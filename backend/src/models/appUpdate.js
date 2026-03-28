const mongoose = require('mongoose');

const appUpdateSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
    },
    body: {
      type: String,
      required: true,
      trim: true,
    },
    versionTag: {
      type: String,
      default: '',
      trim: true,
    },
    pinned: {
      type: Boolean,
      default: false,
    },
    publishedAt: {
      type: Date,
      default: Date.now,
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

appUpdateSchema.index({ pinned: -1, publishedAt: -1 });

module.exports = mongoose.model('AppUpdate', appUpdateSchema);
