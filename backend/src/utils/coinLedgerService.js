const CoinLedger = require('../models/coinLedger');

const recordCoinLedgerEntry = async ({
  userId,
  direction,
  coins,
  source,
  title,
  description,
  metadata = {},
  occurredAt = new Date(),
}) => {
  try {
    if (!userId || !direction || !coins || !source || !title || !description) {
      return null;
    }

    return await CoinLedger.create({
      user: userId,
      direction,
      coins: Math.abs(Number(coins) || 0),
      source,
      title,
      description,
      metadata,
      occurredAt,
    });
  } catch (error) {
    console.error('Failed to record coin ledger entry:', error);
    return null;
  }
};

module.exports = {
  recordCoinLedgerEntry,
};
