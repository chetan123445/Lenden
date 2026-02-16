const mongoose = require('mongoose');

const offerClaimSchema = new mongoose.Schema(
  {
    offer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Offer',
      required: true,
      index: true,
    },
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    coinsAwarded: {
      type: Number,
      required: true,
      min: 1,
    },
    claimedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

offerClaimSchema.index({ offer: 1, user: 1 }, { unique: true });

module.exports = mongoose.model('OfferClaim', offerClaimSchema);
