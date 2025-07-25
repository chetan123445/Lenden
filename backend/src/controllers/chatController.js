const ChatThread = require('../models/chatThread');
const User = require('../models/user');
const leoProfanity = require('leo-profanity');

exports.getChat = async (req, res) => {
  try {
    const { transactionId } = req.params;
    let thread = await ChatThread.findOne({ transactionId }).populate('messages.sender', 'name email');
    if (!thread) return res.json({ messages: [] });
    // Sort messages by timestamp ascending
    const sortedMessages = [...thread.messages].sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
    res.json({ messages: sortedMessages });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch chat', details: err.message });
  }
};

exports.postMessage = async (req, res) => {
  try {
    const { transactionId } = req.params;
    const { senderId, content, parentId } = req.body;
    if ((!content || leoProfanity.check(content))) return res.status(400).json({ error: 'Message contains inappropriate language or is empty.' });
    let thread = await ChatThread.findOne({ transactionId });
    if (!thread) {
      thread = await ChatThread.create({ transactionId, messages: [] });
    }
    const message = {
      sender: senderId,
      content: content || '',
      parentId: parentId || null,
    };
    thread.messages.push(message);
    await thread.save();
    res.status(201).json({ message: thread.messages[thread.messages.length - 1] });
  } catch (err) {
    res.status(500).json({ error: 'Failed to post message', details: err.message });
  }
};

exports.reactMessage = async (req, res) => {
  try {
    const { transactionId, messageId } = req.params;
    const { userId, emoji } = req.body;
    let thread = await ChatThread.findOne({ transactionId });
    if (!thread) return res.status(404).json({ error: 'Chat not found' });
    const msg = thread.messages.id(messageId);
    if (!msg) return res.status(404).json({ error: 'Message not found' });
    // Remove existing reaction by this user (if any)
    msg.reactions = msg.reactions.filter(r => r.userId.toString() !== userId);
    if (emoji) {
      msg.reactions.push({ userId, emoji });
    }
    await thread.save();
    res.json({ message: msg });
  } catch (err) {
    res.status(500).json({ error: 'Failed to react to message', details: err.message });
  }
};

exports.readMessage = async (req, res) => {
  try {
    const { transactionId, messageId } = req.params;
    const { userId } = req.body;
    let thread = await ChatThread.findOne({ transactionId });
    if (!thread) return res.status(404).json({ error: 'Chat not found' });
    const msg = thread.messages.id(messageId);
    if (!msg) return res.status(404).json({ error: 'Message not found' });
    if (!msg.readBy.includes(userId)) {
      msg.readBy.push(userId);
      await thread.save();
    }
    res.json({ message: msg });
  } catch (err) {
    res.status(500).json({ error: 'Failed to mark message as read', details: err.message });
  }
};

exports.flagMessage = async (req, res) => {
  try {
    const { transactionId, messageId } = req.params;
    const { reason } = req.body;
    let thread = await ChatThread.findOne({ transactionId });
    if (!thread) return res.status(404).json({ error: 'Chat not found' });
    const msg = thread.messages.id(messageId);
    if (!msg) return res.status(404).json({ error: 'Message not found' });
    msg.isFlagged = true;
    msg.flaggedReason = reason || 'Flagged by user';
    await thread.save();
    res.json({ message: msg });
  } catch (err) {
    res.status(500).json({ error: 'Failed to flag message', details: err.message });
  }
};

exports.unflagMessage = async (req, res) => {
  try {
    const { transactionId, messageId } = req.params;
    let thread = await ChatThread.findOne({ transactionId });
    if (!thread) return res.status(404).json({ error: 'Chat not found' });
    const msg = thread.messages.id(messageId);
    if (!msg) return res.status(404).json({ error: 'Message not found' });
    msg.isFlagged = false;
    msg.flaggedReason = '';
    await thread.save();
    res.json({ message: msg });
  } catch (err) {
    res.status(500).json({ error: 'Failed to unflag message', details: err.message });
  }
};

exports.deleteMessage = async (req, res) => {
  try {
    const { transactionId, messageId } = req.params;
    const { userId } = req.body;
    let thread = await ChatThread.findOne({ transactionId });
    if (!thread) return res.status(404).json({ error: 'Chat not found' });
    const msg = thread.messages.id(messageId);
    if (!msg) return res.status(404).json({ error: 'Message not found' });
    if (msg.sender.toString() !== userId) return res.status(403).json({ error: 'Not allowed to delete this message' });
    msg.deleted = true;
    msg.content = 'This message was deleted';
    msg.image = undefined;
    await thread.save();
    res.json({ message: msg });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete message', details: err.message });
  }
}; 