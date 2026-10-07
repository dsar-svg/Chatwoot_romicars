// Combos and promotions share the price list with parts (VehiclePrice::KINDS). The bot reads
// all three: parts through the part search, combos and promotions through their own tool.
export const PRICE_KINDS = {
  repuesto: {
    tab: 'Repuestos',
    count: 'repuestos',
    column: 'Repuesto',
    newLabel: 'Nuevo repuesto',
    empty: 'No hay repuestos cargados',
    placeholder: 'Ej: AMORTIGUADOR TRASERO',
  },
  combo: {
    tab: 'Combos',
    count: 'combos',
    column: 'Combo',
    newLabel: 'Nuevo combo',
    empty: 'No hay combos cargados',
    placeholder: 'Ej: COMBO DE FILTROS',
    detailsLabel: 'Qué incluye',
    detailsPlaceholder:
      'Ej: filtro de aceite, filtro de aire y filtro de gasolina',
  },
  promocion: {
    tab: 'Promociones',
    count: 'promociones',
    column: 'Promoción',
    newLabel: 'Nueva promoción',
    empty: 'No hay promociones cargadas',
    placeholder: 'Ej: 10% EN PASTILLAS DE FRENO',
    detailsLabel: 'Detalles y condiciones',
    detailsPlaceholder: 'Ej: pagando en divisas, hasta agotar existencia',
  },
};

export const kindOf = price => price.kind || 'repuesto';

// "2026-10-31" -> "31/10/2026"
export const formatDate = value =>
  value ? value.split('-').reverse().join('/') : '';

// An ends_on in the past: the bot stops offering it, the list says so.
export const isExpired = price =>
  Boolean(price.ends_on) &&
  price.ends_on < new Date().toLocaleDateString('en-CA');
