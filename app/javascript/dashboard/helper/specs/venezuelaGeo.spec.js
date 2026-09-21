import {
  MAP_W,
  MAP_H,
  toSvg,
  VENEZUELA_OUTLINE,
  VENEZUELA_PATH,
} from '../venezuelaGeo';

// Ray casting in (lng, lat). Lives here rather than in the helper because the app only
// ever draws the outline — nothing in production needs to ask whether a point is inside it.
const isInside = (lat, lng, polygon = VENEZUELA_OUTLINE) => {
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i, i += 1) {
    const [latI, lngI] = polygon[i];
    const [latJ, lngJ] = polygon[j];
    const straddles = latI > lat !== latJ > lat;
    if (
      straddles &&
      lng < ((lngJ - lngI) * (lat - latI)) / (latJ - latI) + lngI
    ) {
      inside = !inside;
    }
  }
  return inside;
};

describe('venezuelaGeo', () => {
  describe('toSvg', () => {
    it('puts the north west corner at the origin and the south east at the far corner', () => {
      expect(toSvg(12.2, -73.4)).toEqual({ x: 0, y: 0 });
      expect(toSvg(0.6, -59.8)).toEqual({ x: MAP_W, y: MAP_H });
    });

    it('keeps the canvas in proportion instead of flattening the country', () => {
      // 13.6 degrees of longitude here are roughly 1495km against 1288km of latitude.
      expect(MAP_W / MAP_H).toBeCloseTo(1.16, 1);
    });

    it('places Caracas just past the middle and near the top, where it belongs', () => {
      const { x, y } = toSvg(10.49, -66.88);
      expect(x / MAP_W).toBeCloseTo(0.48, 1);
      expect(y / MAP_H).toBeCloseTo(0.15, 1);
    });
  });

  describe('VENEZUELA_OUTLINE', () => {
    // The point of the outline is that a customer dot lands on the right side of a border.
    // Every one of these was checked against the coordinates of the real place.
    it.each([
      ['Caracas', 10.49, -66.88],
      ['Maracaibo', 10.65, -71.64],
      ['Valencia', 10.18, -68.0],
      ['Barquisimeto', 10.07, -69.32],
      ['Maracay', 10.25, -67.6],
      ['Puerto Ordaz', 8.3, -62.72],
      ['Puerto Ayacucho', 5.66, -67.62],
      ['San Cristóbal', 7.77, -72.22],
      ['San Antonio del Táchira', 7.81, -72.44],
      ['Barcelona', 10.13, -64.68],
      ['Cumaná', 10.45, -64.18],
      ['Mérida', 8.6, -71.14],
      ['Maturín', 9.75, -63.18],
      ['Coro', 11.4, -69.67],
      ['Barinas', 8.62, -70.21],
      ['Valera', 9.32, -70.6],
      ['Acarigua', 9.56, -69.19],
      ['Cabimas', 10.39, -71.45],
      ['Guanare', 9.04, -69.75],
      ['El Tigre', 8.89, -64.25],
    ])('contains %s', (_city, lat, lng) => {
      expect(isInside(lat, lng)).toBe(true);
    });

    // The near ones matter most: Cúcuta and Arauca sit on the border and an outline that
    // is a tenth of a degree off swallows them.
    it.each([
      ['Cúcuta, Colombia', 7.89, -72.51],
      ['Arauca, Colombia', 7.09, -70.76],
      ['Puerto Carreño, Colombia', 6.19, -67.49],
      ['Riohacha, Colombia', 11.54, -72.91],
      ['Valledupar, Colombia', 10.46, -73.25],
      ['Bogotá, Colombia', 4.71, -74.07],
      ['Georgetown, Guyana', 6.8, -58.16],
      ['Boa Vista, Brazil', 2.82, -60.67],
      ['Manaus, Brazil', -3.11, -60.02],
      ['Trinidad', 10.65, -61.22],
      ['Curaçao', 12.17, -68.99],
    ])('excludes %s', (_place, lat, lng) => {
      expect(isInside(lat, lng)).toBe(false);
    });
  });

  describe('VENEZUELA_PATH', () => {
    it('is a closed path built from the outline', () => {
      expect(VENEZUELA_PATH).toMatch(/^M /);
      expect(VENEZUELA_PATH).toMatch(/ Z$/);
      expect(VENEZUELA_PATH.match(/[ML] /g)).toHaveLength(
        VENEZUELA_OUTLINE.length
      );
    });

    it('stays inside the canvas', () => {
      VENEZUELA_OUTLINE.forEach(([lat, lng]) => {
        const { x, y } = toSvg(lat, lng);
        expect(x).toBeGreaterThanOrEqual(0);
        expect(x).toBeLessThanOrEqual(MAP_W);
        expect(y).toBeGreaterThanOrEqual(0);
        expect(y).toBeLessThanOrEqual(MAP_H);
      });
    });
  });
});
