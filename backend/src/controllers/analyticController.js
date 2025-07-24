const Transaction = require('../models/transaction');

exports.getUserAnalytics = async (req, res) => {
  try {
    const { email } = req.query;
    if (!email) return res.status(400).json({ error: 'Email is required' });
    const transactions = await Transaction.find({
      $or: [
        { userEmail: email },
        { counterpartyEmail: email }
      ]
    });
    const now = new Date();
    const months = Array.from({ length: 12 }, (_, i) => {
      const d = new Date(now.getFullYear(), now.getMonth() - 11 + i, 1);
      return d;
    });
    // Analytics calculations
    let totalLent = 0, totalBorrowed = 0, totalInterest = 0;
    let cleared = 0, uncleared = 0;
    let monthlyCounts = Array(12).fill(0);
    let counterparties = {};
    transactions.forEach(t => {
      const isLender = t.userEmail === email && t.role === 'lender';
      const isBorrower = t.userEmail === email && t.role === 'borrower';
      if (isLender) totalLent += t.amount;
      if (isBorrower) totalBorrowed += t.amount;
      if (t.userCleared && t.counterpartyCleared) cleared++;
      else uncleared++;
      // Interest (accrued up to now or expectedReturnDate, whichever is earlier)
      if (t.interestType && t.interestRate && t.expectedReturnDate) {
        const principal = t.amount;
        const rate = t.interestRate;
        const start = new Date(t.date);
        const end = new Date(t.expectedReturnDate);
        const now = new Date();
        const effectiveEnd = end > now ? now : end;
        const years = (effectiveEnd - start) / (365 * 24 * 60 * 60 * 1000);
        if (years > 0) {
          if (t.interestType === 'simple') {
            totalInterest += principal * rate * years / 100;
          } else if (t.interestType === 'compound') {
            const n = t.compoundingFrequency || 1;
            totalInterest += principal * Math.pow(1 + rate / 100 / n, n * years) - principal;
          }
        }
      }
      // Monthly volume
      const d = new Date(t.date);
      months.forEach((m, i) => {
        if (d.getFullYear() === m.getFullYear() && d.getMonth() === m.getMonth()) {
          monthlyCounts[i]++;
        }
      });
      // Counterparties
      const cp = t.counterpartyEmail;
      if (cp) counterparties[cp] = (counterparties[cp] || 0) + 1;
    });
    const topCounterparties = Object.entries(counterparties)
      .map(([k, v]) => ({ email: k, count: v }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5);
    res.json({
      totalLent,
      totalBorrowed,
      totalInterest,
      cleared,
      uncleared,
      total: transactions.length,
      monthlyCounts,
      months: months.map(m => m.toISOString().slice(0, 7)),
      topCounterparties
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}; 