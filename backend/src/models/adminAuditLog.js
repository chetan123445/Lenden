const mongoose = require('mongoose');

const adminAuditLogSchema = new mongoose.Schema(
  {
    admin: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Admin',
      required: true,
      index: true,
    },
    adminEmail: {
      type: String,
      required: true,
      trim: true,
    },
    action: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    targetType: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    targetId: {
      type: String,
      default: '',
      trim: true,
      index: true,
    },
    summary: {
      type: String,
      required: true,
      trim: true,
    },
    details: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    severity: {
      type: String,
      enum: ['info', 'warning', 'critical'],
      default: 'info',
      index: true,
    },
    ipAddress: {
      type: String,
      default: '',
      trim: true,
    },
  },
  { timestamps: true }
);

adminAuditLogSchema.index({ createdAt: -1, severity: 1 });

module.exports = mongoose.model('AdminAuditLog', adminAuditLogSchema);
