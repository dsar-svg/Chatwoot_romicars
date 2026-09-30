# Guía de RomiCars: sistema y bot de atención

Para quien administra RomiCars y para los vendedores. Explica qué hace el sistema, qué hace el
bot, qué deja en manos de una persona y por qué.

Estado al 30/09/2026.

## 1. El sistema

RomiCars corre sobre Chatwoot, una bandeja de mensajes compartida. Todas las conversaciones de
Facebook, Instagram y WhatsApp llegan a un solo lugar, y cada una la atiende el bot o un vendedor.

### Bandejas (canales)

| Bandeja | Canal | Bot | Quién atiende hoy |
|---|---|---|---|
| Romi Cars | Facebook | **activo** | el bot primero, después un vendedor |
| somosromicars | Instagram | apagado | vendedores |
| WABA RomiCars (+58 424-4205394) | WhatsApp | apagado | vendedores |
| Erdu | Facebook (página de pruebas) | — | se va a borrar |

El bot se enciende por bandeja en **Ajustes → Bandejas → (bandeja) → Bot**. Encenderlo en
WhatsApp o Instagram cambia cómo trabajan los vendedores en ese canal: es una decisión de la
tienda.

### Estados de una conversación

- **Pendiente**: la tiene el bot. Solo contesta estas.
- **Abierta**: la tiene un vendedor. El bot ya no escribe.
- **Pospuesta**: vuelve sola a la bandeja en la fecha indicada.
- **Resuelta**: cerrada. Si el cliente vuelve a escribir, se reabre o empieza una nueva.

### Asignación a vendedores

- Las conversaciones se reparten **por turnos entre los vendedores conectados**, empezando por la
  que más espera (política *Reparto RomiCars*, en las cuatro bandejas).
- Solo reciben conversaciones los vendedores que son **miembros de la bandeja** y están
  **conectados** (disponibles). Se agregan en **Ajustes → Bandejas → (bandeja) → Colaboradores**.
- Si llega una conversación y no hay nadie conectado, queda sin asignar. El sistema lo vuelve a
  intentar **cada 30 minutos**, así que se reparte en cuanto alguien se conecte.
- Las conversaciones sin actividad hace más de **7 días** no se reparten solas: quedan en
  *Sin asignar* para que alguien decida qué hacer con ellas.
- Cuando el bot pasa una conversación a un vendedor y no hay nadie conectado, llega una alerta
  por Telegram.

### Etiquetas especiales

| Etiqueta | Para qué | Efecto |
|---|---|---|
| `proveedor` | Proveedores de la tienda | El bot no los atiende, no reciben seguimiento, no cuentan en el dashboard |
| `logistica` | El motorizado, delivery | Igual que proveedor |
| `interno` | Números propios de RomiCars (el segundo WhatsApp) | Igual que proveedor |
| `derivado-whatsapp` | La pone el bot | Marca las conversaciones de Facebook/Instagram que se mandaron a WhatsApp |

Las tres primeras se ponen en el **contacto**: valen para todas sus conversaciones, pasadas y
futuras. Un proveedor que todavía no escribió se puede crear como contacto con su número y la
etiqueta: cuando escriba, Chatwoot lo reconoce por el teléfono.

### Cerrar con resultado

Al resolver, el vendedor elige cómo terminó:

- **Ganada**: hubo venta (se puede anotar monto y factura).
- **Perdida**: no compró. Pide el motivo: precio, tiempo de entrega, sin stock u otro.
- **Consulta**: solo preguntaba algo.

Dos resultados los pone el sistema solo: **Pasó a WhatsApp** (el cliente llegó a WhatsApp con su
código) y **Abandonada** (dejó de contestar, si el seguimiento automático está activo).

Sin resultado, el dashboard no puede medir ventas ni conversión.

### Difusiones desde el teléfono

La tienda usa la app de WhatsApp Business en el teléfono junto con Chatwoot (coexistencia). Una
**difusión** enviada desde el teléfono llega a Chatwoot como una conversación nueva por cada
destinatario, aunque el cliente no conteste.

- El dashboard no las cuenta: solo cuenta a los clientes que escribieron.
- Quedan abiertas en la bandeja. Se pueden cerrar sin problema: si el cliente responde, su mensaje
  entra igual.

### Dashboard

En el menú **Dashboard** (administradores). Todo se calcula sobre los últimos 30 días y solo con
clientes: deja fuera proveedores, logística, números internos y difusiones sin respuesta.

| Bloque | Qué muestra | De dónde sale |
|---|---|---|
| Total leads | Personas distintas que escribieron | Conversaciones con al menos un mensaje del cliente |
| Conversión | Leads con una venta registrada | Conversaciones cerradas como *Ganada* |
| Mini métricas | Nuevos hoy, pendientes, urgentes, en bot, en vendedor, resueltos hoy | Estado actual. Cada tarjeta abre la lista |
| Rendimiento por agente | Conversaciones asignadas, ventas y tiempo de primera respuesta | Asignaciones y cierres de cada vendedor |
| Demanda e interés | Repuestos más buscados y por canal | Cada búsqueda de precio que hace el bot |
| Resolución | Ganadas, perdidas por motivo, consultas, abandonadas, pasadas a WhatsApp | Cierres con resultado |
| ¿De dónde nos escriben? | Mapa por ciudad | Ciudad guardada en el contacto (la pregunta el bot) |
| Productos Profit | Más y menos vendidos | Sistema Profit de la tienda (**no conectado**) |
| Insights IA | Hallazgos y acciones sugeridas, ventas ganadas vs. perdidas | GPT sobre las cifras de arriba. Se actualiza cada 3 horas |

Si los vendedores no cierran con resultado, la conversión y la resolución quedan en cero, y la IA
lo dice así ("no se están registrando los resultados").

### Precios y marcas

**Ajustes → Precios** y **Ajustes → Marcas**. El bot cotiza solo con lo que está ahí:

- **Descripción**: el nombre de la pieza. El bot da prioridad a la pieza cuyo nombre empieza con
  lo que pidió el cliente.
- **Variante / modelo**: para qué carro es.
- **Sinónimos**: otras formas de llamarla (balata, pastillas, eje de levas…). Un sinónimo que
  falta es un repuesto que el bot no encuentra.
- **Precio en divisas y a tasa BCV**, y la tasa del día.

### App para el teléfono

Los vendedores pueden instalar RomiCars como app en el teléfono: abrir
`https://asta-chatwoot.larlxe.easypanel.host/app/m` en Chrome e **Instalar app** desde el menú ⋮.

Trae: conversaciones (con filtro por canal y estado), responder, asignar, etiquetar, posponer y
cerrar con resultado; contactos (buscar, llamar, abrir WhatsApp); marcas y precios; y el
dashboard para administradores. Lo demás se hace desde la versión completa (Ajustes → Abrir
versión completa).

### Resumen diario por Telegram

Todos los días a las **7 pm** llega por Telegram:

1. Lo que el bot no pudo responder: preguntas que las FAQ no contestan, preguntas técnicas,
   pedidos de fotos y quejas, con el número de conversación.
2. Los repuestos que buscaron y no estaban en la lista de precios.

Sirve para saber qué FAQ cargar y qué repuestos o sinónimos agregar.

### Seguimiento automático

**Ajustes → Flujo de conversación → Seguimiento automático** (administradores). Está
**apagado**. Encendido, si el cliente deja de contestar le manda un recordatorio a las horas
configuradas; a los que se mandó a WhatsApp y no llegaron les pregunta si pudieron escribir. Si
sigue sin responder, cierra la conversación como *Abandonada* a las 48 h. Nunca escribe fuera de
la ventana de 24 h.

## 2. El bot

### Qué hace

- **Saluda y pide los datos que faltan**: nombre y apellido, y ciudad. Los guarda en el contacto.
  - Si el perfil de WhatsApp o Facebook no es un nombre (un negocio, una frase, un usuario con
    números, emojis sueltos), pregunta el nombre.
  - Si solo tiene el primer nombre, pregunta el apellido **una sola vez**. Si el cliente no lo da,
    no insiste.
  - Al cliente lo llama por su primer nombre, sin emojis ni títulos ("Arq. Lenin Piña 🏙️" →
    "Lenin").
- **Cotiza** con la lista de precios, siempre como "cuesta 28$ a tasa BCV o 25$ en divisas".
  - Si la pieza viene en **posiciones distintas** (delantera/trasera, derecha/izquierda,
    larga/corta, el par), primero pregunta cuál y cotiza cuando el cliente elige.
  - Si viene en **marcas o calidades distintas** (original de planta, original Chery, Bosch), da
    los precios de todas y pregunta cuál prefiere.
  - Si el cliente manda una **lista**, cotiza cada repuesto y dice cuáles no hay.
  - Si una pieza no está, lo dice y ofrece avisar cuando entre.
- **Entiende audios y fotos**: transcribe el audio y describe la foto. Una foto le dice qué pieza
  es, nunca de qué carro: siempre pide marca y modelo.
- **Responde preguntas frecuentes** (ubicación, envíos, delivery, garantía, métodos de pago,
  promociones) con la tabla de FAQ. Lo que no está ahí no lo contesta.
- **Cierra** la conversación cuando el cliente solo preguntaba y quedó resuelto (*Consulta*), o
  cuando dice que no compra (*Perdida*). En ese caso pregunta una sola vez por qué (precio, tiempo
  de entrega o que no teníamos la pieza) y no insiste.
- **Pospone** la conversación cuando el cliente dice que compra en una fecha ("cobro el viernes"):
  vuelve a la bandeja ese día a las 9 am.
- **Marca la prioridad** de cada conversación (urgente, alta, media, baja).
- **Pasa a un vendedor, dejando una nota privada**, cuando:
  - pide fotos de la pieza;
  - hace una pregunta técnica (medidas, compatibilidad, número de parte);
  - pregunta algo que no está en las FAQ;
  - se queja, se molesta o desconfía ("nadie me responde", "esto parece una estafa"): en ese
    caso también sube la prioridad a *alta*;
  - pide hablar con una persona.

### Ventas desde Facebook e Instagram: el pase a WhatsApp

La tienda vende por WhatsApp, así que una venta de Facebook o Instagram no se cierra ahí:

1. El bot cotiza. Cuando el cliente confirma que lo quiere, le manda un **link de WhatsApp** con
   el mensaje ya escrito, que termina en un código como `RC-7K2QM`.
2. El cliente toca el link y envía. Chatwoot reconoce el código, **une los dos contactos** (queda
   uno solo, con el número de WhatsApp y el nombre de Facebook), cierra la conversación de
   Facebook como *Pasó a WhatsApp* y deja una línea en los dos hilos con lo pedido.
3. **El vendedor atiende en WhatsApp**, con todo lo hablado a la vista.

Si el cliente no toca el link y sigue escribiendo en Facebook, el bot lo sigue atendiendo: si
agrega repuestos, actualiza el pedido y manda el link de nuevo con el mismo código.

Si el cliente prefiere que le escriban, puede dar su número: el bot lo guarda y pasa la
conversación a un vendedor para que le escriba por WhatsApp.

El código `RC-…` es interno. El cliente no tiene que hacer nada con él.

## 3. Lo que el bot NO hace, y por qué

| Caso | Qué hace el bot | Por qué |
|---|---|---|
| **Confirmar si hay unidades** | Da el precio y pregunta si lo quiere. Si le preguntan si hay, dice que el vendedor lo confirma al cerrar el pedido | La lista de precios no tiene cantidades. Nunca dice "lo tengo" ni "te lo aparto" |
| **Fotos de la pieza, la marca o el empaque** | Dice que un asesor se las manda y pasa a vendedor | No hay catálogo de fotos |
| **Medidas, número de parte, compatibilidad** ("¿le sirve al Arauca?") | Pasa a vendedor con la pregunta | La lista no trae esos datos. Una medida equivocada le daña el carro al cliente |
| **Preguntas que no están en las FAQ** (horario, costo del delivery, políticas…) | Dice que lo confirma con el equipo y pasa a vendedor | No inventa. Se resuelve cargando la FAQ |
| **Coordinar el delivery** (costo por zona, nota de entrega) | Informa que hay delivery | El costo depende de la zona y la nota la hace el vendedor |
| **Cobrar, confirmar pagos, devoluciones, descuentos** | Nada; lo deja al vendedor | Son decisiones de la tienda |
| **Marcas que la tienda no trabaja** | Dice con amabilidad que para ese carro no maneja repuestos | Sale de la lista de marcas cargada |
| **Escribir pasadas 24 h** del último mensaje del cliente | No puede | Regla de Meta. Fuera de esa ventana solo se mandan plantillas aprobadas |
| **Atender WhatsApp e Instagram** | Hoy no los atiende | Está encendido solo en Facebook. Se prende por bandeja |
| **Recordar otras conversaciones** | Recuerda solo la conversación en curso | Cada conversación empieza de cero. Sí recuerda del contacto el nombre, la ciudad y el carro |

Otros límites conocidos:

- **Nombres raros**: unos pocos perfiles no se distinguen de un nombre ("aireaccel", "trabajo") y
  el bot los usa para saludar.
- **Sinónimos**: si el cliente llama a la pieza de una forma que no está en la descripción ni en
  los sinónimos, el bot no la encuentra y la reporta como "no la tenemos" (y aparece en el resumen
  diario).
- **Si Chatwoot se cae** (por ejemplo durante una actualización), el bot reintenta por unos 25
  segundos. Si sigue caído, no responde ese mensaje y llega una alerta por Telegram.

## 4. Lo que tiene que hacer el vendedor

- **Estar conectado** (disponible) para recibir conversaciones.
- **Leer la nota privada** que dejó el bot antes de contestar: tiene el carro, los repuestos, los
  precios dados y el motivo del pase.
- **Confirmar la disponibilidad** antes de cerrar la venta.
- **Cerrar con resultado** (ganada, perdida o consulta): es lo que alimenta el dashboard.
- **Etiquetar** `proveedor`, `logistica` o `interno` los números que no son clientes.
- **Fuera de la ventana de 24 h**, usar la plantilla `seguimiento_pedido` desde el editor, o
  contestar desde la app de WhatsApp Business del teléfono.

## 5. Datos que mantiene la tienda

El bot solo es tan bueno como estos datos:

- **FAQ** (tabla `faqs`): hoy hay ubicación, envíos, delivery, garantía y métodos de pago.
  **Faltan**: horario, promociones vigentes, costo del delivery por zona, si Zelle cuenta como
  divisa y la política de devoluciones. Cada promoción se carga como una FAQ con la palabra
  "promoción" en la pregunta, qué incluye, el precio y para qué carro.
- **Lista de precios**: descripción, variante, sinónimos y precios. Revisar el resumen diario para
  saber qué repuestos o sinónimos faltan.
- **Marcas y modelos**: lo que no está cargado, el bot lo trata como una marca que no se trabaja.
- **Vendedores**: cada vendedor necesita su cuenta y ser miembro de las bandejas donde atiende.

## 6. Plantilla `seguimiento_pedido`

La crea el dueño de la cuenta en **Meta Business → WhatsApp Manager → Plantillas de mensajes →
Crear plantilla**. Sirve para retomar una cotización cuando pasaron más de 24 h desde el último
mensaje del cliente.

| Campo | Valor |
|---|---|
| Categoría | **Utilidad** (Utility) |
| Nombre | `seguimiento_pedido` |
| Idioma | Español |
| Encabezado | ninguno |
| Cuerpo | `Hola {{1}}, te escribimos de Romicars por el {{2}} que consultaste. ¿Seguimos con tu pedido?` |
| Ejemplo de `{{1}}` | `Ricardo` |
| Ejemplo de `{{2}}` | `sensor de cigüeñal para Chery Orinoco` |
| Pie | `Responde a este mensaje y te atendemos.` |
| Botones (respuesta rápida) | `Sí, seguimos` · `Ya no lo necesito` |

Para que Meta la apruebe como **Utilidad** y no la pase a **Marketing** (más cara, y el cliente
puede bloquearla), tiene que referirse a algo que el cliente pidió: por eso nombra el repuesto
consultado y no lleva precios, descuentos, emojis de oferta ni la palabra "promoción". Si Meta la
recategoriza igual, se puede usar como Marketing; solo cambia el costo por mensaje.

Uso: en la conversación, cuando el editor muestra que la ventana de 24 h se cerró, el vendedor
elige la plantilla, completa `{{1}}` con el nombre y `{{2}}` con el repuesto, y la envía.
