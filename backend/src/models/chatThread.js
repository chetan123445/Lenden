const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  content: { type: String, default: '' },
  timestamp: { type: Date, default: Date.now },
  parentId: { type: mongoose.Schema.Types.ObjectId, default: null }, // for replies
  reactions: [{ userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, emoji: String }],
  readBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  deleted: { type: Boolean, default: false }
});

const chatThreadSchema = new mongoose.Schema({
  transactionId: { type: mongoose.Schema.Types.ObjectId, ref: 'Transaction', required: true, unique: true },
  messages: [messageSchema]
});

module.exports = mongoose.model('ChatThread', chatThreadSchema); 