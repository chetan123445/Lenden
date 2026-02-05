const Transaction = require('../models/transaction');
const QuickTransaction = require('../models/quickTransaction');
const GroupTransaction = require('../models/groupTransaction');
const User = require('../models/user');

exports.getUserCounterparties = async (req, res) => {
  try {
    const { email } = req.query;
    if (!email) return res.status(400).json({ error: 'Email is required' });

    // Only allow requesting own counterparties
    if (req.user?.email?.toLowerCase() !== email.toLowerCase()) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const user = await User.findOne({ email }).select('_id');
    if (!user) return res.status(404).json({ error: 'User not found' });

    const transactions = await Transaction.find({
      $or: [{ userEmail: email }, { counterpartyEmail: email }],
    }).lean();

    const quickTransactions = await QuickTransaction.find({
      users: email,
    }).lean();

    const groups = await GroupTransaction.find({
      'members.user': user._id,
    })
      .populate('members.user', 'email')
      .lean();

    let counterparties = {};

    transactions.forEach((t) => {
      const cp = t.counterpartyEmail;
      if (cp) counterparties[cp] = (counterparties[cp] || 0) + 1;
    });

    quickTransactions.forEach((t) => {
      const others = (t.users || []).filter((u) => u && u !== email);
      others.forEach((cp) => {
        counterparties[cp] = (counterparties[cp] || 0) + 1;
      });
    });

    groups.forEach((g) => {
      const members = (g.members || [])
        .map((m) => m.user?.email)
        .filter((e) => e && e !== email);
      members.forEach((cp) => {
        counterparties[cp] = (counterparties[cp] || 0) + 1;
      });
    });

    const counterpartiesList = Object.entries(counterparties)
      .map(([k, v]) => ({ email: k, count: v }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5);

    res.json({ counterparties: counterpartiesList });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
