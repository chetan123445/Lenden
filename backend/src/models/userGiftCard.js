const mongoose = require('mongoose');

const userGiftCardSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  giftCard: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'GiftCard',
    required: true,
  },
  coins: {
    type: Number,
    required: true,
  },
  scratched: {
    type: Boolean,
    default: false,
  },
  scratchedAt: {
    type: Date,
    default: null,
  },
  awardedFrom: {
    type: String,
    enum: ['quickTransaction', 'userTransaction', 'group'],
    required: true,
  },
}, { timestamps: true });

userGiftCardSchema.index({ user: 1, scratched: 1 });
userGiftCardSchema.index({ user: 1 });

module.exports = mongoose.model('UserGiftCard', userGiftCardSchema);
