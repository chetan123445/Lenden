const mongoose = require('mongoose');

const offerSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120,
    },
    description: {
      type: String,
      trim: true,
      maxlength: 500,
      default: '',
    },
    coins: {
      type: Number,
      required: true,
      min: 1,
    },
    startsAt: {
      type: Date,
      required: true,
    },
    endsAt: {
      type: Date,
      required: true,
      index: true,
    },
    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['draft', 'scheduled', 'active', 'ended'],
      default: 'draft',
      index: true,
    },
    version: {
      type: Number,
      default: 1,
      min: 1,
    },
    lastNotifiedVersion: {
      type: Number,
      default: 0,
      min: 0,
    },
    recipientType: {
      type: String,
      enum: ['all-users', 'specific-users'],
      default: 'all-users',
      index: true,
    },
    recipients: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
      },
    ],
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Admin',
      required: true,
    },
    updatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Admin',
      default: null,
    },
    changeLog: [
      {
        version: { type: Number, required: true },
        changedAt: { type: Date, default: Date.now },
        changedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'Admin' },
        reason: { type: String, default: 'Offer updated' },
        snapshot: {
          name: String,
          description: String,
          coins: Number,
          startsAt: Date,
          endsAt: Date,
          isActive: Boolean,
          status: String,
          recipientType: String,
          recipients: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
        },
      },
    ],
  },
  { timestamps: true }
);

offerSchema.index({ isActive: 1, startsAt: 1, endsAt: 1 });
offerSchema.index({ recipientType: 1, recipients: 1 });
offerSchema.index({ status: 1, endsAt: 1 });

module.exports = mongoose.model('Offer', offerSchema);
