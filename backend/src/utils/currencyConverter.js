const INR = 'INR';
const FRANKFURTER_URL = 'https://api.frankfurter.dev/v2/rates';
const CurrencyConversionRate = require('../models/currencyConversionRate');
const { getSupportedCurrencyCodes } = require('./supportedCurrencies');

let rateCache = {
  expiresAt: 0,
  ratesToInr: { INR: 1 },
};
let manualRateCache = {
  expiresAt: 0,
  graph: new Map(),
};

const normalizeCurrency = (currency) =>
  (currency || INR).toString().trim().toUpperCase();

async function fetchRatesToInr() {
  const now = Date.now();
  if (rateCache.expiresAt > now) {
    return rateCache.ratesToInr;
  }

  const supportedCurrencies = await getSupportedCurrencyCodes();
  const quotes = supportedCurrencies.filter((code) => code !== INR);
  if (quotes.length === 0) {
    return { INR: 1 };
  }

  const response = await fetch(
    `${FRANKFURTER_URL}?base=${INR}&symbols=${quotes.join(',')}`
  );
  if (!response.ok) {
    throw new Error(`Exchange rate lookup failed (${response.status})`);
  }

  const payload = await response.json();
  const rates = payload?.rates || {};
  const nextRates = { INR: 1 };
  for (const code of quotes) {
    const perInr = Number(rates[code] || 0);
    nextRates[code] = perInr > 0 ? Number((1 / perInr).toFixed(8)) : null;
  }

  rateCache = {
    expiresAt: now + 15 * 60 * 1000,
    ratesToInr: nextRates,
  };

  return nextRates;
}

function buildGraph(rows) {
  const graph = new Map();
  for (const row of rows) {
    const from = normalizeCurrency(row.baseCurrency);
    const to = normalizeCurrency(row.quoteCurrency);
    if (!graph.has(from)) graph.set(from, []);
    graph.get(from).push({
      to,
      rate: Number(row.rate || 0),
    });
  }
  return graph;
}

function resolveGraphRate(graph, from, to, visited = new Set()) {
  if (from === to) return 1;
  if (visited.has(from)) return null;
  visited.add(from);

  const neighbors = graph.get(from) || [];
  for (const edge of neighbors) {
    if (!edge.rate) continue;
    if (edge.to === to) return edge.rate;
    const nextRate = resolveGraphRate(graph, edge.to, to, new Set(visited));
    if (nextRate) return edge.rate * nextRate;
  }

  return null;
}

async function fetchManualRatesToInr() {
  const now = Date.now();
  if (manualRateCache.expiresAt > now) {
    return manualRateCache.graph;
  }

  const rows = await CurrencyConversionRate.find({})
    .sort({ updatedAt: -1 })
    .lean();

  const seenPairs = new Set();
  const latestRows = [];
  for (const row of rows) {
    const pairKey = `${normalizeCurrency(row.baseCurrency)}->${normalizeCurrency(
      row.quoteCurrency
    )}`;
    if (seenPairs.has(pairKey)) continue;
    seenPairs.add(pairKey);
    latestRows.push(row);
  }

  manualRateCache = {
    expiresAt: now + 5 * 60 * 1000,
    graph: buildGraph(latestRows),
  };

  return manualRateCache.graph;
}

async function convertAmountToInr(amount, currency) {
  const normalizedCurrency = normalizeCurrency(currency);
  const numericAmount = Number(amount || 0);
  if (!Number.isFinite(numericAmount)) return 0;
  if (normalizedCurrency === INR) return numericAmount;

  const rate = await getConversionRate(normalizedCurrency, INR);
  if (!rate) {
    throw new Error(`Unsupported currency for INR conversion: ${normalizedCurrency}`);
  }

  return Number((numericAmount * rate).toFixed(2));
}

async function getConversionRate(fromCurrency, toCurrency) {
  const from = normalizeCurrency(fromCurrency);
  const to = normalizeCurrency(toCurrency);
  if (from === to) return 1;

  const manualGraph = await fetchManualRatesToInr();
  let rate = Number(resolveGraphRate(manualGraph, from, to) || 0);
  if (!rate) {
    const ratesToInr = await fetchRatesToInr();
    const fromToInr = Number(ratesToInr[from] || 0);
    const toToInr = Number(ratesToInr[to] || 0);
    if (from === INR && toToInr) {
      rate = Number((1 / toToInr).toFixed(8));
    } else if (to === INR && fromToInr) {
      rate = fromToInr;
    } else if (fromToInr && toToInr) {
      rate = Number((fromToInr / toToInr).toFixed(8));
    }
  }

  return rate || null;
}

async function convertAmount(amount, fromCurrency, toCurrency) {
  const numericAmount = Number(amount || 0);
  if (!Number.isFinite(numericAmount)) return 0;
  const rate = await getConversionRate(fromCurrency, toCurrency);
  if (!rate) {
    throw new Error(
      `Unsupported currency conversion: ${normalizeCurrency(fromCurrency)} to ${normalizeCurrency(toCurrency)}`
    );
  }

  return Number((numericAmount * rate).toFixed(2));
}

async function enrichExpenseWithInr(expense) {
  const amountInr = await convertAmountToInr(expense.amount, expense.currency);
  const split = await Promise.all(
    (expense.split || []).map(async (item) => ({
      ...item,
      amountInr: await convertAmountToInr(item.amount, expense.currency),
    }))
  );

  return {
    ...expense,
    currency: normalizeCurrency(expense.currency),
    amountInr,
    split,
  };
}

module.exports = {
  INR,
  normalizeCurrency,
  getConversionRate,
  convertAmount,
  convertAmountToInr,
  enrichExpenseWithInr,
};
