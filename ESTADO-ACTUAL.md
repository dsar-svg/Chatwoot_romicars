# Estado actual — 28 de septiembre de 2026

Dónde quedó el trabajo, para retomarlo desde otra máquina sin el historial del chat.
Actualizado al cierre de la sesión del 28 de septiembre. Qué hace y qué no hace el bot, para
vendedores y para la entrega: **[GUIA-BOT.md](GUIA-BOT.md)**.

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
- En la misma pantalla se configuran **las horas de silencio** (1 a 12, por defecto 5) y **los
  cuatro textos** del recordatorio, con `{repuesto}` como variable. El nombre del cliente se
  antepone solo. Campo vacío = texto por defecto.
- El tope de 12 h no es arbitrario: el job difiere hasta las 8 am lo que cae de noche (hasta
  12 h más) y pasadas 24 h del último mensaje del cliente, WhatsApp e Instagram solo aceptan
  plantillas. Además, si la ventana ya se cerró, el recordatorio se cancela como
  `fuera_de_ventana` en vez de quedar en el hilo como mensaje fallido.
- El cierre a las 48 h sigue fijo en código (`ConversationFollowup::CLOSE_AFTER`).
- El guard de ventana del job **no usa `Conversation#can_reply?`**: para un mensaje
  automático la regla es 24 h aunque Messenger e Instagram le den 7 días a un agente humano.

### Ventana de 24 h en toda la app (decidido)

`1a3fc64` (19/08) había dejado `can_reply?` siempre en `true` para quitar el banner rojo, pero
Meta seguía rechazando los mensajes libres pasadas 24 h (error 131047). Se restauró el
chequeo en `Conversations::MessageWindowService` y el banner rojo quedó como una línea gris
pequeña sobre el hilo. Fuera de ventana, en WhatsApp el editor solo deja mandar plantillas
(o nota privada); también se puede contestar desde la app de WhatsApp Business en el
teléfono, que por coexistence no tiene ese límite.

### 25/09 — traspaso a WhatsApp, continuidad, proveedores y dashboard

Todo mergeado en `claude/init-tvh2q7`.

| PR | Qué |
|---|---|
| #66–#68 | Seguimiento con interruptor, horas y textos; ventana de 24 h restaurada; menú **Ajustes → Flujo de conversación** (la ruta existía pero nadie la importaba) |
| #69 | Traspaso de Instagram/Facebook a WhatsApp con link `wa.me` y código `RC-XXXXX` |
| #70 | Contactos → ⋮ → **Descargar para el teléfono (.vcf)** |
| #71 | `continua_de`: conversación nueva de un contacto con otra activa en los últimos 14 días |
| #72 | Los 47 specs heredados en verde. Dos eran bugs reales: filtro de contactos (500) y fechas en la búsqueda de conversaciones |
| #73 | Números que no son leads (`proveedor` / `logistica`) y dashboard corregido |

**Traspaso a WhatsApp (`WhatsappHandoff`):**

- `POST /api/v1/accounts/:id/conversations/:id/whatsapp_handoff` (token del bot) → `{ link, code }`.
  Guarda `wa_code`, `wa_enviado_at`, `wa_repuesto`, `wa_vehiculo` y la etiqueta `derivado-whatsapp`.
- `PATCH` al mismo endpoint con `telefono` → guarda el número tecleado. Si otro contacto ya lo
  tiene, se fusionan (el número es único por cuenta).
- Llegada: un mensaje entrante de WhatsApp con el código dispara
  `Conversations::WhatsappHandoffArrivalJob` → fusiona contactos (sobrevive el de WhatsApp, el
  nombre viene del de Instagram), cierra el origen como `derivado` y deja una línea de
  actividad en los dos hilos.
- `derivado` es un tipo sin declarar, como `abandonado`: fuera del embudo, contado aparte en
  el informe ("Pasaron a WhatsApp").
- Si no llega, el seguimiento usa la etapa `derivado` (texto editable en Ajustes).

**No-leads:** etiqueta `proveedor` o `logistica` en el **contacto** (o `proveedor` en una
conversación, que marca el contacto). `Conversation.leads` los excluye. Sus conversaciones no
pasan por el bot, heredan la etiqueta, no reciben seguimiento y no cuentan en el dashboard.

**Dashboard:** leads = contactos distintos (no conversaciones); conversión por vendedor =
ventas ÷ asignadas (antes resueltas ÷ asignadas). Cachés `ai_insights:v3` y `win_loss:v2`.

**Seguimiento:** si alguien pospone (snooze) una conversación después del recordatorio, el
job ya no la cierra a las 48 h.

## 28/09 — bot con traspaso a WhatsApp, probado en vivo

#66–#74 desplegados. El bot quedó activo **solo en las dos páginas de Facebook** (Erdu y Romi
Cars): Instagram y WhatsApp no tienen AgentBot a propósito, mientras está en pruebas.

**n8n `Bot Atencion Cliente`** (versión activa `d2ee73cc`; cada cambio es una versión propia):

- Tools nuevas `derivar_a_whatsapp`, `guardar_telefono`, `posponer_conversacion` (credencial
  `Demo ChatR`). Las dos de `whatsapp_handoff` tienen `neverError` para que el bot lea el 422.
- **El prompt se arma por canal** con expresiones sobre `canal`: en Facebook/Instagram el paso 3
  solo muestra el camino a WhatsApp; en WhatsApp solo nota + `asignar_agente` y la regla `RC-`.
  Una regla "si el canal es X" dentro del prompt no alcanzó: GPT-4o seguía las descripciones de
  las tools ("siempre nota y después asignar") y le pasaba la venta a un vendedor.
- **Cotizar y derivar van en turnos distintos.** En el mismo turno el modelo se saltaba la nota y
  `derivar_a_whatsapp` y **escribió un link inventado** (`wa.me/1234567890`). Ahora cotiza,
  pregunta si lo quiere y deriva con la confirmación.
- **Guard en `Responder en Chatwoot`**: todo link `wa.me` que no sea del número de la tienda con un
  código `RC-` válido se reemplaza por `https://wa.me/584244205394`. Número hardcodeado.
- Otras reglas: primer mensaje con pregunta se contesta antes de pedir datos; "no compro" pregunta
  el motivo y cierra en el turno siguiente; fotos → vendedor (no hay catálogo); listas de
  repuestos se cotizan ítem por ítem; FAQ sin respuesta → no inventar.
- `buscar_faq` une las palabras con OR (antes `plainto_tsquery` exigía todas).
- `saveDataErrorExecution: all`: las ejecuciones fallidas del bot quedan guardadas.

**Probado en vivo desde Messenger** (conversaciones #47, #314–#330): cotización, link + `RC-` +
llegada por WhatsApp con fusión de contactos y cierre `derivado`, teléfono inválido y válido,
posponer hasta el viernes 9 am, pregunta técnica, pérdida con motivo, continuidad (`continua_de`).

**La memoria del bot es por `conversation_id`**: para repetir una prueba hay que cerrar la
conversación y empezar otra, o el modelo copia lo que respondió antes.

**Hallazgo: no hay FAQ de horario.** Con la búsqueda anterior el bot llegó a inventar un horario.
Hay 5 FAQs (ubicación, envíos, delivery, garantía, pagos). Ver pendientes.

**Rails (sin desplegar)**: el cierre `abandonado`/`derivado` ya no escribe "resolved due to 0
minutes of inactivity"; y el webhook de WhatsApp **exige firma** cuando `WHATSAPP_APP_SECRET`
está configurado, aunque el canal sea manual (acepta también `FB_APP_SECRET` e
`INSTAGRAM_APP_SECRET`: es una sola app de Meta y n8n firma con ella).

## Punto exacto donde quedamos

1. **Deploy** del PR de Rails del 28/09 y verificar que siguen entrando los WhatsApp (ver
   "Verificación de firma" en pendientes).
2. **FAQs que faltan**, con datos de la tienda: horario, promociones, costo de delivery por zona,
   Zelle = divisa, devoluciones.
3. **Jobs muertos de Sidekiq** (886, casi todos `AutomationRules::TriggerPendingExecutionsJob`
   con `StatementInvalid`). Falta el error exacto:

```bash
docker exec asta_chatwoot-rails-1 bundle exec rails runner 'd=Sidekiq::DeadSet.new; puts d.size; puts d.map { |j| [j.display_class, j["error_class"], j["error_message"].to_s[0,150]] }.tally.sort_by { -_2 }.first(5).inspect; puts ActiveRecord::Base.connection.table_exists?(:automation_rule_pending_executions)'
```

   Sospecha: tabla `automation_rule_pending_executions` sin crear por un `schema.rb` viejo que
   marcó la migración como corrida.

4. **Plantilla Utility** en Meta (la crea el dueño): `seguimiento_pedido`, español. Texto y
   ejemplos en [GUIA-BOT.md](GUIA-BOT.md#plantilla-seguimiento_pedido). Cuando esté aprobada, el
   vendedor la usa desde el editor fuera de la ventana de 24 h.

## Pendientes

### Seguridad

- [ ] **App Secret en texto plano** en los tres nodos Crypto de `Captura de Campañas`
      (`Calcular Firma IG`, `MSSG`, `WA`). Quedó expuesto en el JSON del workflow y volvió a
      aparecer en la sesión del 28/09. Rotarlo en Meta, moverlo a credencial de n8n, y actualizar
      `WHATSAPP_APP_SECRET` / `FB_APP_SECRET` en super admin **y** los tres nodos a la vez: si
      queda uno viejo, ese canal deja de entrar (401).
- [ ] **Token de Telegram** hardcodeado en 4 nodos de alerta de n8n.
- [ ] **Verificación de firma de WhatsApp (Chatwoot)**: código listo en el PR del 28/09, se activa
      con el deploy. n8n ya re-firma el body limpio (`Calcular Firma WA` → header
      `x-hub-signature-256`), igual que Instagram, que ya exige firma y funciona. **Después del
      deploy**, mandar un WhatsApp de prueba y confirmar que entra; si no entra, los logs de
      rails muestran 401 en `/webhooks/whatsapp/+584244205394` y hay que revisar que
      `WHATSAPP_APP_SECRET` (o `FB_APP_SECRET`) sea el mismo secreto que usa n8n.
- [ ] **n8n no verifica la firma de Meta** en `Webhook Meta (POST)`: firma lo que le llegue. Quien
      conozca `n8n.supricom.com.ve/webhook/romicars-meta-referral` puede inyectar mensajes en los
      tres canales. Arreglo: opción `rawBody` en el webhook y comparar `x-hub-signature-256` contra
      el HMAC del body crudo antes del `If`. Requiere el secreto ya rotado y en credencial.

### Otros

- [x] Reprobar el bot con "chery orinoco, el largo" → cotiza 17 $ BCV / 15 $ divisas (28/09).
- [ ] **Contactos de prueba** (Dario Medina #27 y #310): etiquetarlos `proveedor` al terminar las
      pruebas para sacarlos del dashboard. No antes: con esa etiqueta el bot deja de contestarles.
- [ ] **Casos vistos en WhatsApp sin cubrir** (revisión de 60 conversaciones del 25–28/09):
      variantes 4x4/4x2, año y caja automática cuando cambian el precio; confirmar las marcas de
      `vehicle_brands` (piden Zotye, Chana, Kia, Terios); conversaciones con proveedores sin
      etiqueta (#194, #320).
- [ ] Conectar el bot a Instagram y WhatsApp cuando termine la etapa de pruebas en Facebook. En
      WhatsApp falta probar la regla `RC-` con el bot activo.
- [ ] Probar el echo: escribir desde la app WhatsApp Business y ver si entra como saliente.
- [ ] Mensajes `This message is unavailable.`: sincronización de coexistence (error 131060).
      Ver si siguen apareciendo:
      `Message.where(content: 'This message is unavailable.').group('DATE(created_at)').count`.
- [ ] Que el job de seguimiento mande la plantilla Utility cuando la ventana esté cerrada
      (hoy cancela como `fuera_de_ventana`).
- [ ] RuboCop: ~140 offenses, casi todas heredadas en `romicars_analytics_controller.rb`.
- [ ] `fake-indexeddb` no está en node_modules: los specs de frontend no corren local sin
      quitarlo de `setupFiles` (`vitest.config.ts`).

## Cómo desplegar

```bash
docker stop $(docker ps -q --filter "name=asta_chatwoot")
docker pull ghcr.io/dsar-svg/chatwoot_romicars:latest
```

Y redesplegar desde EasyPanel. Las migraciones corren solas al arrancar
(`db:chatwoot_prepare`). **No usar `name=chatwoot`**: también detiene el otro Chatwoot del VPS
(`automatisupri_chatwoot`).
