import { calcCostBs, calcBolivares } from '../vehiclePriceHelper';

// equiv_13 is the BCV rate plus the markup: at 13%, a rate of 100 Bs/USD gives 113.
const rate = { rate: 100, equiv_13: 113 };

describe('vehiclePriceHelper', () => {
  it('converts a cash price to bolivares at the rate plus 13%', () => {
    expect(calcCostBs(15, rate)).toBe(1695);
  });

  it('gives the USD-at-BCV price that yields the same bolivares', () => {
    // 15 USD cash -> 1695 Bs -> 16.95 USD at the plain BCV rate, rounded.
    expect(calcBolivares(15, rate)).toBe(17);
  });

  it('follows whatever markup the rate was stored with', () => {
    // 20% instead of 13%: 15 USD cash -> 1800 Bs -> 18 USD at the plain BCV rate.
    expect(calcBolivares(15, { rate: 100, equiv_13: 120 })).toBe(18);
  });

  it('returns null without a price or a rate', () => {
    expect(calcCostBs(null, rate)).toBeNull();
    expect(calcCostBs(15, null)).toBeNull();
    expect(calcBolivares(0, rate)).toBeNull();
  });
});
