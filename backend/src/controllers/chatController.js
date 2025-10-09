const ChatThread = require('../models/chatThread');
const User = require('../models/user');
const leoProfanity = require('leo-profanity');

module.exports = (io) => {
  const getChat = async (req, res) => {
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

  const postMessage = async (req, res) => {
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
      const populatedMsg = await ChatThread.populate(thread.messages[thread.messages.length - 1], { path: 'sender', select: 'name email' });
      io.to(transactionId).emit('chatMessage', populatedMsg);
      res.status(201).json({ message: populatedMsg });
    } catch (err) {
      res.status(500).json({ error: 'Failed to post message', details: err.message });
    }
  };

  const reactMessage = async (req, res) => {
    try {
      const { transactionId, messageId } = req.params;
      const { userId, emoji } = req.body;
      let thread = await ChatThread.findOne({ transactionId });
      if (!thread) return res.status(404).json({ error: 'Chat not found' });
      const msg = thread.messages.id(messageId);
      if (!msg) return res.status(404).json({ error: 'Message not found' });
      
      let reactions = msg.reactions.toObject();
      reactions = reactions.filter(r => r.userId.toString() !== userId);
      if (emoji) {
        reactions.push({ userId, emoji });
      }
      msg.reactions = reactions;

      await thread.save();

      await thread.populate('messages.sender', 'name email');
      const updatedMsg = thread.messages.id(messageId);

      io.to(transactionId).emit('messageUpdated', updatedMsg.toObject());
      res.json({ message: updatedMsg.toObject() });
    } catch (err) {
      res.status(500).json({ error: 'Failed to react to message', details: err.message });
    }
  };

  const readMessage = async (req, res) => {
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

  const deleteMessage = async (req, res) => {
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

      io.to(transactionId).emit('messageDeleted', { messageId });
      res.json({ message: msg });
    } catch (err) {
      res.status(500).json({ error: 'Failed to delete message', details: err.message });
    }
  };

  return {
    getChat,
    postMessage,
    reactMessage,
    readMessage,
    deleteMessage,
  };
};