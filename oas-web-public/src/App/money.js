// Formats an amount in the society's configured currency (public_config_config.currency).
// Falls back to GBP while the config is loading, which matches the database default.
export const DEFAULT_CURRENCY = 'GBP';

export const formatMoney = (amount, currency) => {
  const value = Number(amount);
  if (amount === null || amount === undefined || amount === '' || isNaN(value)) {
    return '';
  }
  const code = currency || DEFAULT_CURRENCY;
  try {
    return new Intl.NumberFormat(undefined, { style: 'currency', currency: code }).format(value);
  } catch (e) {
    // Unknown currency code: show the number with the code rather than crash.
    return `${value.toFixed(2)} ${code}`;
  }
};
