# Estado actual — 4 de octubre de 2026

Dónde quedó el trabajo, para retomarlo desde otra máquina sin el historial del chat.
Actualizado al cierre de la sesión del 4 de octubre. Qué hace el sistema, qué hace y qué no
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

- **El bot inventa el horario.** `buscar_faq` devuelve vacío (no hay FAQ de horario) y aun así
  GPT-4o contestó "lunes a viernes 8 a 5, sábados 8 a 12", contra lo que dice el prompt. Se
  corrige cargando la FAQ; mientras falte, el riesgo sigue.
- El filtro de aceite del Chery Orinoco quedó **agotado** en producción desde las pruebas del
  02/10. Confirmar si es real.
- Detalles del bot: preguntó el motivo de la pérdida cuando el cliente ya había dicho "muy caro";
  con dos marcas cotizadas y un "la quiero" no preguntó cuál; no volvió a guardar el vehículo
  cuando el cliente lo corrigió.
- Insights IA y Operación muestran dos "conversión" distintas (ganadas ÷ ganadas + perdidas
  contra ventas ÷ leads); el texto de la IA dice `FacebookPage` y minutos sin convertir.
- Sin probar: ventana de 24 h, envío de fotos, teléfono válido en Instagram y el vencimiento de
  un pospuesto (solo lo cubre el spec).
- En esta máquina no hay Postgres, `node_modules` ni `gh`: los specs y ESLint de #91 y #92 solo
  corrieron en CI.

## Punto exacto donde quedamos

Bot probado en Facebook, WhatsApp e Instagram. Para salir a producción:

1. **Vendedores** (bloqueante): hoy solo existen Dario y Moises, y Dario es el único miembro de
   las bandejas, así que todo lo asignado le cae a él (417 conversaciones el 02/10). Crear las
   cuentas en **Ajustes → Agentes** y agregarlos a las bandejas (sobre todo WABA RomiCars).
   Después, verificar que el reparto les llegue y redistribuir lo que acumuló Dario.
2. **Conectar el bot a WhatsApp e Instagram** cuando la clienta lo decida. Ya está probado en
   las dos con `prueba-bot` (04/10). Al conectarlo a WhatsApp (inbox 4) solo toma las
   conversaciones **nuevas**: las ~375 abiertas ya tienen vendedor y el bot no contesta ahí.
3. **Marcar los agotados antes de encender el bot en más bandejas**: los 2.139 repuestos están
   `available = true`, así que el bot dice "sí lo tenemos" a todo. Lo más rápido: Importar →
   Descargar plantilla, poner NO en DISPONIBLE y subirla.
4. **Decisiones con la clienta**: qué bandejas lleva el bot y seguimiento automático (hoy
   `followups_enabled: false`). Que los vendedores **cierren con resultado**: sin eso el
   dashboard queda en 0 % de conversión.
5. **FAQs que faltan**, con datos de la tienda: horario, promociones, costo de delivery por zona,
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

9. **Plantilla Utility** en Meta (la crea el dueño): `seguimiento_pedido`, español. Texto y
   ejemplos en [GUIA-BOT.md](GUIA-BOT.md#6-plantilla-seguimiento_pedido).

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
