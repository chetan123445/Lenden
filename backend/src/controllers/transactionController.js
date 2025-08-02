const Transaction = require('../models/transaction');
const User = require('../models/user');
const lendingborrowingotp = require('../utils/lendingborrowingotp');
const { sendTransactionReceipt, sendTransactionClearedNotification } = require('../utils/lendingborrowingotp');
const multer = require('multer');
const allowedMimeTypes = ['image/png', 'image/jpeg', 'image/jpg'];
const PDFDocument = require('pdfkit');

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
    
    // Handle interest validation - make it optional
    if (interestType && !['simple', 'compound', 'none'].includes(interestType)) {
      return res.status(400).json({ error: 'Interest type must be simple, compound, or none' });
    }
    if (interestType === 'compound' && (!compoundingFrequency || isNaN(compoundingFrequency))) {
      return res.status(400).json({ error: 'Compounding frequency required for compound interest' });
    }
    
    // Set default interest type if not provided
    const finalInterestType = interestType || 'none';
    const finalInterestRate = (finalInterestType === 'none') ? null : interestRate;
    const finalExpectedReturnDate = (finalInterestType === 'none') ? null : expectedReturnDate;
    const finalCompoundingFrequency = (finalInterestType === 'none') ? null : compoundingFrequency;

    // Check if both emails exist
    const counterparty = await User.findOne({ email: counterpartyEmail });
    const user = await User.findOne({ email: userEmail });
    if (!counterparty) return res.status(400).json({ error: 'Counterparty email not registered' });
    if (!user) return res.status(400).json({ error: 'User email not registered' });

    // Handle photos (images only)
    let photos = [];
    if (req.files && req.files.length > 0) {
      for (const file of req.files) {
        if (!allowedMimeTypes.includes(file.mimetype)) {
          return res.status(400).json({ error: 'Invalid file type. Only PNG, JPG, JPEG allowed.' });
        }
        photos.push(file.buffer.toString('base64'));
      }
    }

    // Calculate total amount with interest if applicable
    let totalAmountWithInterest = amount;
    if (finalInterestType && finalInterestRate) {
      if (finalInterestType === 'simple') {
        // For new transactions, no interest has accumulated yet
        totalAmountWithInterest = amount;
      } else if (finalInterestType === 'compound') {
        // For new transactions, no interest has accumulated yet
        totalAmountWithInterest = amount;
      }
    }

    // Save transaction
    const transaction = await Transaction.create({
      amount,
      currency,
      date,
      time,
      place,
      photos,
      counterpartyEmail,
      userEmail,
      role,
      interestType: finalInterestType,
      interestRate: finalInterestRate,
      expectedReturnDate: finalExpectedReturnDate,
      compoundingFrequency: finalCompoundingFrequency,
      description: description || '',
      remainingAmount: totalAmountWithInterest,
      totalAmountWithInterest: totalAmountWithInterest
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

// Delete transaction endpoint
exports.deleteTransaction = async (req, res) => {
  try {
    const { transactionId, email } = req.body;
    if (!transactionId || !email) {
      return res.status(400).json({ error: 'transactionId and email required' });
    }

    const transaction = await Transaction.findOne({ transactionId });
    if (!transaction) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    // Check if the user is a party to this transaction
    if (transaction.userEmail !== email && transaction.counterpartyEmail !== email) {
      return res.status(403).json({ error: 'You are not a party to this transaction' });
    }

    // Check if both parties have cleared the transaction
    if (!transaction.userCleared || !transaction.counterpartyCleared) {
      return res.status(400).json({
        error: 'Cannot delete transaction. Both parties must clear the transaction first.',
        userCleared: transaction.userCleared,
        counterpartyCleared: transaction.counterpartyCleared
      });
    }

    // Delete the transaction
    await Transaction.deleteOne({ transactionId });

    res.json({
      success: true,
      message: 'Transaction deleted successfully'
    });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete transaction', details: err.message });
  }
};

// Send OTP for partial payment verification
exports.sendPartialPaymentOTP = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }

    // Check if email exists in user schema
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ error: 'Email not registered' });
    }

    // Send OTP
    await lendingborrowingotp.resendOtp(email);
    res.json({ message: 'OTP sent successfully' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to send OTP', details: err.message });
  }
};

// Verify OTP for partial payment
exports.verifyPartialPaymentOTP = async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!email || !otp) {
      return res.status(400).json({ error: 'Email and OTP are required' });
    }

    const valid = lendingborrowingotp.verifyLendingBorrowingOtp(email, otp);
    if (valid) {
      res.json({ verified: true });
    } else {
      res.status(400).json({ verified: false, error: 'Invalid or expired OTP' });
    }
  } catch (err) {
    res.status(500).json({ error: 'Failed to verify OTP', details: err.message });
  }
};

// Process partial payment
exports.processPartialPayment = async (req, res) => {
  try {
    const { 
      transactionId, 
      amount, 
      description, 
      paidBy, 
      lenderEmail, 
      borrowerEmail,
      lenderOtpVerified,
      borrowerOtpVerified 
    } = req.body;

    if (!transactionId || !amount || !paidBy || !lenderEmail || !borrowerEmail) {
      return res.status(400).json({ error: 'All required fields are missing' });
    }

    if (!lenderOtpVerified || !borrowerOtpVerified) {
      return res.status(400).json({ error: 'Both parties must verify their OTP' });
    }

    if (!['lender', 'borrower'].includes(paidBy)) {
      return res.status(400).json({ error: 'paidBy must be lender or borrower' });
    }

    const transaction = await Transaction.findOne({ transactionId });
    if (!transaction) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    // Verify that the emails match the transaction parties
    if (transaction.userEmail !== lenderEmail && transaction.counterpartyEmail !== lenderEmail) {
      return res.status(400).json({ error: 'Lender email does not match transaction parties' });
    }
    if (transaction.userEmail !== borrowerEmail && transaction.counterpartyEmail !== borrowerEmail) {
      return res.status(400).json({ error: 'Borrower email does not match transaction parties' });
    }

    // Calculate interest on the current remaining amount (not the original amount)
    let currentRemainingAmount = transaction.remainingAmount || transaction.amount;
    let totalAmountWithInterest = currentRemainingAmount;
    
    if (transaction.interestType && transaction.interestRate) {
      // Get the last partial payment date or transaction date
      let lastPaymentDate = new Date(transaction.date);
      if (transaction.partialPayments && transaction.partialPayments.length > 0) {
        // Get the date of the last partial payment
        const lastPayment = transaction.partialPayments[transaction.partialPayments.length - 1];
        lastPaymentDate = new Date(lastPayment.paidAt);
      }
      
      const now = new Date();
      const daysDiff = Math.ceil((now - lastPaymentDate) / (1000 * 60 * 60 * 24));
      
      if (daysDiff > 0) { // Only calculate interest if time has passed
        if (transaction.interestType === 'simple') {
          totalAmountWithInterest = currentRemainingAmount + (currentRemainingAmount * transaction.interestRate * daysDiff / 365);
        } else if (transaction.interestType === 'compound') {
          const periods = daysDiff / transaction.compoundingFrequency;
          totalAmountWithInterest = currentRemainingAmount * Math.pow(1 + transaction.interestRate / 100, periods);
        }
      }
    }
    
    // For display purposes, also calculate the total amount with interest from transaction date
    let displayTotalAmountWithInterest = transaction.amount;
    if (transaction.interestType && transaction.interestRate) {
      const transactionDate = new Date(transaction.date);
      const now = new Date();
      const daysDiff = Math.ceil((now - transactionDate) / (1000 * 60 * 60 * 24));
      
      if (daysDiff > 0) {
        if (transaction.interestType === 'simple') {
          displayTotalAmountWithInterest = transaction.amount + (transaction.amount * transaction.interestRate * daysDiff / 365);
        } else if (transaction.interestType === 'compound') {
          const periods = daysDiff / transaction.compoundingFrequency;
          displayTotalAmountWithInterest = transaction.amount * Math.pow(1 + transaction.interestRate / 100, periods);
        }
      }
    }

    // Initialize remaining amount if not set
    if (!transaction.remainingAmount) {
      transaction.remainingAmount = totalAmountWithInterest;
      transaction.totalAmountWithInterest = totalAmountWithInterest;
    } else {
      // Update the total amount with interest for the current remaining amount
      transaction.totalAmountWithInterest = totalAmountWithInterest;
    }

    // Validate payment amount
    if (amount <= 0) {
      return res.status(400).json({ error: 'Payment amount must be greater than 0' });
    }

    if (amount > totalAmountWithInterest) {
      return res.status(400).json({ 
        error: 'Payment amount cannot exceed total amount with interest',
        totalAmountWithInterest: totalAmountWithInterest,
        remainingAmount: transaction.remainingAmount,
        currentAmountWithInterest: totalAmountWithInterest
      });
    }

    // Process the partial payment
    transaction.remainingAmount = totalAmountWithInterest - amount;
    transaction.isPartiallyPaid = true;

    // Add to partial payments history
    transaction.partialPayments.push({
      amount: amount,
      paidBy: paidBy,
      paidAt: new Date(),
      description: description || ''
    });

    // If remaining amount is 0 or less, mark transaction as cleared
    if (transaction.remainingAmount <= 0) {
      transaction.userCleared = true;
      transaction.counterpartyCleared = true;
      transaction.remainingAmount = 0;
    }

    await transaction.save();

    res.json({
      success: true,
      message: 'Partial payment processed successfully',
      remainingAmount: transaction.remainingAmount,
      isFullyPaid: transaction.remainingAmount <= 0,
      displayTotalAmountWithInterest: displayTotalAmountWithInterest
    });

  } catch (err) {
    res.status(500).json({ error: 'Failed to process partial payment', details: err.message });
  }
};

// Get transaction details with partial payment history
exports.getTransactionDetails = async (req, res) => {
  try {
    const { transactionId } = req.params;
    if (!transactionId) {
      return res.status(400).json({ error: 'Transaction ID is required' });
    }

    const transaction = await Transaction.findOne({ transactionId });
    if (!transaction) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    res.json({ transaction });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch transaction details', details: err.message });
  }
}; 