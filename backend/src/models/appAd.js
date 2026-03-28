const mongoose = require('mongoose');

const appAdSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
    },
    body: {
      type: String,
      default: '',
      trim: true,
    },
    callToActionText: {
      type: String,
      default: '',
      trim: true,
    },
    callToActionUrl: {
      type: String,
      default: '',
      trim: true,
    },
    mediaFileId: {
      type: mongoose.Schema.Types.ObjectId,
      default: null,
    },
    mediaFilename: {
      type: String,
      default: '',
      trim: true,
    },
    mediaMimeType: {
      type: String,
      default: '',
      trim: true,
    },
    mediaKind: {
      type: String,
      enum: ['none', 'image', 'video'],
      default: 'none',
    },
    audience: {
      type: String,
      enum: ['all', 'subscribed', 'nonsubscribed'],
      default: 'nonsubscribed',
      index: true,
    },
    placements: {
      type: [String],
      default: ['dashboard'],
    },
    tags: {
      type: [String],
      default: [],
    },
    priorityWeight: {
      type: Number,
      default: 1,
      min: 1,
      max: 100,
    },
    dailyCapPerUser: {
      type: Number,
      default: 3,
      min: 1,
      max: 50,
    },
    videoCloseAtPercent: {
      type: Number,
      enum: [25, 50, 75, 100],
      default: 100,
    },
    active: {
      type: Boolean,
      default: true,
      index: true,
    },
    startsAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
    endsAt: {
      type: Date,
      default: null,
      index: true,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Admin',
      required: true,
    },
  },
  { timestamps: true }
);

appAdSchema.index({ active: 1, startsAt: 1, endsAt: 1 });
appAdSchema.index({ audience: 1, active: 1, startsAt: 1, endsAt: 1 });

module.exports = mongoose.model('AppAd', appAdSchema);
