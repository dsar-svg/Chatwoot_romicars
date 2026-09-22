import { locatePlace, toHeatPoints } from '../venezuelaCities';

describe('locatePlace', () => {
  it('finds a city written plainly', () => {
    expect(locatePlace('Valencia')).toEqual([10.18, -68.0]);
  });

  it('ignores case and accents, which is how people actually type', () => {
    expect(locatePlace('MARACAIBO')).toEqual([10.65, -71.64]);
    expect(locatePlace('Mérida')).toEqual(locatePlace('merida'));
    expect(locatePlace('San Cristóbal')).toEqual([7.77, -72.22]);
  });

  it('pulls the city out of a longer string', () => {
    expect(locatePlace('Valencia, Carabobo')).toEqual([10.18, -68.0]);
    expect(locatePlace('Edo. Zulia')).toEqual([10.65, -71.64]);
    expect(locatePlace('municipio Maracaibo')).toEqual([10.65, -71.64]);
  });

  it('prefers the longest match so the specific name wins', () => {
    expect(locatePlace('San Antonio del Táchira')).toEqual([7.81, -72.44]);
    expect(locatePlace('Ciudad Guayana')).toEqual([8.3, -62.72]);
  });

  it('matches whole words only', () => {
    // "cua" is a town; "Guacara" is a different one and must not resolve to it.
    expect(locatePlace('Guacara')).toEqual([10.23, -67.88]);
  });

  it('falls back to the state capital', () => {
    expect(locatePlace('Anzoátegui')).toEqual([10.13, -64.68]);
  });

  it('answers null for anything it cannot place', () => {
    expect(locatePlace('')).toBeNull();
    expect(locatePlace(null)).toBeNull();
    expect(locatePlace('Bogotá')).toBeNull();
    expect(locatePlace('no sé')).toBeNull();
  });
});

describe('toHeatPoints', () => {
  it('adds up labels that name the same place', () => {
    const points = toHeatPoints([
      { label: 'Puerto Ordaz', count: 4 },
      { label: 'Ciudad Guayana', count: 3 },
      { label: 'Caracas', count: 10 },
    ]);

    expect(points).toHaveLength(2);
    expect(points[0]).toMatchObject({ count: 10, lat: 10.49, lng: -66.88 });
    expect(points[1].count).toBe(7);
    expect(points[1].labels).toEqual(['Puerto Ordaz', 'Ciudad Guayana']);
  });

  it('drops rows it cannot place instead of guessing', () => {
    expect(toHeatPoints([{ label: 'Miami', count: 5 }])).toEqual([]);
    expect(toHeatPoints()).toEqual([]);
  });
});
