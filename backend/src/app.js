require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const cron = require('node-cron');
const { sendReminderEmail } = require('./utils/lendingborrowingotp');
const Transaction = require('./models/transaction');
const User = require('./models/user');

const apiRoutes = require('./routes/api');
const Admin = require('./models/admin');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api', apiRoutes);

// MongoDB Connection
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(async () => {
  console.log('Database Established');
  await Admin.createDefaultAdmin();
  console.log('Default admin ensured');
})
.catch((err) => console.error('Batabase connection error:', err));

cron.schedule('0 8 * * *', async () => {
  try {
    const today = new Date();
    today.setHours(0,0,0,0);
    const tomorrow = new Date(today);
    tomorrow.setDate(today.getDate() + 1);
    // Find transactions due today or overdue and not cleared
    const dueTxns = await Transaction.find({
      expectedReturnDate: { $lte: tomorrow },
      cleared: false
    }).lean();
    for (const txn of dueTxns) {
      // Send to both lender and borrower
      const lender = await User.findById(txn.lender).lean();
      const borrower = await User.findById(txn.borrower).lean();
      const daysLeft = Math.ceil((new Date(txn.expectedReturnDate) - today) / (1000*60*60*24));
      if (lender && lender.email) {
        await sendReminderEmail(lender.email, {
          ...txn,
          counterpartyName: borrower?.name || borrower?.username || borrower?.email,
          counterpartyEmail: borrower?.email
        }, daysLeft);
      }
      if (borrower && borrower.email) {
        await sendReminderEmail(borrower.email, {
          ...txn,
          counterpartyName: lender?.name || lender?.username || lender?.email,
          counterpartyEmail: lender?.email
        }, daysLeft);
      }
    }
    console.log(`[CRON] Reminder emails sent for ${dueTxns.length} transactions.`);
  } catch (err) {
    console.error('[CRON] Error sending reminder emails:', err);
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
