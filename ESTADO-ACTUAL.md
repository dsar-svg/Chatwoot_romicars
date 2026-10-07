# Estado actual — 6 de octubre de 2026

Dónde quedó el trabajo, para retomarlo desde otra máquina sin el historial del chat.
Actualizado al cierre de la sesión del 6 de octubre (noche): **la tienda arrancó a trabajar desde aquí**. Qué hace el sistema, qué hace y qué no
hace el bot, para vendedores y para la entrega: **[GUIA-BOT.md](GUIA-BOT.md)** (también se
entregó en Word).

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

**Probado en vivo desde Messenger** (conversaciones #47, #314–#336; las de Erdu no llegaron al
cliente, ver pendientes): lista de varios repuestos, fotos → vendedor, marca no trabajada, FAQ, cotización, link + `RC-` +
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

## 29–30/09 — app móvil, auditoría del dashboard, bot afinado y configuración para la entrega

### Rails — todo mergeado y desplegado

| PR | Qué |
|---|---|
| #76 | Cierre `abandonado`/`derivado` sin "0 minutos de inactividad"; firma de WhatsApp exigida con `WHATSAPP_APP_SECRET` |
| #77 | **App móvil (PWA)** en `/app/m`: conversaciones, detalle, contactos, marcas y precios. Instalable |
| #78 | Vista previa de adjuntos en la lista móvil |
| #79 | Filtro por canal en la app; iconos con fondo blanco (iOS) y maskable (Android) |
| #80 | La app instalada abre en `/app/m` aunque el login o un `start_url` viejo manden al dashboard |
| #81 | Pestaña Dashboard en la app, solo administradores y `report_manage` |
| #82 | Auditoría del dashboard: leads solo si el cliente escribió (`Conversation.customer_wrote`), agentes = todos los miembros (eran solo rol `agent`), la IA ya no inventa causas con cierres en cero |
| #83 | Etiqueta `interno` en `NON_LEAD_LABELS` (números propios, como el segundo WhatsApp) |
| #84 | Tiempo de respuesta redondeado, orden de agentes por chats, contexto de IA con respuesta promedio y origen de las consultas |

Rama `claude/guia-entrega` (sin mergear): esta actualización y la guía de entrega reescrita.

**Por qué el dashboard daba cero:** en WhatsApp nadie había cerrado nunca una conversación con
resultado (las 17 resueltas eran pruebas de Facebook), el bot solo corre en Facebook y ahí solo
escribían contactos `proveedor`. Las cifras eran correctas; lo que faltaba era el registro.

### n8n `Bot Atencion Cliente` (versión activa `5f70021f`)

- **Nombres**: `Edit Fields5.cliente` limpia el perfil (emojis, títulos, mayúsculas, letras
  decoradas con NFKC) y saluda con el primer nombre. Negocios, frases, usuarios con dígitos y
  siglas cuentan como "falta nombre". Si solo hay nombre, `faltan` incluye `apellido`, que se
  pide una sola vez. `guardar_nombre_cliente` guarda nombre y apellido juntos.
- **`buscar_precio_repuesto` reescrito**:
  - plurales y género normalizados (`delantera` = `delantero`);
  - entre coincidencias exactas gana la que tiene más palabras en la **descripción** y la palabra
    principal al inicio (el antirruido salía para "pastilla de freno" por su sinónimo);
  - devuelve `precio_texto` ya redactado ("28$ a tasa BCV o 25$ en divisas"): el modelo invertía
    los montos;
  - si las exactas difieren por posición (delantera/trasera, izq./der., larga/corta, el par)
    **no devuelve precios**, así el bot tiene que preguntar cuál.
- **Prompt**: no ofrece confirmar disponibilidad; variantes de marca terminan en "¿cuál
  prefieres?"; molestia o desconfianza → nota, prioridad `high` y `asignar_agente` (también en
  Facebook, sin WhatsApp); tras guardar el apellido sigue con el primer nombre.
- **`asignar_agente` y `crear_nota_privada`**: si el bot le promete al cliente pasarlo o
  consultarlo, tiene que llamarlas en ese turno. En la pregunta técnica lo prometía y no lo hacía.
- **`Responder en Chatwoot`**: los links markdown `[url](url)` se convierten en la URL sola antes
  del guard de `wa.me` (Messenger los mostraba duplicados con corchetes).
- **`Consultar Contacto`**: reintenta 5 veces cada 5 s. Durante un deploy un mensaje se perdió y
  solo llegó la alerta de Telegram.
- Probado en vivo desde Messenger (#807–#823): apellido una vez, variantes por posición y por
  marca, precio único, foto, queja, técnica, venta perdida con motivo, compra con derivación, y
  seguir escribiendo después del link (actualiza el pedido y mantiene el mismo `RC-`).

### n8n `Resumen diario: lo que el bot no pudo responder` (`Ev6gat9QCzd9hoX3`)

Todos los días a las 19:00 (America/Caracas): lee de Postgres las notas privadas del
`AgentBot` del día y `product_inquiries` con `encontrado = false`, GPT-4o-mini separa lo que el
bot no pudo resolver, y lo manda por Telegram (credencial `Api Telegram Dario`, chat
`6281232133`). Probado: llegó el del 30/09.

### Configuración de Chatwoot (hecha el 30/09)

- **Asignación**: política `Reparto RomiCars` (id 1, round robin, `longest_waiting`, 100 por
  hora, excluye inactivas > 168 h) en las cuatro bandejas. `assignment_v2` asigna solo a
  miembros **conectados**; sin política no había reintento y por eso se acumulaban las sin
  asignar. **Romi Cars** (inbox 2) tenía la auto-asignación apagada: ahora encendida.
- **399 conversaciones de difusión cerradas** en WhatsApp (solo mensajes salientes, historial
  completo). Quedó abierta la #556 (un vendedor escribió y el cliente no contestó).
- **Etiquetas**: 18 proveedores de la lista de la clienta (6 existían, 12 creados como
  contactos #788–#799), 10 tiendas marcadas por nombre (por confirmar), `logistica` en
  "delivery Romicars" (#81), `interno` en "Romicars Ventas Digitales" (#42).
- Excel entregado para la reunión: `Contactos_por_confirmar_RomiCars.xlsx` (14 por confirmar, 19
  confirmados).
- Contacto de prueba #27 restaurado ("Dario Medina", `proveedor`).

## 01–02/10 — disponibilidad de repuestos y pruebas de entrega

### Rails — mergeado y desplegado

| PR | Qué |
|---|---|
| #87 | **Disponibilidad**: columna `vehicle_prices.available` (default `true`), distinta de `active` (inactivo = el bot no lo ve). Botón agotado/disponible por fila, casilla en el editor (también en la app), etiqueta "Agotado". **Marcado masivo**: casillas por fila y "seleccionar todos los resultados" → `PATCH vehicle_prices/bulk_availability` (solo administradores). **Plantilla Excel**: `GET vehicle_prices/export` arma un .xlsx a mano con rubyzip (`VehiclePriceExportService`) con DESCRIPCION, MODELO, COSTO, DIVISA, SINONIMOS, DISPONIBLE; la importación lee DISPONIBLE (SI/NO, vacío no cambia) y actualiza filas creadas desde el dashboard en vez de saltarlas. **Bolívares al guardar**: `VehiclePrice#reprice_in_bolivares` calcula `monto_bs` y `bolivares` con la última tasa en cada guardado (antes solo al actualizar la tasa, y el bot cotiza con lo guardado) |
| #88 | Win/loss del dashboard: con 0 cierres en el período reutilizaba la narrativa guardada en Redis (decía "se perdieron todas" citando chats de prueba #15/#17/#18). Ahora un lado sin cierres lleva el resumen fijo y sin patrones; claves `win_loss:v4` y `win_loss:memory:v2`. Guía de entrega actualizada |

### n8n `Bot Atencion Cliente` (versión activa `cc67b084`, anterior `5f70021f`)

- `buscar_precio_repuesto` devuelve `disponible`; si está agotado anula los precios y
  `precio_texto` = "AGOTADO: …".
- Prompt: con `disponible=true` confirma "sí lo tenemos" (nunca aparta ni reserva); agotado → lo
  dice sin precio y ofrece vendedor (nota + `asignar_agente`) o cierra `perdido`/`sin_stock`. Se
  quitó la regla de "nunca confirmar disponibilidad".

### Probado el 02/10 sobre la imagen desplegada

- Messenger con el contacto #27 (#901–#902): agotado → sin precio y ofrece vendedor; acepta →
  nota y asignación por `Reparto RomiCars`; disponible → "sí lo tenemos, 6$ a tasa BCV o 5$ en
  divisas"; compra → link de WhatsApp con `RC-`. Ejecuciones de n8n sin error (~20 s por
  respuesta). Datos de prueba restaurados (#337 disponible, #27 con `proveedor`).
- Exportación (.xlsx válido, 78 KB) y marcado masivo por API.
- Dashboard escritorio y app móvil: todos los endpoints 200 en 100–200 ms; cifras coherentes
  (354 leads, 0 % conversión porque nadie cerró con resultado); sin desborde horizontal en 375 px.
- Resumen diario por Telegram corrió el 30/09 y el 01/10 a las 19:00.

## 04/10 — bot probado en WhatsApp e Instagram

Las pruebas se hicieron con el contacto #23 (Dario Medina, etiqueta `prueba-bot`, #90), que
recibe el bot en cualquier bandeja aunque la bandeja no lo tenga conectado. WhatsApp e Instagram
siguen **sin bot para los clientes reales**.

### Rails — mergeado y desplegado

| PR | Qué |
|---|---|
| #90 | Etiqueta `prueba-bot` en el contacto: su conversación nueva va al bot de la bandeja o, si no tiene, al que ya corre en otra |
| #91 | **Traspaso tras posponer**: una conversación que el bot pospuso volvía como `open` con el bot asignado, y `asignar_agente` (que solo contaba desde `pending`) no asignaba a nadie ni saltaba la alerta de Telegram. Ahora: si el cliente escribe vuelve a `pending`; si vence la fecha pasa a los vendedores (`bot_handoff!`); y el toggle a `open` del bot suelta una conversación abierta que todavía tenga. **`prueba-bot` fuera del dashboard** (`Conversation.without_bot_testers`, solo cifras: el bot y el seguimiento los siguen tratando como clientes) |
| #92 | **Insights IA al día**: un cierre con resultado (o uno corregido) borra la caché de `ai_insights` y `win_loss` (`RomicarsInsightsCache`); sin cierres sigue valiendo 3 h. Botón **Actualizar análisis** en la pestaña |

### Probado en vivo (conversaciones #935–#946)

- **WhatsApp**: variantes por posición, cotización y paso a vendedor sin link; el bot callado con
  vendedor asignado; FAQ; marca no cargada (Kia); pregunta técnica; cliente molesto (prioridad
  alta); lista de tres repuestos; pérdida por precio con motivo; posponer hasta una fecha y volver
  antes (con #91 desplegado); tres mensajes en ráfaga (una sola respuesta); cambio de vehículo;
  intento de manipulación; pedir una persona; repuesto agotado; respuesta del vendedor desde
  Chatwoot (llega al teléfono) y cierre `ganado`.
- **Instagram** (cuenta `sam_dar1219`): cotización con variantes, link `wa.me` con código `RC-`,
  llegada por WhatsApp con fusión de contactos y cierre `derivado`, teléfono inválido, FAQ de
  garantía y pregunta técnica con vendedor asignado.
- **Dashboard**: la venta de prueba movió conversión, ventas y crédito del vendedor. Con #91
  desplegado quedó en **376 leads, 0 cierres y 0 consultas**: todo lo que mostraban Resolución y
  Demanda venía del contacto de prueba.
- Sin vendedor en línea llega la alerta de Telegram "Cliente esperando vendedor".

### Fallos y detalles que siguen abiertos

- ~~**El bot inventa el horario.**~~ Resuelto el 05/10 (FAQ de horario cargada y `SIN_RESPUESTA` en `buscar_faq`). `buscar_faq` devuelve vacío (no hay FAQ de horario) y aun así
  GPT-4o contestó "lunes a viernes 8 a 5, sábados 8 a 12", contra lo que dice el prompt. Se
  corrige cargando la FAQ; mientras falte, el riesgo sigue.
- El filtro de aceite del Chery Orinoco (#1408) sigue **agotado** en producción. No lo marcaron
  las pruebas del 02/10 (ese día solo se tocó la horquilla #337, y se restauró); seguramente fue
  la prueba de agotado del 04/10. Confirmar con la clienta si es real.
- ~~Detalles del bot~~ (resuelto el 05/10): preguntó el motivo de la pérdida cuando el cliente ya había dicho "muy caro";
  con dos marcas cotizadas y un "la quiero" no preguntó cuál; no volvió a guardar el vehículo
  cuando el cliente lo corrigió.
- ~~Dos conversiones~~ (resuelto el 05/10, #95): Insights IA y Operación mostraban dos "conversión" distintas (ganadas ÷ ganadas + perdidas
  contra ventas ÷ leads); el texto de la IA dice `FacebookPage` y minutos sin convertir.
- Sin probar: ventana de 24 h, envío de fotos, teléfono válido en Instagram y el vencimiento de
  un pospuesto (solo lo cubre el spec).
- En esta máquina no hay Postgres, `node_modules` ni `gh`: los specs y ESLint de #91 y #92 solo
  corrieron en CI.

## 05/10 — detalles del bot y una sola conversión (entrega)

### Rails
- #95 `claude/entrega-detalles`: **una sola "conversión"** en todo el dashboard (clientes que compraron ÷ leads, `lead_conversion_pct`). La tarjeta Ganadas y los prompts de la IA usan esa; ganadas ÷ (ganadas + perdidas) pasa a llamarse `tasa_de_cierre_pct` y la IA no puede llamarla conversión. Canales legibles para la IA (`Facebook`, no `FacebookPage`) y tiempos en horas. Claves `ai_insights:v6`, `win_loss:v5`, `win_loss:memory:v3`.

### n8n `Bot Atencion Cliente` (versión activa `0a88b09c`, anterior `c602f65b`)
- Paso 5: si el cliente ya dijo por qué no compra ("muy caro", "tarda mucho", "no lo tienen") cierra `perdido` con ese motivo en el mismo turno, sin preguntar. Misma excepción en `cerrar_conversacion`.
- Paso 3 (a2 en Facebook/Instagram, a0 en WhatsApp): con varias opciones cotizadas, un "la quiero" sin decir cuál pregunta cuál; no deriva ni pasa a vendedor.
- Si el cliente corrige el vehículo, `validar_vehiculo` + `guardar_vehiculo` antes de recotizar.
- `buscar_faq` sin coincidencias devuelve una fila `SIN_RESPUESTA` que manda dejar nota y asignar (antes prometía "lo confirmo con el equipo" sin hacer nada). Nunca escribe horario sin FAQ.
- Pregunta técnica: `actualizar_prioridad` high.

### Probado en vivo (Messenger, contacto #23 `prueba-bot`, #973–#978)
- Dos bombas de agua + "la quiero" → "¿cuál de las dos prefieres?" (falló con la primera versión: el paso 3 le ganaba; corregido).
- "perdón, es para un chery arauca" → guardó CHERY ARAUCA y recotizó.
- "no gracias, está muy caro" → cerrada `perdido` / `precio`, textual "esta muy caro", sin preguntar.
- Horario con la FAQ cargada hoy → "hasta las 5:00 PM".
- Delivery a Maracay (sin FAQ) → nota y asignación por `Reparto RomiCars`.
- "la bomba de agua chery para el arauca" listó las dos: "Chery" es también la marca del carro, ambiguo de verdad.
- El contacto #27 ya no existe: se unió al #23 en las pruebas del 04/10.

## 06/10 — plantilla de seguimiento, caché de bandejas, tasa del BCV y porcentaje

### Rails — mergeado y desplegado

| PR | Qué |
|---|---|
| #94 | **Clave de caché que vence**: el panel guarda bandejas, etiquetas y equipos en IndexedDB y solo los vuelve a pedir si cambia la clave de la cuenta. La clave vive 72 h en Redis y, vencida, la API devolvía un `0000000000` fijo: un navegador con su lista guardada bajo ese mismo valor nunca refrescaba (el panel mostraba solo "Erdu" con cuatro bandejas creadas, y Campañas no ofrecía WABA RomiCars). Ahora una clave vencida se vuelve a generar al leerla |
| #97 | **Porcentaje sobre la tasa BCV editable** (`account.settings['price_markup_percent']`, 13 por defecto) desde **Ajustes → Precios → Cambiar porcentaje**, solo administradores. Al guardar rehace el equivalente de la última tasa y todo el catálogo (`PATCH exchange_rates/markup`). **La tasa se lee de bcv.org.ve** y se guarda con su "Fecha Valor"; `ve.dolarapi.com` queda de respaldo. Una tasa a más de 25 % de la última se descarta. El job pasó de cada 6 h a cada hora. La columna sigue llamándose `equiv_13` |
| #98 | bcv.org.ve manda un certificado intermedio que no corresponde y desde el servidor toda lectura fallaba la verificación. El intermedio correcto (Sectigo DV R36, hasta 2036) va en `config/certs` y se suma a las raíces del sistema solo para esa consulta. Si el BCV cambia de CA vuelve a fallar y responde el respaldo: la pantalla lo dice ("fuente: respaldo") |

**Decidido con el dueño**: los precios pasan a la tasa del día siguiente en cuanto el BCV la
publica (por la tarde), no a medianoche.

Probado en producción el 06/10: porcentaje 13 → 14 → 13 con el catálogo recalculado las dos
veces; "Actualizar ahora" trajo 873,87 con fecha valor 07/10 y fuente BCV. **Sin ver todavía**:
que el job de cada hora la traiga solo.

### Plantilla `seguimiento_pedido` en Meta

- **Importaciones Romicars** (WABA `112013338473590`, el número principal): creada el 04/10 y
  aprobada como **Utility**, en español, con el texto de la guía. Sincronizada en la bandeja
  WABA RomiCars; aparece en el editor y en Campañas.
- **Romicars Ventas Digitales** (WABA `529004876962549`): Meta responde "no tiene permiso para
  crear ni actualizar plantillas". Va con lo que ya faltaba de esa línea: número sin conectar y
  portafolio sin verificar. Al enviarla Meta también avisó que la categoría debería ser
  Marketing; en la principal pasó como Utility sin ese aviso.
- En una **campaña**, la variable 1 es `{{contact.first_name}}` (un contacto sin nombre se
  salta). La variable 2 es un texto igual para todos: Chatwoot no guarda en el contacto qué
  repuesto consultó. Se combina con los filtros de marca y modelo de la audiencia. Mandarla en
  masa a quien no consultó nada arriesga que Meta la pase a Marketing.

## 06/10 (noche) — arranque: corte, bot en las cuatro bandejas, horario y reparto

### Corte del arranque: 06/10 a las 7:40 pm

- Las **986 conversaciones** creadas antes de esa hora llevan la etiqueta `previo-arranque` y
  están cerradas (541 seguían abiertas). No se borraron, ni ellas ni los contactos: la mayoría
  se había atendido desde la app del teléfono, y de 941 contactos solo 1 tenía vehículo.
- El dashboard no las cuenta (#100). La etiqueta va en la conversación, no en el contacto: el
  mismo cliente que vuelve abre una conversación nueva y es un lead.
- Se hizo por la API de acciones masivas (`POST bulk_actions`). Ninguna bandeja tiene encuesta
  ni saludo, así que cerrar no le escribió a nadie.

### Rails — mergeado y desplegado

| PR | Qué |
|---|---|
| #100 | `Conversation.without_pre_launch`: las cifras del dashboard saltan `previo-arranque` |
| #101 | **Aviso de fuera de horario al traspasar**: cuando el bot pasa a vendedor con la bandeja cerrada, 20 s después sale el mensaje de fuera de horario de la bandeja (`Conversations::OutOfOfficeNoticeJob`). El aviso nativo se calla mientras el bot tiene la conversación: salía con el primer mensaje, encima de la respuesta del bot |
| #102 | **Link de WhatsApp alternado** entre las líneas (`WhatsappHandoff.whatsapp_number`, contador en Redis; la conversación guarda `wa_numero` y repite el suyo). **Seguimiento solo con la tienda abierta**: espera el horario comercial de la bandeja, sin cancelarse |
| #103 | **Seguimiento con plantilla**: fuera de las 24 h, si la bandeja tiene `seguimiento_pedido` aprobada y hubo un repuesto cotizado, sale la plantilla (nombre, o "buen día" si el perfil no tiene uno, y el repuesto). `STALE_AFTER` pasó de 1 a 3 días |
| #104 | **Asignar a vendedores desconectados**: con `account.settings['assign_offline_agents']` el reparto usa a todos los miembros de la bandeja. Apagado es la regla de Chatwoot (solo conectados). Sin interruptor en pantalla: se cambia con `PATCH /api/v1/accounts/1` |

### n8n `Bot Atencion Cliente` (versión activa `27476e59`, anterior `0a88b09c`)

- El guard de `Responder en Chatwoot` acepta links `wa.me` de las dos líneas (`584244205394`
  y `584129876030`). Al agregar una línea hay que sumarla ahí o sus links se reemplazan por el
  link pelado sin código.

### Configuración hecha el 06/10

- **Bot conectado a las cuatro bandejas**: Romi Cars (2), somosromicars (3), WABA RomiCars (4) y
  WABA Romi 2 (5, `+58 412-9876030`, la segunda línea, ya conectada). La bandeja Erdu ya no existe.
- **Horario comercial** en las cuatro: lunes a viernes 8:00–17:00, sábados 8:00–13:00, domingo
  cerrado, `America/Caracas`. Texto: "En este momento estamos fuera de horario. Tu solicitud
  quedó registrada y un vendedor te atenderá apenas abramos." Se edita por bandeja en
  **Ajustes → Entradas → Horario comercial**. Ese mismo horario gobierna el seguimiento.
- **Reparto**: `assign_offline_agents: true`. Política `Reparto RomiCars` también en WABA Romi 2
  (sin política el tope por defecto es 5 asignaciones por vendedor cada 5 minutos, y la sexta
  se quedaba sin asignar).
- **Miembros**: WABA RomiCars → Ventas 1; WABA Romi 2 → ventas 2. **Instagram y Facebook sin
  miembros**: ahí los traspasos quedan sin asignar.
- **Porcentaje sobre la tasa BCV: 15 %** (lo subió el dueño desde Ajustes → Precios).
- Agentes: Dario y Moises (administradores), Susel, Ventas 1 y ventas 2.

### Probado en producción el 06/10 por la noche (contacto #23, #1030–#1043)

- Bot en la línea principal, la segunda línea e Instagram: cotiza, deja nota y pasa a vendedor o
  manda el link.
- Aviso de fuera de horario: nada con el primer mensaje; 20 s después del traspaso, el aviso.
- Dos traspasos seguidos desde Instagram: uno a cada línea, cada uno con su código. Llegada por
  la segunda línea con el código: origen cerrado `derivado` y contactos unidos.
- Reparto con los vendedores desconectados: asignó a Ventas 1 y a ventas 2, y repartió las que
  estaban esperando.
- Dashboard tras el corte: 7 leads, 0 cierres, 0 consultas (10 leads al cierre de la sesión).

### Sin probar

- El seguimiento (#102 y #103): sigue apagado. Al encenderlo le escribe a clientes reales, y
  cada plantilla la cobra Meta como mensaje de utilidad. No se envió ninguna plantilla real.
- El vencimiento de un pospuesto y que el job de la tasa la traiga solo cada hora.
- **Respuestas a estados de WhatsApp**: no se sabe cómo llegan (texto normal, "mensaje no
  disponible" o no llegan). En 235 conversaciones revisadas no apareció ninguna identificable.
  Pendiente mirar la primera que entre.

### Visto de paso

- En la segunda línea el primer mensaje de un chat llegó como "This message is unavailable." y
  el bot contestó un saludo genérico. Una vez; vigilar.
- Un vendedor contestó a mano desde la app de Instagram una conversación que llevaba el bot, y
  ofreció una promoción (filtros de aire, aceite y gasolina por 12 $) que no está en las FAQ.
  Acordar quién contesta en Instagram y cargar la promoción.
- WhatsApp Web no escribe en el cuadro de mensaje justo después de abrir un chat por URL: hay
  que hacer clic en el cuadro y comprobar con una captura que el mensaje salió.

## 07/10 — pedidos de la clienta: sin emojis, menos insistencia, nombres de piezas, fotos

### n8n `Bot Atencion Cliente` (versión activa `34489583`, anterior `82245667`)

- **Sin emojis ni signos de exclamación**: regla en el prompt, saludo nuevo ("Hola, bienvenido a
  Romicars.") y, como red, `Responder en Chatwoot` borra emojis y "¡", y cambia "!" por ".".
- **Datos del cliente**: se piden como mucho dos veces, nunca en dos mensajes seguidos; la
  segunda explica para qué ("es para incluirte en nuestra base de datos..."). Después no
  insiste más. Sin probar en vivo: el contacto de prueba ya tiene todos los datos.
- **Nombres populares**: si no hay coincidencia, reintenta una vez con el otro nombre de la misma
  pieza antes de pasar a vendedor, y no cotiza una pieza que solo se parece en el nombre.
- **Fotos**: la descripción automática dice cuándo no está segura y transcribe códigos. Si el
  cliente ya nombró la pieza, manda lo que dijo él; si no se reconoce, pasa a vendedor.
- **Promociones**: al cotizar filtros, aceite, bujías, kit de tiempo, pastillas o kit de crochet
  busca en las FAQ una promo que lo incluya y la menciona. **Hoy no hay ninguna promo cargada**
  (las 6 FAQ son pagos, garantía, delivery, envíos, ubicación y horario).

### Sinónimos de la lista de precios corregidos (378 filas, vía API)

La causa principal de las confusiones: los sinónimos venían cargados por palabra suelta y muchos
eran de otra pieza ("DISCO CROCHET" tenía "disco de freno", "MESETA" tenía "plato de clutch",
las pilas de gasolina "batería", los mozos "rótula", todos los filtros llevaban "filtro de
aceite, de aire, de gasolina" a la vez). Se reescribieron por regla sobre la descripción; los
precios no cambiaron (comprobado fila por fila). Respaldo de los valores anteriores en el
`localStorage` del navegador de la extensión, clave `vp_synonyms_backup_20261007`.

Probado en vivo (Messenger, #1089): "disco de croche del Orinoco" cotiza el de crochet, "disco
de freno" pregunta delantero o trasero, "bastón de agua del Arauca" cotiza la tubería principal.

### Rails — rama `claude/bot-sin-emojis`

- Mensajes de seguimiento sin emojis.

## Punto exacto donde quedamos

En producción desde el 06/10 a las 7:40 pm, con el bot en las cuatro bandejas. Lo que falta:

1. **Miembros en Instagram y Facebook** (bloqueante): somosromicars y Romi Cars no tienen
   vendedores, así que lo que el bot pasa a vendedor ahí queda sin asignar. Hay 2 abiertas así.
2. **Segunda línea**: falta la plantilla `seguimiento_pedido` en la WABA "Romicars Ventas
   Digitales" (el 04/10 Meta respondía que no tenía permiso; reintentar ahora que está conectada).
3. **Marcar los agotados**: el bot ya contesta en todas las bandejas y los 2.139 repuestos están
   `available = true`, así que el bot dice "sí lo tenemos" a todo. Lo más rápido: Importar →
   Descargar plantilla, poner NO en DISPONIBLE y subirla.
4. **Encender el seguimiento** cuando se decida (hoy `followups_enabled: false`); con 5 horas
   de silencio y el horario comercial, entre semana cae dentro de las 24 h. Que los vendedores
   **cierren con resultado**: sin eso el dashboard queda en 0 % de conversión.
5. **FAQs que faltan**, con datos de la tienda: promociones (una FAQ por promo, con la palabra
   "promoción", qué incluye, para qué carro y precio; el bot ya las ofrece), costo de delivery por zona,
   Zelle = divisa, devoluciones. Sin ellas el bot pasa esas preguntas a un vendedor.
6. **Excel de contactos por confirmar**: desmarcar los que no sean proveedores.
7. **Tarjeta Productos Profit**: sin conectar le muestra a la clienta "Agrega PROFIT_API_URL…".
   Decidir si se oculta mientras no esté conectada.
8. **Jobs muertos de Sidekiq** (886, casi todos `AutomationRules::TriggerPendingExecutionsJob`
   con `StatementInvalid`). Falta el error exacto:

```bash
docker exec asta_chatwoot-rails-1 bundle exec rails runner 'd=Sidekiq::DeadSet.new; puts d.size; puts d.map { |j| [j.display_class, j["error_class"], j["error_message"].to_s[0,150]] }.tally.sort_by { -_2 }.first(5).inspect; puts ActiveRecord::Base.connection.table_exists?(:automation_rule_pending_executions)'
```

   Sospecha: tabla `automation_rule_pending_executions` sin crear por un `schema.rb` viejo que
   marcó la migración como corrida.

9. **Respuestas a estados de WhatsApp**: ver cómo llega la primera y decidir qué hace el bot.

## Pendientes

### Seguridad

- [ ] **App Secret en texto plano** en los tres nodos Crypto de `Captura de Campañas`
      (`Calcular Firma IG`, `MSSG`, `WA`). Quedó expuesto en el JSON del workflow y volvió a
      aparecer en la sesión del 28/09. Rotarlo en Meta, moverlo a credencial de n8n, y actualizar
      `WHATSAPP_APP_SECRET` / `FB_APP_SECRET` en super admin **y** los tres nodos a la vez: si
      queda uno viejo, ese canal deja de entrar (401).
- [ ] **Token de Telegram** hardcodeado en 4 nodos de alerta de n8n.
- [x] **Verificación de firma de WhatsApp (Chatwoot)**: activa desde el 29/09 (PR #76 + App Secret
      cargado en super admin → `WHATSAPP_APP_SECRET`, que hasta ese día estaba **vacío**, así que
      la regla no se encendía). Probado: un WhatsApp real entró. Si algún día dejan de entrar,
      los logs de rails muestran 401 en `/webhooks/whatsapp/...`: el secreto de super admin no
      coincide con el de `Calcular Firma WA` en n8n.
- [ ] **n8n no verifica la firma de Meta** en `Webhook Meta (POST)`: firma lo que le llegue. Quien
      conozca `n8n.supricom.com.ve/webhook/romicars-meta-referral` puede inyectar mensajes en los
      tres canales. Arreglo: opción `rawBody` en el webhook y comparar `x-hub-signature-256` contra
      el HMAC del body crudo antes del `If`. Requiere el secreto ya rotado y en credencial.

### Otros

- [x] Reprobar el bot con "chery orinoco, el largo" → cotiza 17 $ BCV / 15 $ divisas (28/09).
- [x] **Contactos de prueba** (Dario Medina #27 y #310) etiquetados `proveedor`: salen del
      dashboard, pero **el bot ya no les contesta**. Para volver a probar, quitar la etiqueta y
      cerrar cada conversación entre escenario y escenario (la memoria del bot es por
      conversación). Al terminar, volver a poner la etiqueta.
- [ ] **Borrar la bandeja Erdu** (inbox 1, página de pruebas personal; no envía: `Invalid
      appsecret_proof`). Lo hace el dueño.
- [ ] **Kia no está en `vehicle_brands`**: el bot contesta "para el Kia Rio no manejamos repuestos",
      pero Juan vendió amortiguadores de Kia Rio por WhatsApp (#309). Cargar las marcas reales.
- [ ] **Casos vistos en WhatsApp sin cubrir** (revisión de 60 conversaciones del 25–28/09):
      variantes 4x4/4x2, año y caja automática cuando cambian el precio; confirmar las marcas de
      `vehicle_brands` (piden Zotye, Chana, Kia, Terios); conversaciones con proveedores sin
      etiqueta (#194, #320).
- [ ] **Segundo número de WhatsApp** `+58 412-9876030`, WABA "Romicars Ventas Digitales"
      (`529004876962549`), otra línea de RomiCars. Está en el portafolio pero **Fuera de
      internet**: falta la conexión con coexistence. El registro insertado de Chatwoot
      (configuración `2113356415923718`) queda bloqueado con "Romi Cars no puede incorporar
      clientes" porque el portafolio **no está verificado**. Camino que funciona: QR desde la
      Bandeja de entrada de Business Suite, con una página sin WhatsApp vinculado (Romi Cars ya
      tiene el +58 424-4205394), y después el formulario manual de Chatwoot. Luego: asignar la WABA
      al usuario del sistema, limpiar el override del número (`clear_phone_number_callback_override`)
      para que pase por n8n. No hace falta tocar n8n: Chatwoot elige la bandeja por el
      `phone_number_id` del payload. El traspaso desde Facebook/Instagram sigue yendo al número
      principal (primera bandeja de WhatsApp).
- [ ] **Verificar el portafolio Romi Cars** en Meta (Centro de seguridad): habilita el registro
      insertado y sube los límites de mensajes.
- [x] Probar el bot en Instagram y WhatsApp (04/10, con `prueba-bot`). Falta conectarlo: punto 2
      de "Punto exacto donde quedamos".
- [ ] Detalles del bot: si el cliente ya dijo la marca ("la bomba Chery") igual pregunta cuál
      prefiere; en la pregunta técnica no actualizó la prioridad.
- [ ] Unos pocos perfiles que no se distinguen de un nombre ("aireaccel", "trabajo") se usan para
      saludar.
- [ ] Probar el echo: escribir desde la app WhatsApp Business y ver si entra como saliente.
- [ ] Mensajes `This message is unavailable.`: sincronización de coexistence (error 131060).
      Ver si siguen apareciendo:
      `Message.where(content: 'This message is unavailable.').group('DATE(created_at)').count`.
- [ ] Que el job de seguimiento mande la plantilla Utility cuando la ventana esté cerrada
      (hoy cancela como `fuera_de_ventana`).
- [ ] RuboCop: ~140 offenses, casi todas heredadas en `romicars_analytics_controller.rb`.
      `lint-frontend`, `lint-backend` y `security-scan` fallan en todos los PRs por deuda anterior.
- [ ] La barra de comandos del escritorio busca rutas que el fork quitó (captain, portals,
      attributes, automation, macros, applications) y llena la consola de errores.
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
