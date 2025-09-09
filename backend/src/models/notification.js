const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  sender: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Admin',
    required: true,
  },
  recipientType: {
    type: String,
    enum: ['all-users', 'all-admins', 'specific-users', 'specific-admins'],
    required: true,
  },
  recipients: [
    {
      type: mongoose.Schema.Types.ObjectId,
      refPath: 'recipientModel',
    },
  ],
  recipientModel: {
    type: String,
    required: true,
    enum: ['User', 'Admin'],
  },
  message: {
    type: String,
    required: true,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model('Notification', notificationSchema);
