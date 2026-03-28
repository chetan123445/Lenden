const mongoose = require('mongoose');

const appUpdateReadSchema = new mongoose.Schema(
  {
    update: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'AppUpdate',
      required: true,
      index: true,
    },
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    readAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

appUpdateReadSchema.index({ update: 1, user: 1 }, { unique: true });

module.exports = mongoose.model('AppUpdateRead', appUpdateReadSchema);
