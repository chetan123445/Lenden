const GroupChatThread = require('../models/groupChatThread');
const GroupTransaction = require('../models/groupTransaction');
const User = require('../models/user');
const leoProfanity = require('leo-profanity');

exports.getGroupChat = async (req, res) => {
  try {
    const { groupTransactionId } = req.params;
    
    // Check if user is a member of the group
    const group = await GroupTransaction.findById(groupTransactionId);
    if (!group) {
      return res.status(404).json({ error: 'Group not found' });
    }
    
    const userId = req.user._id;
    const isMember = group.members.some(member => 
      member.user.toString() === userId?.toString() && !member.leftAt
    );
    
    if (!isMember) {
      return res.status(403).json({ error: 'You are not a member of this group' });
    }
    
    let thread = await GroupChatThread.findOne({ groupTransactionId })
      .populate('messages.sender', 'name email');
    
    if (!thread) return res.json({ messages: [] });
    
    // Sort messages by timestamp ascending
    const sortedMessages = [...thread.messages].sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
    res.json({ messages: sortedMessages });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch group chat', details: err.message });
  }
};

exports.postGroupMessage = async (req, res) => {
  try {
    const { groupTransactionId } = req.params;
    const { content, parentId } = req.body;
    const senderId = req.user._id;
    
    if (!content || leoProfanity.check(content)) {
      return res.status(400).json({ error: 'Message contains inappropriate language or is empty.' });
    }
    
    // Check if user is a member of the group
    const group = await GroupTransaction.findById(groupTransactionId);
    if (!group) {
      return res.status(404).json({ error: 'Group not found' });
    }
    
    const isMember = group.members.some(member => 
      member.user.toString() === senderId?.toString() && !member.leftAt
    );
    
    if (!isMember) {
      return res.status(403).json({ error: 'You are not a member of this group' });
    }
    
    let thread = await GroupChatThread.findOne({ groupTransactionId });
    if (!thread) {
      thread = await GroupChatThread.create({ groupTransactionId, messages: [] });
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
    res.status(500).json({ error: 'Failed to post group message', details: err.message });
  }
};

exports.reactGroupMessage = async (req, res) => {
  try {
    const { groupTransactionId, messageId } = req.params;
    const { emoji } = req.body;
    const userId = req.user._id;
    
    // Check if user is a member of the group
    const group = await GroupTransaction.findById(groupTransactionId);
    if (!group) {
      return res.status(404).json({ error: 'Group not found' });
    }
    
    const isMember = group.members.some(member => 
      member.user.toString() === userId?.toString() && !member.leftAt
    );
    
    if (!isMember) {
      return res.status(403).json({ error: 'You are not a member of this group' });
    }
    
    let thread = await GroupChatThread.findOne({ groupTransactionId });
    if (!thread) return res.status(404).json({ error: 'Group chat not found' });
    
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
    res.status(500).json({ error: 'Failed to react to group message', details: err.message });
  }
};

exports.readGroupMessage = async (req, res) => {
  try {
    const { groupTransactionId, messageId } = req.params;
    const userId = req.user._id;
    
    // Check if user is a member of the group
    const group = await GroupTransaction.findById(groupTransactionId);
    if (!group) {
      return res.status(404).json({ error: 'Group not found' });
    }
    
    const isMember = group.members.some(member => 
      member.user.toString() === userId?.toString() && !member.leftAt
    );
    
    if (!isMember) {
      return res.status(403).json({ error: 'You are not a member of this group' });
    }
    
    let thread = await GroupChatThread.findOne({ groupTransactionId });
    if (!thread) return res.status(404).json({ error: 'Group chat not found' });
    
    const msg = thread.messages.id(messageId);
    if (!msg) return res.status(404).json({ error: 'Message not found' });
    
    if (!msg.readBy.includes(userId)) {
      msg.readBy.push(userId);
      await thread.save();
    }
    
    res.json({ message: msg });
  } catch (err) {
    res.status(500).json({ error: 'Failed to mark group message as read', details: err.message });
  }
};

exports.deleteGroupMessage = async (req, res) => {
  try {
    const { groupTransactionId, messageId } = req.params;
    const userId = req.user._id;
    
    // Check if user is a member of the group
    const group = await GroupTransaction.findById(groupTransactionId);
    if (!group) {
      return res.status(404).json({ error: 'Group not found' });
    }
    
    const isMember = group.members.some(member => 
      member.user.toString() === userId?.toString() && !member.leftAt
    );
    
    if (!isMember) {
      return res.status(403).json({ error: 'You are not a member of this group' });
    }
    
    let thread = await GroupChatThread.findOne({ groupTransactionId });
    if (!thread) return res.status(404).json({ error: 'Group chat not found' });
    
    const msg = thread.messages.id(messageId);
    if (!msg) return res.status(404).json({ error: 'Message not found' });
    
    if (msg.sender.toString() !== userId) {
      return res.status(403).json({ error: 'Not allowed to delete this message' });
    }
    
    msg.deleted = true;
    msg.content = 'This message was deleted';
    await thread.save();
    
    res.json({ message: msg });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete group message', details: err.message });
  }
}; 