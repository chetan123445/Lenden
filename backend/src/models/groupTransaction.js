const mongoose = require('mongoose');

const groupTransactionSchema = new mongoose.Schema({
  title: { type: String, required: true },
  creator: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  color: { type: String, default: '#2196F3' }, // New: group color hex code
  members: [{
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    joinedAt: { type: Date, default: Date.now },
    leftAt: { type: Date, default: null },
  }],
  expenses: [{
    description: { type: String, required: true },
    amount: { type: Number, required: true },
    addedBy: { type: String, required: true }, // Changed from ObjectId to String to store email
    date: { type: Date, default: Date.now },
    selectedMembers: [{ type: String }], // New: emails of members included in this expense
    split: [{
      user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
      amount: { type: Number, required: true },
      settled: { type: Boolean, default: false }, // New: track if this split is settled
      settledAt: { type: Date, default: null }, // New: when it was settled
      settledBy: { type: String, default: null }, // New: who settled it (email)
    }],
  }],
  balances: [{
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    balance: { type: Number, default: 0 },
  }],
  isActive: { type: Boolean, default: true },
  favourite: [{ type: String }], // Array of user emails
  messageCounts: [{
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    count: { type: Number, default: 0 },
  }],
}, { timestamps: true });

groupTransactionSchema.index({ title: 1 });
groupTransactionSchema.index({ creator: 1 });
groupTransactionSchema.index({ 'members.user': 1 });

groupTransactionSchema.methods.canRemoveMember = function(userId) {
  const bal = this.balances.find(b => b.user.toString() === userId.toString());
  return !bal || bal.balance === 0;
};

module.exports = mongoose.model('GroupTransaction', groupTransactionSchema);