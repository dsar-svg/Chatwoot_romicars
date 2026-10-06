// Price math shared by the settings price list and the mobile app. `rate` is the
// latest exchange rate record: equiv_13 is the BCV rate plus the shop's markup (the name
// dates from when that was a fixed 13%).

export const calcCostBs = (divisa, rate) => {
  if (!divisa || !rate) return null;
  return Number((divisa * rate.equiv_13).toFixed(2));
};

export const calcBolivares = (divisa, rate) => {
  const montoBs = calcCostBs(divisa, rate);
  if (montoBs === null) return null;
  return Math.round(montoBs / rate.rate);
};

export const toVE = (value, decimals) =>
  Number(value).toLocaleString('es-VE', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  });
