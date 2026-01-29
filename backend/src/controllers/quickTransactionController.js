const QuickTransaction = require('../models/quickTransaction');
const User = require('../models/user');
const Subscription = require('../models/subscription');
const { logQuickTransactionActivity } = require('./activityController');

exports.createQuickTransaction = async (req, res) => {
  try {
    const { amount, currency, date, time, description, counterpartyEmail, role } = req.body;
    const user = req.user;
    const userEmail = user.email;

    if (userEmail === counterpartyEmail) {
      return res.status(400).json({ error: 'User and counterparty email cannot be the same.' });
    }

    const counterparty = await User.findOne({ email: counterpartyEmail });
    if (!counterparty) {
      return res.status(404).json({ error: 'Counterparty email not found.' });
    }

    const quickTransaction = new QuickTransaction({
      amount,
      currency,
      date,
      time,
      description,
      users: [userEmail, counterpartyEmail],
      role,
    });

    await quickTransaction.save();
    await logQuickTransactionActivity(req.user._id, 'quick_transaction_created', quickTransaction, { counterpartyEmail });
    res.status(201).json({ 
        message: 'Quick transaction created successfully', 
        quickTransaction, 
        freeQuickTransactionsRemaining: user.freeQuickTransactionsRemaining 
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.getQuickTransactions = async (req, res) => {
  try {
    const userEmail = req.user.email;
    const quickTransactions = await QuickTransaction.find({ users: userEmail }).sort({ createdAt: -1 }).lean();

    const populatedTransactions = await Promise.all(quickTransactions.map(async (t) => {
      const users = await User.find({ email: { $in: t.users } }).select('name email');
      t.users = users.map(u => ({ name: u.name, email: u.email }));
      return t;
    }));

    res.status(200).json({ quickTransactions: populatedTransactions });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.updateQuickTransaction = async (req, res) => {
  try {
    const { id } = req.params;
    const { amount, currency, date, time, description, role } = req.body;
    const userEmail = req.user.email;

    const quickTransaction = await QuickTransaction.findById(id);

    if (!quickTransaction) {
      return res.status(404).json({ error: 'Quick transaction not found' });
    }

    if (quickTransaction.cleared) {
      return res.status(403).json({ error: 'Cannot edit a cleared transaction' });
    }

    if (!quickTransaction.users.includes(userEmail)) {
      return res.status(403).json({ error: 'User not authorized to update this transaction' });
    }

    quickTransaction.amount = amount;
    quickTransaction.currency = currency;
    quickTransaction.date = date;
    quickTransaction.time = time;
    quickTransaction.description = description;
    quickTransaction.role = role;

    await quickTransaction.save();
    await logQuickTransactionActivity(req.user._id, 'quick_transaction_updated', quickTransaction);

    res.status(200).json({ quickTransaction });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.deleteQuickTransaction = async (req, res) => {
  try {
    const { id } = req.params;
    const quickTransaction = await QuickTransaction.findById(id);

    if (!quickTransaction) {
      return res.status(404).json({ error: 'Quick transaction not found' });
    }

    if (!quickTransaction.users.includes(req.user.email)) {
      return res.status(403).json({ error: 'User not authorized to delete this transaction' });
    }

    await QuickTransaction.findByIdAndDelete(id);
    await logQuickTransactionActivity(req.user._id, 'quick_transaction_deleted', quickTransaction);

    res.status(200).json({ message: 'Quick transaction deleted successfully' });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.clearQuickTransaction = async (req, res) => {
  try {
    const { id } = req.params;

    const quickTransaction = await QuickTransaction.findById(id);

    if (!quickTransaction) {
      return res.status(404).json({ error: 'Quick transaction not found' });
    }

    if (!quickTransaction.users.includes(req.user.email)) {
      return res.status(403).json({ error: 'User not authorized to clear this transaction' });
    }

    quickTransaction.cleared = true;
    await quickTransaction.save();
    await logQuickTransactionActivity(req.user._id, 'quick_transaction_cleared', quickTransaction);

    res.status(200).json({ quickTransaction });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.clearAllQuickTransactions = async (req, res) => {
  try {
    const userEmail = req.user.email;
    await QuickTransaction.deleteMany({ users: userEmail });
    await logQuickTransactionActivity(req.user._id, 'quick_transaction_cleared_all', {});
    res.status(200).json({ message: 'All quick transactions cleared successfully' });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};