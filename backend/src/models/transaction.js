const mongoose = require('mongoose');
delete mongoose.connection.models['Transaction'];
const { v4: uuidv4 } = require('uuid');

const transactionSchema = new mongoose.Schema({
  transactionId: {
    type: String,
    default: uuidv4,
    unique: true
  },
  amount: {
    type: Number,
    required: true
  },
  currency: {
    type: String,
    required: true
  },
  date: {
    type: Date,
    required: true
  },
  time: {
    type: String,
    required: true
  },
  place: {
    type: String,
    required: true
  },
  photos: [{
    type: String // base64 encoded images
  }],
  interestType: {
    type: String,
    enum: ['simple', 'compound'],
    default: null
  },
  interestRate: {
    type: Number,
    default: null
  },
  expectedReturnDate: {
    type: Date,
    default: null
  },
  compoundingFrequency: {
    type: Number,
    default: null
  },
  userCleared: {
    type: Boolean,
    default: false
  },
  counterpartyCleared: {
    type: Boolean,
    default: false
  },
  counterpartyEmail: {
    type: String,
    required: true
  },
  userEmail: {
    type: String,
    required: true
  },
  role: {
    type: String,
    enum: ['lender', 'borrower'],
    required: true
  },
  description: {
    type: String,
    default: ''
  }
}, { timestamps: true });

transactionSchema.index({ transactionId: 1 });
transactionSchema.index({ userEmail: 1 });
transactionSchema.index({ counterpartyEmail: 1 });
transactionSchema.index({ date: -1 });
transactionSchema.index({ role: 1 });

module.exports = mongoose.model('Transaction', transactionSchema); 