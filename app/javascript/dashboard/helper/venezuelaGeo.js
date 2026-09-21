// Projection and outline for the customer map.
//
// The outline is kept in lat/lng and goes through the same `toSvg` as the customer dots.
// It used to be hand-drawn directly in SVG units, so the two never shared a coordinate
// system: a dot for Caracas would have landed nowhere near the coast it was drawn on.

export const MAP_W = 500;
export const LAT_MIN = 0.6;
export const LAT_MAX = 12.2;
export const LNG_MIN = -73.4;
export const LNG_MAX = -59.8;

// Height from the real proportions rather than a round number. At this latitude the 13.6
// degrees of longitude span about 1495 km against 1288 km of latitude, so the 500x300
// canvas this replaces squashed the country flat.
export const MAP_H = Math.round(
  (MAP_W * (LAT_MAX - LAT_MIN)) /
    ((LNG_MAX - LNG_MIN) *
      Math.cos((((LAT_MIN + LAT_MAX) / 2) * Math.PI) / 180))
);

export function toSvg(lat, lng) {
  return {
    x: ((lng - LNG_MIN) / (LNG_MAX - LNG_MIN)) * MAP_W,
    y: MAP_H - ((lat - LAT_MIN) / (LAT_MAX - LAT_MIN)) * MAP_H,
  };
}

// Coarse but anchored on the real extremes and on the border towns, which is what keeps
// dots on the right side of a frontier. Vertices are [lat, lng], clockwise from the Guajira.
export const VENEZUELA_OUTLINE = [
  [11.85, -71.33], // Castilletes, Colombian border on the Guajira
  [11.4, -70.2],
  [12.2, -69.95], // Paraguaná, northernmost point
  [11.45, -69.6],
  [10.95, -68.35],
  [10.6, -67.1], // La Guaira
  [10.3, -65.9],
  [10.2, -64.7], // Barcelona
  [10.55, -64.2], // Cumaná and the Araya peninsula
  [10.65, -63.2],
  [10.72, -61.9], // Paria
  [9.8, -62.3],
  [8.55, -59.85], // Punta Playa, eastern limit
  [7.0, -60.2],
  [6.2, -61.1],
  [5.2, -60.75], // Roraima
  [4.2, -61.5],
  [3.6, -63.4],
  [1.3, -66.2],
  [0.65, -66.95], // Piedra del Cocuy, southernmost point
  [1.9, -67.1],
  [3.8, -67.6],
  [5.65, -67.72], // the Orinoco opposite Puerto Ayacucho
  [6.2, -67.45],
  [7.15, -70.8], // the Arauca, which runs north of the Colombian town
  [7.1, -71.8],
  [7.82, -72.47], // San Antonio del Táchira, east of Cúcuta
  [7.95, -72.49],
  [9.0, -72.75],
  [9.8, -73.15], // Sierra de Perijá, western limit
  [10.5, -72.4],
  [11.1, -71.95],
];

export const VENEZUELA_PATH = `${VENEZUELA_OUTLINE.map(([lat, lng], index) => {
  const { x, y } = toSvg(lat, lng);
  return `${index === 0 ? 'M' : 'L'} ${x.toFixed(1)},${y.toFixed(1)}`;
}).join(' ')} Z`;
