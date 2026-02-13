const QuickTransaction = require('../models/quickTransaction');
const User = require('../models/user');
const Subscription = require('../models/subscription');
const { logQuickTransactionActivity } = require('./activityController');
const { awardGiftCard, shouldAwardGiftCard } = require('./userGiftCardController');
const { processReferralRewardOnFirstCreation } = require('../utils/referralService');

const isBlockedBy = (user, other) =>
  (user.blockedUsers || []).some(
    (id) => id.toString() === other._id.toString()
  );

const isSubscribed = async (userId) => {
  const subscription = await Subscription.findOne({
    user: userId,
    status: 'active',
  });
  return (
    subscription &&
    subscription.subscribed &&
    subscription.endDate >= new Date()
  );
};

const getTodayRange = () => {
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  const end = new Date();
  end.setHours(23, 59, 59, 999);
  return { start, end };
};

exports.createQuickTransaction = async (req, res) => {
  try {
    const { amount, currency, date, time, description, counterpartyEmail, role } = req.body;
    const user = await User.findById(req.user._id).select('email blockedUsers');
    const userEmail = user.email;

    if (userEmail === counterpartyEmail) {
      return res.status(400).json({ error: 'User and counterparty email cannot be the same.' });
    }

    const counterparty = await User.findOne({ email: counterpartyEmail }).select(
      'email blockedUsers'
    );
    if (!counterparty) {
      return res.status(404).json({ error: 'Counterparty email not found.' });
    }
    if (isBlockedBy(user, counterparty)) {
      return res.status(403).json({
        error: 'You have blocked this user. Unblock to proceed.',
      });
    }
    if (isBlockedBy(counterparty, user)) {
      return res.status(403).json({
        error: 'You cannot add this user because they have blocked you.',
      });
    }

    if (!(await isSubscribed(user._id))) {
      const { start, end } = getTodayRange();
      const todayCount = await QuickTransaction.countDocuments({
        creatorEmail: userEmail,
        createdAt: { $gte: start, $lte: end },
      });
      if (todayCount >= 3) {
        return res.status(429).json({
          error: 'Daily limit reached: You can create 3 quick transactions per day.',
        });
      }
    }

    const quickTransaction = new QuickTransaction({
      amount,
      currency,
      date,
      time,
      description,
      users: [userEmail, counterpartyEmail],
      creatorEmail: userEmail,
      role,
    });

    await quickTransaction.save();
    const referralReward = await processReferralRewardOnFirstCreation(req.user._id);
    await logQuickTransactionActivity(req.user._id, 'quick_transaction_created', quickTransaction, { counterpartyEmail });

    // Award gift card every 10 quick transactions (guaranteed, randomized within window)
    const quickTxnCount = await QuickTransaction.countDocuments({ creatorEmail: userEmail });
    console.log(`[Quick Transaction] User ${userEmail} has created ${quickTxnCount} quick transactions`);
    let awardedCard = null;
    if (shouldAwardGiftCard(req.user._id, quickTxnCount, 10)) {
      console.log(`[Quick Transaction] Awarding gift card at count ${quickTxnCount}!`);
      awardedCard = await awardGiftCard(req.user._id, 'quickTransaction');
    } else {
      console.log(`[Quick Transaction] No card award yet. Progress: ${quickTxnCount} within window`);
    }

    res.status(201).json({ 
        message: 'Quick transaction created successfully', 
        quickTransaction, 
        freeQuickTransactionsRemaining: user.freeQuickTransactionsRemaining,
        referralReward,
        giftCardAwarded: awardedCard ? true : false,
        awardedCard: awardedCard
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.createQuickTransactionWithCoins = async (req, res) => {
  const QUICK_TRANSACTION_COST = 5;
  try {
    const { amount, currency, date, time, description, counterpartyEmail, role } = req.body;
    const user = await User.findById(req.user._id);
    const userEmail = user.email;

    if (user.lenDenCoins < QUICK_TRANSACTION_COST) {
      return res.status(403).json({ error: 'Insufficient LenDen coins.' });
    }

    if (userEmail === counterpartyEmail) {
      return res.status(400).json({ error: 'User and counterparty email cannot be the same.' });
    }

    const counterparty = await User.findOne({ email: counterpartyEmail }).select(
      'email blockedUsers'
    );
    if (!counterparty) {
      return res.status(404).json({ error: 'Counterparty email not found.' });
    }
    if (isBlockedBy(user, counterparty)) {
      return res.status(403).json({
        error: 'You have blocked this user. Unblock to proceed.',
      });
    }
    if (isBlockedBy(counterparty, user)) {
      return res.status(403).json({
        error: 'You cannot add this user because they have blocked you.',
      });
    }

    if (!(await isSubscribed(user._id))) {
      const { start, end } = getTodayRange();
      const todayCount = await QuickTransaction.countDocuments({
        creatorEmail: userEmail,
        createdAt: { $gte: start, $lte: end },
      });
      if (todayCount >= 3) {
        return res.status(429).json({
          error: 'Daily limit reached: You can create 3 quick transactions per day.',
        });
      }
    }

    user.lenDenCoins -= QUICK_TRANSACTION_COST;
    await user.save();

    const quickTransaction = new QuickTransaction({
      amount,
      currency,
      date,
      time,
      description,
      users: [userEmail, counterpartyEmail],
      creatorEmail: userEmail,
      role,
    });

    await quickTransaction.save();
    const referralReward = await processReferralRewardOnFirstCreation(req.user._id);
    await logQuickTransactionActivity(req.user._id, 'quick_transaction_created_with_coins', quickTransaction, { counterpartyEmail });

    // Award gift card every 10 quick transactions (guaranteed, randomized within window)
    const quickTxnCount = await QuickTransaction.countDocuments({ creatorEmail: userEmail });
    console.log(`[Quick Transaction with Coins] User ${userEmail} has created ${quickTxnCount} quick transactions`);
    let awardedCard = null;
    if (shouldAwardGiftCard(user._id, quickTxnCount, 10)) {
      console.log(`[Quick Transaction with Coins] Awarding gift card at count ${quickTxnCount}!`);
      awardedCard = await awardGiftCard(user._id, 'quickTransaction');
    } else {
      console.log(`[Quick Transaction with Coins] No card award yet. Progress: ${quickTxnCount} within window`);
    }

    res.status(201).json({ 
        message: 'Quick transaction created successfully with LenDen coins', 
        quickTransaction, 
        lenDenCoins: user.lenDenCoins,
        referralReward,
        giftCardAwarded: awardedCard ? true : false,
        awardedCard: awardedCard
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
