# Guía del bot de atención — RomiCars

Para vendedores y para quien administre Chatwoot. Explica qué hace el bot, qué deja en
manos de una persona y por qué.

## Dónde está activo

| Canal | Bot | Quién atiende |
|---|---|---|
| Facebook (páginas Romi Cars y Erdu) | activo | el bot primero, después un vendedor |
| Instagram (somosromicars) | apagado, en pruebas | vendedores |
| WhatsApp (+58 424-4205394) | apagado, en pruebas | vendedores |

El bot se enciende por bandeja en **Ajustes → Bandejas → (bandeja) → Bot**. Solo contesta
conversaciones que están asignadas a él (estado *Pendiente*). En cuanto una conversación pasa a
un vendedor, el bot deja de escribir en ella.

## Qué hace el bot

- **Saluda y pide nombre y ciudad** si faltan, y los guarda en el contacto.
- **Cotiza** con la lista de precios: precio a tasa BCV y en divisas. Si hay variantes (corto/largo),
  pregunta cuál. Si el cliente manda una lista, cotiza cada repuesto y dice cuáles no hay.
- **Entiende audios y fotos**: transcribe el audio y describe la foto de la pieza. Una foto le dice
  qué pieza es, nunca de qué carro: siempre pide marca y modelo.
- **Responde preguntas frecuentes** (ubicación, envíos, delivery, garantía, métodos de pago) desde
  la tabla de FAQs. Lo que no está en esa tabla no lo contesta: pasa la conversación a un vendedor.
- **Cierra** la conversación cuando el cliente solo preguntaba algo y quedó resuelto, o cuando dice
  que no compra. En ese caso le pregunta una sola vez por qué (precio, tiempo de entrega o que no
  teníamos la pieza) y lo registra para el informe.
- **Pospone** la conversación cuando el cliente dice que compra en una fecha ("cobro el viernes"):
  vuelve a la bandeja ese día a las 9 am.

### Ventas desde Facebook e Instagram: el traspaso a WhatsApp

La tienda vende por los Estados de WhatsApp, que solo ve quien tiene el número de la tienda
guardado. Por eso una venta de Facebook o Instagram no se cierra ahí:

1. El bot cotiza. Cuando el cliente confirma que lo quiere, le manda un **link de WhatsApp** con el
   mensaje ya escrito, que termina en un código como `RC-7K2QM`.
2. El cliente toca el link y envía. Chatwoot reconoce el código, **une los dos contactos** (queda
   uno solo, con el número verificado por WhatsApp y el nombre que dio en Facebook), cierra la
   conversación de Facebook como *Pasó a WhatsApp* y deja una línea en los dos hilos:
   *"Viene de Romi Cars (conversación #314) por sensor de cigüeñal largo para CHERY ORINOCO."*
3. **El vendedor atiende la conversación de WhatsApp.** Ahí está todo lo que se habló: no hace falta
   volver a preguntar el repuesto ni el carro.

Si el cliente prefiere que le escriban, puede dar su número en el chat: el bot lo guarda en el
contacto y pasa la conversación a un vendedor para que le escriba por WhatsApp.

El código `RC-…` es interno. El cliente no tiene que hacer nada con él, y el bot nunca lo menciona.

## Qué NO hace el bot, y por qué

| Caso | Qué hace el bot | Por qué |
|---|---|---|
| **Fotos de la pieza, la marca o el empaque** | Dice que un asesor se las manda, deja nota y asigna vendedor | No hay catálogo de fotos. El vendedor las toma o las busca |
| **Medidas, número de parte, compatibilidad** ("¿le sirve al Tiggo?") | Deja nota con la pregunta y asigna vendedor | La lista de precios no trae esos datos. Una medida equivocada le daña el carro al cliente |
| **Preguntas que no están en las FAQs** (horario, promos, políticas…) | Dice que lo confirma con el equipo | No inventa. Se resuelve cargando la FAQ (ver abajo) |
| **Disponibilidad en inventario** | Da el precio y ofrece confirmar disponibilidad; nunca dice "lo tengo" | La lista de precios no tiene cantidades |
| **Delivery: coordinar la entrega y la nota de entrega** (nombre, cédula, ubicación) | Informa que hay delivery (FAQ) | El costo depende de la zona y la nota la hace el vendedor |
| **Cobrar, confirmar pagos, devoluciones** | Nada; lo deja al vendedor | Son decisiones de la tienda |
| **Marcas que la tienda no trabaja** | Dice con amabilidad que para ese carro no maneja repuestos | Lo decide la lista de marcas cargada en el sistema |
| **Escribirle a un cliente pasadas 24 h** de su último mensaje | No puede | Regla de Meta: fuera de esa ventana solo se pueden mandar plantillas aprobadas |

## Lo que tiene que hacer el vendedor

- **Tomar las conversaciones asignadas** y leer la **nota privada** que dejó el bot: tiene el carro,
  los repuestos, los precios dados y el motivo del pase.
- **Cerrar con resultado** cuando termina (venta, perdida o consulta): alimenta el informe.
- **Etiquetar `proveedor` o `logistica`** los números que no son clientes. Así no cuentan como
  leads, no pasan por el bot y no reciben seguimiento.
- **Fuera de la ventana de 24 h**, usar la plantilla `seguimiento_pedido` desde el editor, o
  contestar desde la app de WhatsApp Business del teléfono.

## Datos que mantiene la tienda

El bot solo es tan bueno como estos datos:

- **FAQs** (tabla `faqs`): hoy hay ubicación, envíos, delivery, garantía y métodos de pago.
  **Faltan**: horario, promociones vigentes, costo del delivery por zona, si Zelle cuenta como
  divisa y la política de devoluciones.
- **Lista de precios** (`vehicle_prices`): descripción, variante y sinónimos. Un sinónimo que falta
  es un repuesto que el bot no encuentra.
- **Marcas y modelos** (`vehicle_brands`, `vehicle_models`): lo que no está aquí, el bot lo trata
  como una marca que no se trabaja.

## Plantilla `seguimiento_pedido`

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

## Seguimiento automático

Se enciende en **Ajustes → Flujo de conversación → Seguimiento automático** (solo administradores).
Está **apagado** por defecto. Si el cliente deja de contestar, el sistema le manda un recordatorio
a las horas configuradas y, si sigue sin responder, cierra la conversación como *abandonada* a las
48 h. No escribe fuera de la ventana de 24 h.
