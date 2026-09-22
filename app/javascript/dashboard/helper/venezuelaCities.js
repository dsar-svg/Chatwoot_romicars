// City and state coordinates for the contact heat map.
//
// The backend hands back whatever string was stored on the contact ("Valencia",
// "valencia, carabobo", "Edo. Zulia"), because that is what a person types or a bot
// captures. Turning it into a point is a lookup problem, not a geocoding one: the shop
// sells in one country and the list of places its customers write from is short.
//
// States resolve to their capital. A contact that only says "Zulia" is worth plotting on
// Maracaibo — the alternative is dropping it, and the map is about which region writes
// most, not which street.

export const VENEZUELA_PLACES = {
  // Capital region
  caracas: [10.49, -66.88],
  'distrito capital': [10.49, -66.88],
  'la guaira': [10.6, -66.93],
  vargas: [10.6, -66.93],
  'catia la mar': [10.6, -67.03],
  'los teques': [10.34, -67.04],
  miranda: [10.3, -66.6],
  guarenas: [10.47, -66.61],
  guatire: [10.47, -66.54],
  charallave: [10.24, -66.86],
  cua: [10.16, -66.89],
  'ocumare del tuy': [10.11, -66.77],
  'san antonio de los altos': [10.36, -66.96],
  higuerote: [10.48, -66.1],

  // Zulia
  maracaibo: [10.65, -71.64],
  zulia: [10.65, -71.64],
  cabimas: [10.39, -71.45],
  'ciudad ojeda': [10.2, -71.31],
  lagunillas: [10.13, -71.26],
  machiques: [10.06, -72.56],
  'santa barbara del zulia': [9.0, -71.92],
  'san carlos del zulia': [9.0, -71.93],

  // Carabobo and Aragua
  valencia: [10.18, -68.0],
  carabobo: [10.18, -68.0],
  guacara: [10.23, -67.88],
  'puerto cabello': [10.47, -68.01],
  moron: [10.49, -68.2],
  maracay: [10.25, -67.6],
  aragua: [10.25, -67.6],
  turmero: [10.23, -67.47],
  cagua: [10.19, -67.46],
  'la victoria': [10.23, -67.33],
  'villa de cura': [10.04, -67.49],

  // Lara, Yaracuy, Falcon
  barquisimeto: [10.07, -69.32],
  lara: [10.07, -69.32],
  cabudare: [10.02, -69.27],
  carora: [10.18, -70.08],
  'el tocuyo': [9.79, -69.79],
  'san felipe': [10.34, -68.74],
  yaracuy: [10.34, -68.74],
  yaritagua: [10.08, -69.13],
  coro: [11.4, -69.67],
  falcon: [11.4, -69.67],
  'punto fijo': [11.69, -70.2],

  // Andes
  merida: [8.6, -71.14],
  ejido: [8.55, -71.24],
  'el vigia': [8.62, -71.65],
  'san cristobal': [7.77, -72.22],
  tachira: [7.77, -72.22],
  'san antonio del tachira': [7.81, -72.44],
  rubio: [7.7, -72.36],
  'la fria': [8.22, -72.24],
  trujillo: [9.37, -70.44],
  valera: [9.32, -70.6],
  barinas: [8.62, -70.21],

  // Llanos
  guanare: [9.04, -69.75],
  portuguesa: [9.04, -69.75],
  acarigua: [9.56, -69.19],
  araure: [9.57, -69.22],
  'san carlos': [9.66, -68.59],
  cojedes: [9.66, -68.59],
  tinaquillo: [9.92, -68.3],
  'san juan de los morros': [9.9, -67.35],
  guarico: [9.9, -67.35],
  calabozo: [8.92, -67.43],
  'valle de la pascua': [9.21, -66.01],
  'san fernando de apure': [7.9, -67.47],
  apure: [7.9, -67.47],

  // Oriente
  barcelona: [10.13, -64.68],
  anzoategui: [10.13, -64.68],
  'puerto la cruz': [10.22, -64.62],
  lecheria: [10.19, -64.68],
  'el tigre': [8.89, -64.25],
  anaco: [9.43, -64.47],
  'puerto piritu': [10.06, -65.04],
  cumana: [10.45, -64.18],
  sucre: [10.45, -64.18],
  carupano: [10.67, -63.25],
  maturin: [9.75, -63.18],
  monagas: [9.75, -63.18],
  porlamar: [10.95, -63.85],
  'nueva esparta': [10.95, -63.85],
  margarita: [10.95, -63.85],
  pampatar: [10.99, -63.8],
  'la asuncion': [11.03, -63.86],
  juangriego: [11.08, -63.97],

  // Guayana and the south
  'ciudad bolivar': [8.13, -63.55],
  bolivar: [8.13, -63.55],
  'ciudad guayana': [8.3, -62.72],
  'puerto ordaz': [8.3, -62.72],
  'san felix': [8.38, -62.65],
  upata: [8.01, -62.4],
  'santa elena de uairen': [4.6, -61.11],
  tucupita: [9.06, -62.05],
  'delta amacuro': [9.06, -62.05],
  'puerto ayacucho': [5.66, -67.62],
  amazonas: [5.66, -67.62],
};

// Longest first so "san cristobal" wins over "cristobal" and "ciudad guayana" over
// "guayana" when the stored string carries more than the city.
const KEYS = Object.keys(VENEZUELA_PLACES).sort((a, b) => b.length - a.length);

const normalize = value =>
  String(value ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z]+/g, ' ')
    .trim();

export function locatePlace(raw) {
  const text = normalize(raw);
  if (!text) return null;
  if (VENEZUELA_PLACES[text]) return VENEZUELA_PLACES[text];

  // "Valencia, Carabobo", "Edo Zulia", "municipio Maracaibo" all carry the place inside a
  // longer string. Substring on word boundaries rather than `includes`, so "cua" does not
  // match "Guacara".
  const key = KEYS.find(k => new RegExp(`\\b${k}\\b`).test(text));
  return key ? VENEZUELA_PLACES[key] : null;
}

// Groups the rows the API returns onto points. Several labels can land on one place
// ("Pto Ordaz" and "Ciudad Guayana"), and those counts belong together on the map.
export function toHeatPoints(locations = []) {
  const points = new Map();

  locations.forEach(({ label, count }) => {
    const place = locatePlace(label);
    if (!place) return;

    const id = place.join(',');
    const current = points.get(id) || {
      lat: place[0],
      lng: place[1],
      count: 0,
      labels: [],
    };
    current.count += Number(count) || 0;
    current.labels.push(label);
    points.set(id, current);
  });

  return [...points.values()].sort((a, b) => b.count - a.count);
}
