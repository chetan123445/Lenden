const mongoose = require('mongoose');

const appAdEventSchema = new mongoose.Schema(
  {
    ad: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'AppAd',
      required: true,
      index: true,
    },
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    type: {
      type: String,
      enum: ['impression', 'click', 'close', 'hide', 'report'],
      required: true,
      index: true,
    },
    watchSeconds: {
      type: Number,
      default: 0,
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    occurredAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  { timestamps: true }
);

appAdEventSchema.index({ ad: 1, user: 1, type: 1, occurredAt: -1 });

module.exports = mongoose.model('AppAdEvent', appAdEventSchema);
