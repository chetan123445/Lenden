const mongoose = require('mongoose');
const Transaction = require('../models/transaction');

// MongoDB connection string - update this with your actual connection string
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/lenden';

async function migratePartialPaymentFields() {
  try {
    // Connect to MongoDB
    await mongoose.connect(MONGODB_URI);
    console.log('Connected to MongoDB');

    // Find all transactions that don't have the new fields
    const transactions = await Transaction.find({
      $or: [
        { remainingAmount: { $exists: false } },
        { totalAmountWithInterest: { $exists: false } },
        { partialPayments: { $exists: false } },
        { isPartiallyPaid: { $exists: false } }
      ]
    });

    console.log(`Found ${transactions.length} transactions to migrate`);

    let updatedCount = 0;
    for (const transaction of transactions) {
      // Calculate total amount with interest if applicable
                     let totalAmountWithInterest = transaction.amount;
               if (transaction.interestType && transaction.interestRate) {
                 const now = new Date();
                 const transactionDate = new Date(transaction.date);
                 const daysDiff = Math.ceil((now - transactionDate) / (1000 * 60 * 60 * 24));
                 
                 if (daysDiff > 0) { // Only calculate interest if time has passed
                   if (transaction.interestType === 'simple') {
                     totalAmountWithInterest = transaction.amount + (transaction.amount * transaction.interestRate * daysDiff / 365);
                   } else if (transaction.interestType === 'compound') {
                     const periods = daysDiff / transaction.compoundingFrequency;
                     totalAmountWithInterest = transaction.amount * Math.pow(1 + transaction.interestRate / 100, periods);
                   }
                 }
               }

      // Update the transaction with new fields
      await Transaction.updateOne(
        { _id: transaction._id },
        {
          $set: {
            remainingAmount: totalAmountWithInterest,
            totalAmountWithInterest: totalAmountWithInterest,
            partialPayments: [],
            isPartiallyPaid: false
          }
        }
      );

      updatedCount++;
      if (updatedCount % 100 === 0) {
        console.log(`Updated ${updatedCount} transactions...`);
      }
    }

    console.log(`Migration completed! Updated ${updatedCount} transactions`);
  } catch (error) {
    console.error('Migration failed:', error);
  } finally {
    await mongoose.disconnect();
    console.log('Disconnected from MongoDB');
  }
}

// Run the migration if this file is executed directly
if (require.main === module) {
  migratePartialPaymentFields();
}

module.exports = migratePartialPaymentFields; 