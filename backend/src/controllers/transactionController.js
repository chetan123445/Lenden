const Transaction = require('../models/transaction');
const User = require('../models/user');
const lendingborrowingotp = require('../utils/lendingborrowingotp');
const { sendTransactionReceipt, sendTransactionClearedNotification } = require('../utils/lendingborrowingotp');
const multer = require('multer');
const allowedMimeTypes = ['image/png', 'image/jpeg', 'image/jpg', 'application/pdf'];

// Create a new transaction
exports.createTransaction = async (req, res) => {
  try {
    const {
      amount,
      currency,
      date,
      time,
      place,
      counterpartyEmail,
      userEmail,
      role, // 'lender' or 'borrower'
      interestType,
      interestRate,
      expectedReturnDate,
      compoundingFrequency,
      description
    } = req.body;

    // Validate required fields
    if (!amount || !currency || !date || !time || !place || !counterpartyEmail || !userEmail || !role) {
      return res.status(400).json({ error: 'All fields are required' });
    }
    if (!['lender', 'borrower'].includes(role)) {
      return res.status(400).json({ error: 'Role must be lender or borrower' });
    }
    if (interestType && !['simple', 'compound'].includes(interestType)) {
      return res.status(400).json({ error: 'Interest type must be simple or compound' });
    }
    if (interestType === 'compound' && (!compoundingFrequency || isNaN(compoundingFrequency))) {
      return res.status(400).json({ error: 'Compounding frequency required for compound interest' });
    }

    // Check if both emails exist
    const counterparty = await User.findOne({ email: counterpartyEmail });
    const user = await User.findOne({ email: userEmail });
    if (!counterparty) return res.status(400).json({ error: 'Counterparty email not registered' });
    if (!user) return res.status(400).json({ error: 'User email not registered' });

    // Handle files
    let files = [];
    if (req.files && req.files.length > 0) {
      for (const file of req.files) {
        if (!allowedMimeTypes.includes(file.mimetype)) {
          return res.status(400).json({ error: 'Invalid file type. Only PNG, JPG, JPEG, and PDF allowed.' });
        }
        files.push({
          data: file.buffer,
          type: file.mimetype,
          name: file.originalname
        });
      }
    }

    // Save transaction
    const transaction = await Transaction.create({
      amount,
      currency,
      date,
      time,
      place,
      files,
      counterpartyEmail,
      userEmail,
      role,
      interestType: interestType || null,
      interestRate: interestRate || null,
      expectedReturnDate: expectedReturnDate || null,
      compoundingFrequency: compoundingFrequency || null,
      description: description || ''
    });
    res.json({ success: true, transactionId: transaction.transactionId, transaction });

    // Send receipt emails to both parties (fire and forget)
    try {
      sendTransactionReceipt(userEmail, transaction, counterpartyEmail);
      sendTransactionReceipt(counterpartyEmail, transaction, userEmail);
    } catch (e) {
      console.error('Failed to send transaction receipt:', e);
    }
  } catch (err) {
    res.status(500).json({ error: 'Failed to create transaction', details: err.message });
  }
};

// Check if email exists in user schema
exports.checkEmailExists = async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email is required' });
  const user = await User.findOne({ email });
  if (user) return res.json({ exists: true });
  return res.json({ exists: false });
};

// Send OTP to counterparty email
exports.sendCounterpartyOTP = async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email is required' });
  try {
    await lendingborrowingotp.resendOtp(email);
    res.json({ message: 'OTP sent to counterparty email' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to send OTP' });
  }
};

// Verify counterparty OTP
exports.verifyCounterpartyOTP = async (req, res) => {
  const { email, otp } = req.body;
  if (!email || !otp) return res.status(400).json({ error: 'Email and OTP are required' });
  const valid = lendingborrowingotp.verifyLendingBorrowingOtp(email, otp);
  if (valid) return res.json({ verified: true });
  return res.status(400).json({ verified: false, error: 'Invalid or expired OTP' });
};

// Send OTP to logged-in user email
exports.sendUserOTP = async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email is required' });
  try {
    await lendingborrowingotp.resendOtp(email);
    res.json({ message: 'OTP sent to user email' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to send OTP' });
  }
};

// Verify logged-in user OTP
exports.verifyUserOTP = async (req, res) => {
  const { email, otp } = req.body;
  if (!email || !otp) return res.status(400).json({ error: 'Email and OTP are required' });
  const valid = lendingborrowingotp.verifyLendingBorrowingOtp(email, otp);
  if (valid) return res.json({ verified: true });
  return res.status(400).json({ verified: false, error: 'Invalid or expired OTP' });
};

// Get all transactions for a user, grouped by role
exports.getUserTransactions = async (req, res) => {
  try {
    const { email } = req.query;
    if (!email) return res.status(400).json({ error: 'Email is required' });
    const transactions = await Transaction.find({
      $or: [
        { userEmail: email },
        { counterpartyEmail: email }
      ]
    }).sort({ createdAt: -1 });
    // Group into lending and borrowing for both userEmail and counterpartyEmail
    const lending = transactions.filter(t => (t.role === 'lender' && t.userEmail === email) || (t.role === 'borrower' && t.counterpartyEmail === email));
    const borrowing = transactions.filter(t => (t.role === 'borrower' && t.userEmail === email) || (t.role === 'lender' && t.counterpartyEmail === email));
    res.json({ lending, borrowing });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch transactions', details: err.message });
  }
};

// Clear transaction endpoint
exports.clearTransaction = async (req, res) => {
  try {
    const { transactionId, email } = req.body;
    if (!transactionId || !email) return res.status(400).json({ error: 'transactionId and email required' });
    const transaction = await Transaction.findOne({ transactionId });
    if (!transaction) return res.status(404).json({ error: 'Transaction not found' });
    let updated = false;
    let otherPartyEmail = null;
    if (transaction.userEmail === email) {
      if (!transaction.userCleared) {
        transaction.userCleared = true;
        updated = true;
        otherPartyEmail = transaction.counterpartyEmail;
      }
    } else if (transaction.counterpartyEmail === email) {
      if (!transaction.counterpartyCleared) {
        transaction.counterpartyCleared = true;
        updated = true;
        otherPartyEmail = transaction.userEmail;
      }
    } else {
      return res.status(403).json({ error: 'You are not a party to this transaction' });
    }
    if (updated) {
      await transaction.save();
      // Notify the other party
      try {
        sendTransactionClearedNotification(otherPartyEmail, transaction, email);
      } catch (e) {
        console.error('Failed to send cleared notification:', e);
      }
    }
    res.json({ success: true, userCleared: transaction.userCleared, counterpartyCleared: transaction.counterpartyCleared, fullyCleared: transaction.userCleared && transaction.counterpartyCleared });
  } catch (err) {
    res.status(500).json({ error: 'Failed to clear transaction', details: err.message });
  }
}; 