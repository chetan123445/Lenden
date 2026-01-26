const mongoose = require('mongoose');

const giftCardSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
  },
  value: {
    type: Number,
    required: true,
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Admin',
    required: true,
  },
}, { timestamps: true });

giftCardSchema.index({ name: 1 });

module.exports = mongoose.model('GiftCard', giftCardSchema);
