// Date ranges for the Operación tab. Days are the viewer's local days (the shop is in
// Caracas): the page sends their start and end as instants, so the server needs no time zone.

export const PERIOD_OPTIONS = [
  { value: 'today', label: 'Hoy' },
  { value: '7d', label: 'Últimos 7 días' },
  { value: '30d', label: 'Últimos 30 días' },
  { value: 'month', label: 'Este mes' },
  { value: 'last_month', label: 'Mes pasado' },
  { value: 'custom', label: 'Personalizado' },
];

const startOfDay = date =>
  new Date(date.getFullYear(), date.getMonth(), date.getDate());
const endOfDay = date =>
  new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate(),
    23,
    59,
    59,
    999
  );
const daysBefore = (date, days) =>
  new Date(date.getFullYear(), date.getMonth(), date.getDate() - days);
// "2026-10-05" from <input type="date"> as a local day; `new Date(string)` would read it as UTC.
const fromInput = value => {
  const [year, month, day] = String(value).split('-').map(Number);
  return year && month && day ? new Date(year, month - 1, day) : null;
};
const pad = number => String(number).padStart(2, '0');
const short = date => `${pad(date.getDate())}/${pad(date.getMonth() + 1)}`;

// { since, until, label } for a preset, or null for an incomplete custom range. `until` is
// null for ranges that run to now: the server takes its own clock, so the auto refresh keeps
// counting new chats instead of stopping where the range was picked.
export function periodRange(preset, { from, to } = {}, now = new Date()) {
  const label = PERIOD_OPTIONS.find(option => option.value === preset)?.label;
  switch (preset) {
    case 'today':
      return { since: startOfDay(now), until: null, label };
    case '7d':
      return { since: daysBefore(now, 6), until: null, label };
    case 'month':
      return {
        since: new Date(now.getFullYear(), now.getMonth(), 1),
        until: null,
        label,
      };
    case 'last_month':
      return {
        since: new Date(now.getFullYear(), now.getMonth() - 1, 1),
        until: endOfDay(new Date(now.getFullYear(), now.getMonth(), 0)),
        label,
      };
    case 'custom': {
      const start = fromInput(from);
      const end = fromInput(to);
      if (!start || !end || start > end) return null;
      return {
        since: start,
        until: endOfDay(end),
        label: `Del ${short(start)} al ${short(end)}`,
      };
    }
    default:
      // Nothing to send: the server's default is the last 30 days counted back from now.
      return { since: null, until: null, label: PERIOD_OPTIONS[2].label };
  }
}
