const Transaction = require('../models/transaction');
const GroupTransaction = require('../models/groupTransaction');
const User = require('../models/user');

function buildRecentMonths() {
  const now = new Date();
  return Array.from({ length: 12 }, (_, i) => {
    return new Date(now.getFullYear(), now.getMonth() - 11 + i, 1);
  });
}

function applyMonthCount(months, monthlyCounts, dateValue) {
  const date = new Date(dateValue);
  months.forEach((month, index) => {
    if (
      date.getFullYear() === month.getFullYear() &&
      date.getMonth() === month.getMonth()
    ) {
      monthlyCounts[index] += 1;
    }
  });
}

function buildMetricCatalog(type) {
  if (type === 'group') {
    return [
      { id: 'totalLent', title: 'Contributed' },
      { id: 'totalBorrowed', title: 'Your Share' },
      { id: 'totalInterest', title: 'Outstanding' },
      { id: 'cleared', title: 'Settled' },
      { id: 'uncleared', title: 'Unsettled' },
      { id: 'total', title: 'Expenses' },
      { id: 'totalGroups', title: 'Groups' },
      { id: 'monthly', title: 'Monthly Activity' },
    ];
  }

  return [
    { id: 'totalLent', title: 'Total Lent' },
    { id: 'totalBorrowed', title: 'Total Borrowed' },
    { id: 'totalInterest', title: 'Interest' },
    { id: 'cleared', title: 'Cleared' },
    { id: 'uncleared', title: 'Uncleared' },
    { id: 'total', title: 'Total Transactions' },
    { id: 'monthly', title: 'Monthly Activity' },
  ];
}

async function getAnalyticsUser(email) {
  if (!email) {
    return { error: 'Email is required', status: 400 };
  }

  const user = await User.findOne({ email }).select('_id privacySettings email');
  if (!user) {
    return { error: 'User not found', status: 404 };
  }

  if (user.privacySettings && user.privacySettings.analyticsSharing === false) {
    return { analyticsSharing: false, user };
  }

  return { analyticsSharing: true, user };
}

exports.getUserAnalytics = async (req, res) => {
  try {
    const { email } = req.query;
    const analyticsUser = await getAnalyticsUser(email);

    if (analyticsUser.error) {
      return res.status(analyticsUser.status).json({ error: analyticsUser.error });
    }

    if (analyticsUser.analyticsSharing === false) {
      return res.json({ analyticsSharing: false });
    }

    const months = buildRecentMonths();
    const monthlyCounts = Array(12).fill(0);

    const transactions = await Transaction.find({
      $or: [{ userEmail: email }, { counterpartyEmail: email }],
    });

    let totalLent = 0;
    let totalBorrowed = 0;
    let totalInterest = 0;
    let cleared = 0;
    let uncleared = 0;

    transactions.forEach((transaction) => {
      let isLender = false;
      let isBorrower = false;

      if (transaction.userEmail === email) {
        isLender = transaction.role === 'lender';
        isBorrower = transaction.role === 'borrower';
      } else {
        isLender = transaction.role === 'borrower';
        isBorrower = transaction.role === 'lender';
      }

      if (isLender) totalLent += transaction.amount;
      if (isBorrower) totalBorrowed += transaction.amount;

      if (transaction.userCleared && transaction.counterpartyCleared) {
        cleared += 1;
      } else {
        uncleared += 1;
      }

      if (
        transaction.interestType &&
        transaction.interestRate &&
        transaction.expectedReturnDate
      ) {
        const principal = transaction.amount;
        const rate = transaction.interestRate;
        const start = new Date(transaction.date);
        const expectedEnd = new Date(transaction.expectedReturnDate);
        const currentDate = new Date();
        const effectiveEnd = expectedEnd > currentDate ? currentDate : expectedEnd;
        const years = (effectiveEnd - start) / (365 * 24 * 60 * 60 * 1000);

        if (years > 0) {
          if (transaction.interestType === 'simple') {
            totalInterest += (principal * rate * years) / 100;
          } else if (transaction.interestType === 'compound') {
            const frequency = transaction.compoundingFrequency || 1;
            totalInterest +=
              principal * Math.pow(1 + rate / 100 / frequency, frequency * years) -
              principal;
          }
        }
      }

      applyMonthCount(months, monthlyCounts, transaction.date);
    });

    return res.json({
      analyticsSharing: true,
      category: 'secure',
      totalLent,
      totalBorrowed,
      totalInterest,
      cleared,
      uncleared,
      total: transactions.length,
      monthlyCounts,
      months: months.map((month) => month.toISOString().slice(0, 7)),
      highlightedMetrics: ['totalLent', 'totalBorrowed'],
      availableInsights: buildMetricCatalog('secure'),
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.getGroupAnalytics = async (req, res) => {
  try {
    const { email } = req.query;
    const analyticsUser = await getAnalyticsUser(email);

    if (analyticsUser.error) {
      return res.status(analyticsUser.status).json({ error: analyticsUser.error });
    }

    if (analyticsUser.analyticsSharing === false) {
      return res.json({ analyticsSharing: false });
    }

    const user = analyticsUser.user;
    const userId = user._id.toString();
    const months = buildRecentMonths();
    const monthlyCounts = Array(12).fill(0);

    const groups = await GroupTransaction.find({
      'members.user': user._id,
    });

    let totalContributed = 0;
    let totalShare = 0;
    let outstanding = 0;
    let settled = 0;
    let uncleared = 0;
    let totalExpenses = 0;

    groups.forEach((group) => {
      (group.expenses || []).forEach((expense) => {
        const userSplit = (expense.split || []).find(
          (split) => split.user?.toString() === userId
        );
        const userIsInExpense =
          expense.addedBy === email || Boolean(userSplit);

        if (!userIsInExpense) {
          return;
        }

        totalExpenses += 1;
        applyMonthCount(months, monthlyCounts, expense.date || group.createdAt);

        if (expense.addedBy === email) {
          totalContributed += expense.amount || 0;
        }

        if (userSplit) {
          totalShare += userSplit.amount || 0;
          if (userSplit.settled) {
            settled += 1;
          } else {
            uncleared += 1;
            outstanding += userSplit.amount || 0;
          }
        }
      });
    });

    return res.json({
      analyticsSharing: true,
      category: 'group',
      totalLent: totalContributed,
      totalBorrowed: totalShare,
      totalInterest: outstanding,
      cleared: settled,
      uncleared,
      total: totalExpenses,
      totalGroups: groups.length,
      monthlyCounts,
      months: months.map((month) => month.toISOString().slice(0, 7)),
      highlightedMetrics: ['totalLent', 'totalBorrowed'],
      availableInsights: buildMetricCatalog('group'),
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
