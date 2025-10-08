const mongoose = require('mongoose');

const quickTransactionSchema = new mongoose.Schema({
  amount: {
    type: Number,
    required: true,
  },
  currency: {
    type: String,
    required: true,
  },
  date: {
    type: Date,
    required: true,
  },
  time: {
    type: String,
    required: true,
  },
  users: [{
    type: String,
    required: true,
  }],
  role: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    required: true,
  },
  cleared: {
    type: Boolean,
    default: false,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
});

quickTransactionSchema.pre('save', function (next) {
  this.updatedAt = Date.now();
  next();
});

const QuickTransaction = mongoose.model('QuickTransaction', quickTransactionSchema);

module.exports = QuickTransaction;
