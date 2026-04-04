const CurrencyDefinition = require('../models/currencyDefinition');

const DEFAULT_CURRENCIES = [
  { code: 'INR', symbol: '₹', label: 'Indian Rupee' },
  { code: 'USD', symbol: '\$', label: 'US Dollar' },
  { code: 'EUR', symbol: '€', label: 'Euro' },
  { code: 'GBP', symbol: '£', label: 'British Pound' },
  { code: 'JPY', symbol: '¥', label: 'Japanese Yen' },
  { code: 'CNY', symbol: '¥', label: 'Chinese Yuan' },
  { code: 'CAD', symbol: '\$', label: 'Canadian Dollar' },
  { code: 'AUD', symbol: '\$', label: 'Australian Dollar' },
  { code: 'CHF', symbol: 'Fr', label: 'Swiss Franc' },
  { code: 'RUB', symbol: '₽', label: 'Russian Ruble' },
];

function normalizeCurrencyCode(code) {
  return (code || '').toString().trim().toUpperCase();
}

async function getSupportedCurrencyDefinitions() {
  const rows = await CurrencyDefinition.find({ active: true }).lean();
  const merged = new Map();

  for (const currency of DEFAULT_CURRENCIES) {
    merged.set(currency.code, { ...currency });
  }

  for (const row of rows) {
    const code = normalizeCurrencyCode(row.code);
    if (!code) continue;
    merged.set(code, {
      code,
      symbol: row.symbol || code,
      label: row.label || code,
    });
  }

  return Array.from(merged.values()).sort((a, b) => a.code.localeCompare(b.code));
}

async function getSupportedCurrencyCodes() {
  const defs = await getSupportedCurrencyDefinitions();
  return defs.map((item) => item.code);
}

module.exports = {
  DEFAULT_CURRENCIES,
  normalizeCurrencyCode,
  getSupportedCurrencyDefinitions,
  getSupportedCurrencyCodes,
};
