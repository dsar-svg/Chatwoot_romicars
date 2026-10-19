import { periodRange } from '../period';

describe('periodRange', () => {
  // 19 Oct 2026, 15:30 local time.
  const now = new Date(2026, 9, 19, 15, 30);

  it('starts today at local midnight', () => {
    const { since, until } = periodRange('today', {}, now);
    expect(since).toEqual(new Date(2026, 9, 19));
    expect(until).toBeNull();
  });

  it('counts today among the last 7 days', () => {
    expect(periodRange('7d', {}, now).since).toEqual(new Date(2026, 9, 13));
  });

  it('covers the whole of last month, across a year change', () => {
    const january = new Date(2027, 0, 10);
    const { since, until } = periodRange('last_month', {}, january);
    expect(since).toEqual(new Date(2026, 11, 1));
    expect(until).toEqual(new Date(2026, 11, 31, 23, 59, 59, 999));
  });

  it('reads custom days as local days, both ends included', () => {
    const range = periodRange(
      'custom',
      { from: '2026-10-01', to: '2026-10-05' },
      now
    );
    expect(range.since).toEqual(new Date(2026, 9, 1));
    expect(range.until).toEqual(new Date(2026, 9, 5, 23, 59, 59, 999));
    expect(range.label).toBe('Del 01/10 al 05/10');
  });

  it('waits for a complete custom range', () => {
    expect(periodRange('custom', { from: '2026-10-01' }, now)).toBeNull();
    expect(
      periodRange('custom', { from: '2026-10-05', to: '2026-10-01' }, now)
    ).toBeNull();
  });
});
