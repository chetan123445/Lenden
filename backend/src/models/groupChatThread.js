const mongoose = require('mongoose');

const groupMessageSchema = new mongoose.Schema({
  sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  content: { type: String, default: '' },
  timestamp: { type: Date, default: Date.now },
  parentId: { type: mongoose.Schema.Types.ObjectId, default: null }, // for replies
  reactions: [{ userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, emoji: String }],
  readBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  deleted: { type: Boolean, default: false }
});

const groupChatThreadSchema = new mongoose.Schema({
  groupTransactionId: { type: mongoose.Schema.Types.ObjectId, ref: 'GroupTransaction', required: true, unique: true },
  messages: [groupMessageSchema]
});

groupChatThreadSchema.index({ groupTransactionId: 1 });

module.exports = mongoose.model('GroupChatThread', groupChatThreadSchema); 