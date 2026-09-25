# Estado actual — 23/24 de septiembre de 2026

Dónde quedó el trabajo, para retomarlo desde otra máquina sin el historial del chat.
Escrito al cierre de la sesión del 23 de septiembre.

## Qué está funcionando hoy

| Canal | Estado | Cómo llegan los mensajes |
|---|---|---|
| Messenger | operativo | Meta → n8n `Captura de Campañas` → `/bot` |
| Instagram | operativo desde el 23/09 | Meta → n8n → `/webhooks/instagram` |
| WhatsApp | operativo desde el 23/09 | Meta → n8n → `/webhooks/whatsapp/+584244205394` |

- WABA `Romicars`, id `112013338473590`, número `+58 424-4205394`, en **coexistence**
  (la app WhatsApp Business del teléfono sigue funcionando).
- Inbox de Chatwoot: `WABA RomiCars` (id 4). Canal creado a mano con un token de usuario
  del sistema **sin caducidad**, no por Embedded Signup — el único template de registro
  insertado que ofrecía Meta era el de 60 días, que obliga a reautorizar cada dos meses.
- El registro del webhook lo hace Chatwoot solo (`after_commit :setup_webhooks`), no hay
  que tocar nada en el panel de Meta al recrear un canal.

### Decisión de arquitectura que conviene recordar

WhatsApp pasa por n8n **a propósito**. Meta entrega al override por número **o** al callback
de la app, nunca a los dos. Al principio Chatwoot registró el override y se llevó el tráfico
directo; se limpió con `clear_phone_number_callback_override` para devolverlo a n8n y
conservar la atribución de campañas de los anuncios click-to-WhatsApp.

Consecuencia: **n8n está en el camino crítico**. Si n8n se cae, no entra ningún WhatsApp.

## Trabajo de esta sesión

### Rails — todo mergeado en `claude/init-tvh2q7`

| PR | Qué |
|---|---|
| #62 | Mapa de calor de contactos por ciudad; el seguimiento firma con el AgentBot del inbox |
| #63 | (cerrado, reemplazado por #64) |
| #64 | Correos de cuenta en español + logo; ciudad del contacto desde los campos correctos; arreglo de CI; resultados del seguimiento |

Lo importante del #64, commit `21ccfed`:

- **`abandonado` es un `resolution_type` propio.** El silencio dejó de cerrarse como
  `perdido / sin_respuesta`. Lo escribe solo `ConversationFollowupsJob`, no aparece en el
  modal de resolución, y queda fuera de los porcentajes del embudo — se reporta como
  contador aparte. Constantes en `app/models/conversation.rb`: `RESOLUTION_TYPES` (los
  cuatro) y `DECLARED_RESOLUTION_TYPES` (los tres que declara una persona).
- **Un seguimiento `assisted` ya no cierra nada.** Con vendedor asignado el job solo deja
  nota privada; cerrar por él era lo que convertía una entrega en curso en venta perdida a
  las 48 h.
- **Etiquetas `proveedor` y `logistica`** sacan la conversación del embudo
  (`EXCLUDED_LABELS` en `app/jobs/conversation_followups_job.rb`).
- **CI arrancó por primera vez.** `config/database.yml` tenía
  `ENV.fetch('POSTGRES_USERNAME')` sin default en el bloque `production:`, y ERB renderiza
  el archivo entero sea cual sea `RAILS_ENV`, así que los 16 shards morían en `db:create`.

Estado del suite tras el arreglo: **385 examples, 1 failure** en el shard 0. El fallo es
`spec/controllers/devise/session_controller_spec.rb:22`, deuda vieja sin relación con estos
cambios. `lint-backend` marca 137 offenses de RuboCop, casi todas en código anterior.

### n8n — workflow `Bot Atencion Cliente` (`8nLOTjgmTTK52CsO`)

Cada cambio quedó como versión separada en el historial del workflow.

- **Búsqueda de precios reescrita.** `ILIKE` no ignora acentos, así que `cigüeñal` nunca
  coincidía con `CIGUEÑAL` y el match exacto devolvía cero para una pieza que está dos veces
  en el catálogo. El fallback difuso además no tenía `ORDER BY similarity`, y entregaba una
  fila arbitraria: ofreció un cigüeñal de 136 $ en lugar de un sensor de 15 $. Ahora los dos
  lados se normalizan con `translate()`, cada palabra de más de 2 letras tiene que aparecer
  en `description + synonyms`, el difuso va ordenado, y las filas sin precio quedan fuera.
- **Varias variantes exactas ya no se eligen solas.** Si la búsqueda devuelve CORTA y LARGO,
  el bot las nombra y pregunta cuál.
- **Nombres basura.** `Edit Fields5` exige `/\p{L}{2}/u` — dos letras seguidas. Antes un
  perfil de WhatsApp llamado `.` o un emoji pasaba como nombre válido.
- **Preguntas técnicas al humano.** `vehicle_prices` no tiene medidas, número de parte ni
  compatibilidad, y el modelo las contestaba de memoria. Regla nueva: nota privada y
  `asignar_agente`.
- **Las tools son internas.** El bot llegó a escribirle a un cliente "parece que no
  manejamos el modelo sensor de cigüeñal como un vehículo".
- **`validar_vehiculo` solo acepta marcas y modelos.**
- **Tuteo.** Las frases literales al cliente pasaron de voseo a tú.

### n8n — workflow `Captura de Campañas` (`FQjlPEDU4CcBmIoU`)

- `Reenviar a Chatwoot WA` apuntaba a `/webhooks/whatsapp` sin el número → 404 en todo.
- `Guardar en Redis` armaba la clave con `entry[0].messaging[0].sender.id`, que no existe en
  un payload de WhatsApp. Ahora usa `$json.contact_id`, que `Extraer Referral` ya resuelve
  por canal.
- Del lado del bot, `Consultar Campaña Meta` elige el `source_id` que es solo dígitos. Con
  coexistence un contacto tiene varios `contact_inbox` (teléfono y BSUID `VE.xxx`), y
  `contact_inboxes[0]` era una moneda al aire.

### Suscripciones de Meta (app `1353538049908119`)

Se agregaron por API, con `POST /{app-id}/subscriptions`:

- `smb_message_echoes` al objeto `whatsapp_business_account` — sin eso, lo que el dueño
  escribe desde la app del teléfono no aparecía en Chatwoot. Chatwoot lo pedía del lado de
  la WABA, pero la app nunca lo tuvo habilitado y Meta entrega solo lo que está en las dos
  listas.
- El objeto `instagram` completo, que no estaba suscrito: `messages`,
  `messaging_postbacks`, `messaging_referral`, `standby`. Verificado con un DM real.

### 25/09 — el seguimiento se enciende desde la app

- **Bug en producción desde el deploy del #64**: la exclusión por etiquetas usaba
  `Conversation.tagged_with(..., any: true).select('conversations.id')`, y Postgres la
  rechazaba con `subquery has too many columns`. Como revienta en `schedule_new`, el job no
  agendaba, no mandaba ni cerraba nada. Ahora consulta `taggings` directo.
- **El interruptor reemplazó a `FOLLOWUPS_ENABLED`.** Vive en `account.settings['followups_enabled']`
  y se cambia desde **Configuración → Flujo de conversación → Seguimiento automático**
  (solo administradores). La variable de entorno ya no se lee: si sigue puesta en EasyPanel
  no hace nada y se puede borrar.
- **Después de desplegar, el seguimiento queda APAGADO** hasta que alguien lo prenda desde
  esa pantalla. Es a propósito: el job le escribe a clientes solo.
- Un seguimiento pendiente de más de un día se cancela como `vencido` en vez de mandarse, para
  que apagar y prender no dispare una semana de recordatorios atrasados.

## Punto exacto donde quedamos

Investigando unos mensajes `This message is unavailable.` que aparecen en varias
conversaciones de WhatsApp (una es la #48, de `+12066409886`).

Ya está descartado que sea spam. Lo explica el comentario del propio fork en
`app/services/whatsapp/incoming_message_base_service.rb`:

> WhatsApp delivers messages it cannot render (e.g. coexistence companion-device syncs that
> fail with error 131060) as type: unsupported with no content.

Es la sincronización del historial del teléfono hacia la WABA al conectar coexistence.

**El comando que faltaba correr** (la consulta anterior dio 0 porque `content_attributes`
se guarda con `store ... coder: JSON`, o sea un string JSON dentro de una columna `json`,
y `->>` devuelve NULL):

```bash
docker exec asta_chatwoot-rails-1 bundle exec rails runner "
ms = Message.where(content: 'This message is unavailable.').order(:created_at)
puts ['total', ms.count].inspect
puts ms.joins(conversation: :contact).group('contacts.phone_number').count.inspect
puts ['primera', ms.minimum(:created_at).to_s, 'ultima', ms.maximum(:created_at).to_s].inspect
"
```

Cómo leerlo:

- fechas concentradas alrededor del 23/09 → sincronización inicial, se detiene sola
- fechas que siguen apareciendo → el companion device sigue fallando, hay que mirar la app
  y el estado del número en el portafolio

Efecto secundario a decidir: cada uno creó contacto y conversación, quedaron asignadas por
la política por defecto y cuentan como leads. Si son muchas, inflan el denominador de la
conversión.

## Pendientes

### Seguridad

- [ ] **App Secret en texto plano** en los tres nodos Crypto de `Captura de Campañas`
      (`Calcular Firma IG`, `MSSG`, `WA`). Quedó expuesto en el JSON del workflow. Rotarlo en
      Meta, moverlo a credencial de n8n, y actualizar `WHATSAPP_APP_SECRET` en super admin.
- [ ] **Token de Telegram** hardcodeado en 4 nodos de alerta de n8n.
- [ ] **Verificación de firma del webhook de WhatsApp apagada.** El canal es manual, así que
      `meta_signature_verification_required?` da `false` y cualquiera que sepa la URL puede
      postear. Se enciende copiando el App Secret al `provider_config` del canal, pero hay que
      arreglar antes el body del nodo de n8n: manda `contentType: json`, que re-serializa y
      rompe el HMAC. Tiene que ir como raw.

### Continuidad de conversaciones — diseñado, no construido

El plan acordado, en orden:

1. ~~`abandonado` como tipo propio~~ hecho en #64
2. **Marcar la continuación**: cuando nace una conversación para un contacto cuya anterior
   cerró `abandonado` hace poco, estamparle `custom_attributes['continua_de']`. Sin eso el
   mismo lead cuenta dos veces: `abandonado` en la vieja y `ganado` en la nueva.
3. **Posponer con el snooze nativo.** Chatwoot ya tiene `status: snoozed` y `snoozed_until`,
   y `TriggerScheduledItemsJob` las reabre. Una conversación pospuesta ya es invisible para
   `eligible_conversations`. Falta la tool `posponer_conversacion` en el bot y un guard para
   que un seguimiento ya enviado no cierre una conversación que después se pospuso.
4. **Plantilla para lo diferido.** Fuera de la ventana de 24 h de Meta, un mensaje libre no
   se manda: `Whatsapp::SendOnWhatsappService` lo crea con `status: failed` y el vendedor
   cree que salió. Hace falta una plantilla **Utility** aprobada, con nombre y repuesto como
   variables, y que el job la use cuando `conversation.can_reply?` sea falso.

### Deduplicación de contactos y traspaso a WhatsApp — diseñado, no construido

Ya hay un caso real: Dario Medina existe como contacto de Instagram y como contacto de
WhatsApp.

1. `after_commit` en `Contact` cuando cambia `phone_number`: buscar el otro contacto de la
   cuenta con ese número y fusionar con `ContactMergeAction` (base = el más viejo). Fusionar
   solo si hay exactamente un candidato.
2. Enlace `wa.me` con el repuesto y un código de correlación al detectar intención de compra.
   No pedir el número por chat: el mensaje entrante de WhatsApp lo entrega verificado.
3. Cerrar la conversación de origen como `consulta / derivado_whatsapp`, nunca `ganado`.
4. Etapa `derivado` en el seguimiento.
5. Endpoint `.vcf` para exportar los teléfonos a la agenda del teléfono — los estados de
   WhatsApp solo los ve quien te tiene guardado y a quien vos tenés guardado, y ninguna API
   publica estados.

### Otros

- [ ] Reprobar el bot con "chery orinoco, el largo" → debe cotizar 17 $ a tasa BCV o 15 $ en
      divisas, no el cigüeñal de 136 $.
- [ ] Probar el echo: escribir desde la app WhatsApp Business y ver si entra como saliente.
- [ ] 886 jobs muertos en Sidekiq, 879 de
      `AutomationRules::TriggerPendingExecutionsJob / ActiveRecord::StatementInvalid`.
- [ ] 137 offenses de RuboCop, 77 autocorregibles.
- [ ] `fake-indexeddb` no está en node_modules: ningún spec de frontend corre local.
- [ ] Bandeja "Erdu" (id 1): era de prueba, se puede borrar.

## Cómo desplegar

```bash
docker stop $(docker ps -q --filter "name=chatwoot")
docker rmi ghcr.io/dsar-svg/chatwoot_romicars:latest
docker pull ghcr.io/dsar-svg/chatwoot_romicars:latest
```

Y redesplegar desde EasyPanel. El commit `21ccfed` no necesita migraciones: `abandonado` es
un valor de una columna `string`, no un enum.
