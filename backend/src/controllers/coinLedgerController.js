const CoinLedger = require('../models/coinLedger');
const User = require('../models/user');

const formatSourceLabel = (source) =>
  source
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');

exports.getMyCoinHistory = async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select('lenDenCoins');
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const limit = Math.min(Math.max(Number(req.query.limit) || 60, 1), 200);
    const entries = await CoinLedger.find({ user: req.user._id })
      .sort({ occurredAt: -1, createdAt: -1 })
      .limit(limit)
      .lean();

    const summary = entries.reduce(
      (acc, entry) => {
        const amount = Number(entry.coins || 0);
        if (entry.direction === 'earned') {
          acc.totalEarned += amount;
        } else {
          acc.totalSpent += amount;
        }

        const key = entry.source || 'other';
        if (!acc.bySource[key]) {
          acc.bySource[key] = {
            label: formatSourceLabel(key),
            earned: 0,
            spent: 0,
            count: 0,
          };
        }
        acc.bySource[key].count += 1;
        if (entry.direction === 'earned') {
          acc.bySource[key].earned += amount;
        } else {
          acc.bySource[key].spent += amount;
        }

        return acc;
      },
      { totalEarned: 0, totalSpent: 0, bySource: {} }
    );

    res.json({
      balance: Number(user.lenDenCoins || 0),
      summary: {
        totalEarned: summary.totalEarned,
        totalSpent: summary.totalSpent,
        net: summary.totalEarned - summary.totalSpent,
        sources: Object.values(summary.bySource).sort(
          (a, b) => b.count - a.count || b.earned + b.spent - (a.earned + a.spent)
        ),
      },
      entries: entries.map((entry) => ({
        id: entry._id,
        direction: entry.direction,
        coins: entry.coins,
        source: entry.source,
        title: entry.title,
        description: entry.description,
        occurredAt: entry.occurredAt,
        metadata: entry.metadata || {},
      })),
    });
  } catch (error) {
    console.error('Error fetching coin history:', error);
    res.status(500).json({ error: 'Failed to fetch coin history' });
  }
};
