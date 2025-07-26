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
    addedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    date: { type: Date, default: Date.now },
    split: [{
      user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
      amount: { type: Number, required: true },
    }],
  }],
  balances: [{
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    balance: { type: Number, default: 0 },
  }],
  pendingLeaves: [{
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    requestedAt: { type: Date, default: Date.now },
  }],
  isActive: { type: Boolean, default: true },
}, { timestamps: true });

groupTransactionSchema.index({ title: 1 });
groupTransactionSchema.index({ creator: 1 });
groupTransactionSchema.index({ 'members.user': 1 });

groupTransactionSchema.methods.canRemoveMember = function(userId) {
  const bal = this.balances.find(b => b.user.toString() === userId.toString());
  return !bal || bal.balance === 0;
};

module.exports = mongoose.model('GroupTransaction', groupTransactionSchema); 