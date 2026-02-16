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
    offerVersion: {
      type: Number,
      default: 1,
      min: 1,
    },
    idempotencyKey: {
      type: String,
      default: null,
      trim: true,
    },
    revoked: {
      type: Boolean,
      default: false,
      index: true,
    },
    revokedAt: {
      type: Date,
      default: null,
    },
    revokedReason: {
      type: String,
      default: null,
      trim: true,
    },
  },
  { timestamps: true }
);

offerClaimSchema.index(
  { offer: 1, user: 1, revoked: 1 },
  { unique: true, partialFilterExpression: { revoked: false } }
);
offerClaimSchema.index({ user: 1, claimedAt: -1 });
offerClaimSchema.index({ idempotencyKey: 1 }, { sparse: true });

module.exports = mongoose.model('OfferClaim', offerClaimSchema);
