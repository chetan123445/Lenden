const GroupTransaction = require('../models/groupTransaction');
const User = require('../models/user');
const { sendGroupSettleOtp } = require('../utils/groupSettleOtp');
const mongoose = require('mongoose');

// Helper function to process expenses and convert Object IDs to emails in addedBy field
async function processExpenses(expenses) {
  return await Promise.all((expenses || []).map(async expense => {
    if (expense.addedBy && typeof expense.addedBy === 'string' && expense.addedBy.length === 24) {
      // This is likely an Object ID, try to find the user and get their email
      try {
        const User = require('../models/user');
        const user = await User.findById(expense.addedBy);
        if (user) {
          return { ...expense, addedBy: user.email };
        }
      } catch (err) {
        console.log('Error finding user for expense:', err.message);
      }
    }
    return expense;
  }));
}

// Helper: check if all userIds exist in User collection
async function validateUsers(userIds) {
  const count = await User.countDocuments({ _id: { $in: userIds } });
  return count === userIds.length;
}

exports.createGroup = async (req, res) => {
  try {
    if (!req.user || !req.user._id) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    const { title, memberEmails, color } = req.body;
    const creator = req.user._id;
    
    if (!title) {
      return res.status(400).json({ error: 'Title is required' });
    }
    
    // Get creator's email to filter out from memberEmails
    const creatorUser = await User.findById(creator);
    if (!creatorUser) {
      return res.status(400).json({ error: 'Creator not found' });
    }
    
    // Filter out creator's email from memberEmails (they're added automatically)
    const filteredMemberEmails = memberEmails.filter(email => email !== creatorUser.email);
    
    // Find users by email
    const users = await User.find({ email: { $in: filteredMemberEmails } });
    if (users.length !== filteredMemberEmails.length) {
      return res.status(400).json({ error: 'One or more members do not exist' });
    }
    
    const memberIds = users.map(u => u._id.toString());
    // Always add creator as the first member
    memberIds.unshift(creator.toString());
    
    const members = memberIds.map(id => ({ user: id }));
    const group = await GroupTransaction.create({ title, creator, members, color });
    // Populate members and creator for response
    const populatedGroup = await GroupTransaction.findById(group._id)
      .populate('members.user', 'email')
      .populate('creator', 'email');
    // Map members to include email
    const groupObj = populatedGroup.toObject();
    groupObj.members = groupObj.members.map(m => ({
      _id: m.user._id,
      email: m.user.email,
      joinedAt: m.joinedAt,
      leftAt: m.leftAt
    }));
    groupObj.creator = {
      _id: groupObj.creator._id,
      email: groupObj.creator.email
    };
    res.status(201).json({ group: groupObj });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.addMember = async (req, res) => {
  try {
    const { groupId } = req.params;
    const { email } = req.body;
    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    if (group.creator.toString() !== req.user._id.toString()) return res.status(403).json({ error: 'Only creator can add members' });
    
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: 'User not found' });
    
    // Check if trying to add the group creator
    if (user._id.toString() === group.creator.toString()) {
      return res.status(400).json({ error: 'Group creator is already a member by default' });
    }
    
    if (group.members.some(m => m.user.toString() === user._id.toString() && !m.leftAt)) return res.status(400).json({ error: 'User already a member' });
    group.members.push({ user: user._id, joinedAt: new Date() });
    group.balances.push({ user: user._id, balance: 0 });
    await group.save();
    // Populate members and creator for response
    const populatedGroup = await GroupTransaction.findById(group._id)
      .populate('members.user', 'email')
      .populate('creator', 'email');
    // Map members to include email
    const groupObj = populatedGroup.toObject();
    groupObj.members = groupObj.members.map(m => ({
      _id: m.user._id,
      email: m.user.email,
      joinedAt: m.joinedAt,
      leftAt: m.leftAt
    }));
    groupObj.creator = {
      _id: groupObj.creator._id,
      email: groupObj.creator.email
    };
    res.json({ group: groupObj });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.removeMember = async (req, res) => {
  try {
    const { groupId } = req.params;
    const { email } = req.body;
    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    if (group.creator.toString() !== req.user._id.toString()) return res.status(403).json({ error: 'Only creator can remove members' });
    
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: 'User not found' });
    
    // Check if trying to remove the creator
    if (user._id.toString() === group.creator.toString()) {
      return res.status(400).json({ error: 'Cannot remove group creator' });
    }
    
    // Check if user is a member
    const memberIndex = group.members.findIndex(m => m.user.toString() === user._id.toString() && !m.leftAt);
    if (memberIndex === -1) return res.status(400).json({ error: 'User is not a member of this group' });
    
    // Check if user has pending balances
    const userBalance = group.balances.find(b => b.user.toString() === user._id.toString());
    if (userBalance && userBalance.balance !== 0) {
      return res.status(400).json({ error: 'Cannot remove member with pending balances. Please ask them to settle their balance first.' });
    }
    
    // Mark member as left
    group.members[memberIndex].leftAt = new Date();
    await group.save();
    
    const populatedGroup = await GroupTransaction.findById(group._id)
      .populate('members.user', 'email')
      .populate('creator', 'email');
    const groupObj = populatedGroup.toObject();
    groupObj.members = groupObj.members.map(m => ({
      _id: m.user._id,
      email: m.user.email,
      joinedAt: m.joinedAt,
      leftAt: m.leftAt
    }));
    groupObj.creator = {
      _id: groupObj.creator._id,
      email: groupObj.creator.email
    };
    res.json({ group: groupObj });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.addExpense = async (req, res) => {
  try {
    const { groupId } = req.params;
    const { description, amount, splitType, split, date } = req.body;
    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    const userId = req.user._id;
    const userEmail = req.user.email; // Get user's email
    if (!group.members.some(m => m.user.toString() === userId.toString() && !m.leftAt)) return res.status(403).json({ error: 'Not a group member' });
    if (!description || !amount || amount <= 0) return res.status(400).json({ error: 'Description and positive amount required' });
    let splitArr = [];
    const activeMembers = group.members.filter(m => !m.leftAt);
    if (splitType === 'equal') {
      const per = parseFloat((amount / activeMembers.length).toFixed(2));
      let total = per * activeMembers.length;
      let diff = parseFloat((amount - total).toFixed(2));
      splitArr = activeMembers.map((m, i) => ({ user: m.user, amount: per + (i === 0 ? diff : 0) }));
    } else if (splitType === 'custom') {
      if (!Array.isArray(split) || split.reduce((a, b) => a + b.amount, 0) !== amount) return res.status(400).json({ error: 'Split must sum to total amount' });
      splitArr = split.map(s => ({ user: s.user, amount: s.amount }));
    } else {
      return res.status(400).json({ error: 'Invalid split type' });
    }
    // Add expense with user's email instead of ID
    group.expenses.push({ description, amount, addedBy: userEmail, date: date ? new Date(date) : new Date(), split: splitArr });
    // Update balances
    splitArr.forEach(s => {
      const bal = group.balances.find(b => b.user.toString() === s.user.toString());
      if (bal) bal.balance += s.amount;
    });
    const payerBal = group.balances.find(b => b.user.toString() === userId.toString());
    if (payerBal) payerBal.balance -= amount;
    await group.save();
    
    // Return populated group data
    const populatedGroup = await GroupTransaction.findById(group._id)
      .populate('members.user', 'email')
      .populate('creator', 'email');
    const groupObj = populatedGroup.toObject();
    
    // Process expenses to convert Object IDs to emails in addedBy field
    const processedExpenses = await processExpenses(groupObj.expenses);
    
    groupObj.members = groupObj.members.map(m => ({
      _id: m.user._id,
      email: m.user.email,
      joinedAt: m.joinedAt,
      leftAt: m.leftAt
    }));
    groupObj.creator = {
      _id: groupObj.creator._id,
      email: groupObj.creator.email
    };
    groupObj.expenses = processedExpenses;
    
    res.json({ group: groupObj });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.requestLeave = async (req, res) => {
  try {
    const { groupId } = req.params;
    const userId = req.user._id;
    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    if (!group.members.some(m => m.user.toString() === userId.toString() && !m.leftAt)) return res.status(403).json({ error: 'Not a group member' });
    if (!group.canRemoveMember(userId)) {
      if (!group.pendingLeaves.some(l => l.user.toString() === userId.toString())) {
        group.pendingLeaves.push({ user: userId });
        await group.save();
        // Send email to group creator (mock)
        // ...
      }
      return res.status(400).json({ error: 'Settle your balance before leaving. Request sent to group creator.' });
    }
    // Mark as left
    const member = group.members.find(m => m.user.toString() === userId.toString() && !m.leftAt);
    if (member) member.leftAt = new Date();
    await group.save();
    res.json({ group });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.settleBalance = async (req, res) => {
  try {
    const { groupId } = req.params;
    const { userId } = req.body; // user to settle
    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    if (group.creator.toString() !== req.user._id.toString()) return res.status(403).json({ error: 'Only creator can settle balances' });
    // Send OTP to creator's email
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    group._pendingOtp = { userId, otp, createdAt: new Date() };
    await sendGroupSettleOtp(req.user.email, otp);
    await group.save();
    res.json({ message: 'OTP sent to your email' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.otpVerifySettle = async (req, res) => {
  try {
    const { groupId } = req.params;
    const { userId, otp } = req.body;
    const group = await GroupTransaction.findById(groupId);
    if (!group || !group._pendingOtp) return res.status(400).json({ error: 'No pending OTP' });
    if (group._pendingOtp.userId !== userId || group._pendingOtp.otp !== otp) return res.status(400).json({ error: 'Invalid OTP' });
    // Settle balance
    const bal = group.balances.find(b => b.user.toString() === userId.toString());
    if (bal) bal.balance = 0;
    // Remove pending leave if any
    group.pendingLeaves = group.pendingLeaves.filter(l => l.user.toString() !== userId.toString());
    group._pendingOtp = undefined;
    await group.save();
    res.json({ group });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}; 

// Get all groups for the logged-in user (as creator or member)
exports.getUserGroups = async (req, res) => {
  try {
    const userId = req.user._id;
    // Find groups where user is creator or a member (and not left)
    const groups = await GroupTransaction.find({
      $or: [
        { creator: userId },
        { 'members.user': userId, 'members.leftAt': null }
      ]
    })
      .populate('members.user', 'email')
      .populate('creator', 'email')
      .sort({ createdAt: -1 });
    
    // Map to summary format
    const groupSummaries = await Promise.all(groups.map(async g => {
      const obj = g.toObject();
      
      // Process expenses to convert Object IDs to emails in addedBy field
      const processedExpenses = await processExpenses(obj.expenses);
      
      return {
        _id: obj._id,
        title: obj.title,
        creator: obj.creator ? { _id: obj.creator._id, email: obj.creator.email } : null,
        members: obj.members.map(m => ({
          _id: m.user._id,
          email: m.user.email,
          joinedAt: m.joinedAt,
          leftAt: m.leftAt
        })),
        expenses: processedExpenses,
        balances: obj.balances || [],
        color: obj.color,
        createdAt: obj.createdAt,
        updatedAt: obj.updatedAt
      };
    }));
    
    res.json({ groups: groupSummaries });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}; 

exports.updateGroupColor = async (req, res) => {
  try {
    const { groupId } = req.params;
    const { color } = req.body;
    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    if (group.creator.toString() !== req.user._id.toString()) return res.status(403).json({ error: 'Only creator can update color' });
    group.color = color || '#2196F3';
    await group.save();
    const populatedGroup = await GroupTransaction.findById(group._id)
      .populate('members.user', 'email')
      .populate('creator', 'email');
    const groupObj = populatedGroup.toObject();
    
    // Process expenses to convert Object IDs to emails in addedBy field
    const processedExpenses = await processExpenses(groupObj.expenses);
    
    groupObj.members = groupObj.members.map(m => ({
      _id: m.user._id,
      email: m.user.email,
      joinedAt: m.joinedAt,
      leftAt: m.leftAt
    }));
    groupObj.creator = {
      _id: groupObj.creator._id,
      email: groupObj.creator.email
    };
    groupObj.expenses = processedExpenses;
    
    res.json({ group: groupObj });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Delete group (only creator)
exports.deleteGroup = async (req, res) => {
  try {
    const { groupId } = req.params;
    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    if (group.creator.toString() !== req.user._id.toString()) return res.status(403).json({ error: 'Only creator can delete group' });
    
    // Check if any member has pending balances
    const hasPendingBalances = group.balances.some(b => b.balance !== 0);
    if (hasPendingBalances) {
      return res.status(400).json({ error: 'Cannot delete group with pending balances. Please settle all balances first.' });
    }
    
    await GroupTransaction.findByIdAndDelete(groupId);
    res.json({ message: 'Group deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Leave group (members only, not creator)
exports.leaveGroup = async (req, res) => {
  try {
    const { groupId } = req.params;
    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    
    // Check if user is the creator
    if (group.creator.toString() === req.user._id.toString()) {
      return res.status(400).json({ error: 'Group creator cannot leave. Use delete group instead.' });
    }
    
    // Check if user is a member
    const memberIndex = group.members.findIndex(m => m.user.toString() === req.user._id.toString() && !m.leftAt);
    if (memberIndex === -1) return res.status(400).json({ error: 'You are not a member of this group' });
    
    // Check if user has pending balances
    const userBalance = group.balances.find(b => b.user.toString() === req.user._id.toString());
    if (userBalance && userBalance.balance !== 0) {
      return res.status(400).json({ error: 'Cannot leave group with pending balances. Please settle your balance first.' });
    }
    
    // Mark member as left
    group.members[memberIndex].leftAt = new Date();
    await group.save();
    
    const populatedGroup = await GroupTransaction.findById(group._id)
      .populate('members.user', 'email')
      .populate('creator', 'email');
    const groupObj = populatedGroup.toObject();
    
    // Process expenses to convert Object IDs to emails in addedBy field
    const processedExpenses = await processExpenses(groupObj.expenses);
    
    groupObj.members = groupObj.members.map(m => ({
      _id: m.user._id,
      email: m.user.email,
      joinedAt: m.joinedAt,
      leftAt: m.leftAt
    }));
    groupObj.creator = {
      _id: groupObj.creator._id,
      email: groupObj.creator.email
    };
    groupObj.expenses = processedExpenses;
    
    res.json({ group: groupObj });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}; 

// Delete expense (only creator)
exports.deleteExpense = async (req, res) => {
  try {
    const { groupId, expenseId } = req.params;
    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    if (group.creator.toString() !== req.user._id.toString()) return res.status(403).json({ error: 'Only creator can delete expenses' });
    
    // Find and remove the expense
    const expenseIndex = group.expenses.findIndex(e => e._id.toString() === expenseId);
    if (expenseIndex === -1) return res.status(404).json({ error: 'Expense not found' });
    
    // Remove the expense
    group.expenses.splice(expenseIndex, 1);
    await group.save();
    
    const populatedGroup = await GroupTransaction.findById(group._id)
      .populate('members.user', 'email')
      .populate('creator', 'email');
    const groupObj = populatedGroup.toObject();
    
    // Process expenses to convert Object IDs to emails in addedBy field
    const processedExpenses = await processExpenses(groupObj.expenses);
    
    groupObj.members = groupObj.members.map(m => ({
      _id: m.user._id,
      email: m.user.email,
      joinedAt: m.joinedAt,
      leftAt: m.leftAt
    }));
    groupObj.creator = {
      _id: groupObj.creator._id,
      email: groupObj.creator.email
    };
    groupObj.expenses = processedExpenses;
    
    res.json({ group: groupObj });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}; 