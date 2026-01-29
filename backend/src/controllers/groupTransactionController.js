const GroupTransaction = require('../models/groupTransaction');
const User = require('../models/user');
const Subscription = require('../models/subscription');
const { sendGroupSettleOtp } = require('../utils/groupSettleOtp');
const { sendGroupLeaveRequestEmail } = require('../utils/groupLeaveRequestEmail');
const groupTransactionEmail = require('../utils/groupTransactionEmail');
const mongoose = require('mongoose');
const { logGroupActivity, logGroupActivityForAllMembers } = require('./activityController');
const PDFDocument = require('pdfkit');
const { sendGroupReceiptEmail } = require('../utils/groupReceiptEmail');

// Helper function to process expenses and convert Object IDs to emails in addedBy field
async function processExpenses(expenses) {
  return await Promise.all((expenses || []).map(async expense => {
    // Since we now store emails directly in addedBy, no conversion is needed
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
    const { title, memberEmails, color } = req.body;
    const creator = req.user;

    if (!creator) {
      return res.status(400).json({ error: 'Creator not found' });
    }

    if (!title) {
      return res.status(400).json({ error: 'Title is required' });
    }
    
    // Filter out creator's email from memberEmails (they're added automatically)
    const filteredMemberEmails = memberEmails.filter(email => email !== creator.email);
    
    // Find users by email
    const users = await User.find({ email: { $in: filteredMemberEmails } });
    if (users.length !== filteredMemberEmails.length) {
      return res.status(400).json({ error: 'One or more members do not exist' });
    }
    
    const memberIds = users.map(u => u._id.toString());
    // Always add creator as the first member
    memberIds.unshift(creator._id.toString());
    
    const members = memberIds.map(id => ({ user: id }));
    const group = await GroupTransaction.create({ title, creator: creator._id, members, color });
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
    res.status(201).json({ 
        message: "Group created successfully",
        group: groupObj, 
        freeGroupsRemaining: creator.freeGroupsRemaining 
    });
    
    // Log activity for group creation - all members get notified
    try {
      const creatorInfo = {
        creatorId: creator._id,
        creatorEmail: creator.email
      };
      await logGroupActivityForAllMembers('group_created', group, {}, null, creatorInfo);
      groupTransactionEmail.sendGroupCreatedEmail(populatedGroup, creator);
    } catch (e) {
      console.error('Failed to log group activity or send email:', e);
    }
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
    
    // Check if user is already an active member
    if (group.members.some(m => m.user.toString() === user._id.toString() && !m.leftAt)) {
      return res.status(400).json({ error: 'User already a member' });
    }
    
    // Check if user was previously removed and handle re-adding
    const existingMemberIndex = group.members.findIndex(m => m.user.toString() === user._id.toString());
    if (existingMemberIndex !== -1) {
      // User was previously in the group, reactivate them
      group.members[existingMemberIndex].leftAt = null;
      group.members[existingMemberIndex].joinedAt = new Date(); // Update join date
      
      // Check if balance entry exists, if not create one
      const existingBalance = group.balances.find(b => b.user.toString() === user._id.toString());
      if (!existingBalance) {
        group.balances.push({ user: user._id, balance: 0 });
      }
    } else {
      // User is completely new to the group
      group.members.push({ user: user._id, joinedAt: new Date() });
      group.balances.push({ user: user._id, balance: 0 });
    }
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
    
    // Log activity for member addition - all members get notified
    try {
      const creatorInfo = {
        creatorId: req.user._id,
        creatorEmail: req.user.email
      };
      await logGroupActivityForAllMembers('member_added', group, {
        memberEmail: email
      }, null, creatorInfo);
      groupTransactionEmail.sendMemberAddedEmail(populatedGroup, email, req.user.email);
    } catch (e) {
      console.error('Failed to log group activity or send email:', e);
    }
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
    
    // Log activity for member removal - all members get notified
    try {
      const creatorInfo = {
        creatorId: req.user._id,
        creatorEmail: req.user.email
      };
      await logGroupActivityForAllMembers('member_removed', group, {
        memberEmail: email
      }, null, creatorInfo);

      // Send email to the removed member first
      groupTransactionEmail.sendYouHaveBeenRemovedEmail(populatedGroup, email, req.user.email);
      // Then, send email to the rest of the group
      groupTransactionEmail.sendMemberRemovedEmail(populatedGroup, email, req.user.email);
    } catch (e) {
      console.error('Failed to log group activity or send email:', e);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.addExpense = async (req, res) => {
  try {
    console.log('addExpense called with body:', req.body);
    const { groupId } = req.params;
    const { description, amount, splitType, split, date, selectedMembers } = req.body;
    console.log('Parsed data:', { groupId, description, amount, splitType, split, selectedMembers });
    
    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    console.log('Group found:', group._id);
    
    const userId = req.user._id;
    
    // Fetch user's email from database since req.user.email might not be populated
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ error: 'User not found' });
    const userEmail = user.email;
    
    console.log('User:', { userId, userEmail });
    
    if (!group.members.some(m => m.user.toString() === userId.toString() && !m.leftAt)) return res.status(403).json({ error: 'Not a group member' });
    if (!description || !amount || amount <= 0) return res.status(400).json({ error: 'Description and positive amount required' });
    
    // Validate selected members
    if (!selectedMembers || !Array.isArray(selectedMembers) || selectedMembers.length === 0) {
      return res.status(400).json({ error: 'At least one member must be selected for the expense' });
    }
    
    // Get active members and validate selected members
    const activeMembers = group.members.filter(m => !m.leftAt);
    
    // Populate members if not already populated
    let populatedActiveMembers = activeMembers;
    if (activeMembers.length > 0 && typeof activeMembers[0].user === 'object' && !activeMembers[0].user.email) {
      // Members are not populated, we need to populate them
      const populatedGroup = await GroupTransaction.findById(groupId)
        .populate('members.user', 'email');
      populatedActiveMembers = populatedGroup.members.filter(m => !m.leftAt);
    }
    
    const activeMemberEmails = populatedActiveMembers.map(m => {
      if (m.user && typeof m.user === 'object' && m.user.email) {
        return m.user.email;
      }
      return null;
    }).filter(email => email !== null);
    
    console.log('Active member emails:', activeMemberEmails);
    console.log('Selected members:', selectedMembers);
    
    // Validate that all selected members are active members
    const invalidMembers = selectedMembers.filter(email => !activeMemberEmails.includes(email));
    if (invalidMembers.length > 0) {
      return res.status(400).json({ error: `Invalid members selected: ${invalidMembers.join(', ')}` });
    }
    
    let splitArr = [];
    
    if (splitType === 'equal') {
      console.log('Processing equal split');
      // Split equally among selected members only
      const per = parseFloat((amount / selectedMembers.length).toFixed(2));
      let total = per * selectedMembers.length;
      let diff = parseFloat((amount - total).toFixed(2));
      
      // Create split array for selected members only
      splitArr = selectedMembers.map((email, i) => {
        const member = populatedActiveMembers.find(m => {
          if (m.user && typeof m.user === 'object' && m.user.email) {
            return m.user.email === email;
          }
          return false;
        });
        if (member) {
          return { user: member.user._id || member.user, amount: per + (i === 0 ? diff : 0) };
        }
        return null;
      }).filter(item => item !== null);
      
      console.log('Equal split array:', splitArr);
      
    } else if (splitType === 'custom') {
      console.log('Processing custom split');
      if (!Array.isArray(split) || split.length === 0) {
        return res.status(400).json({ error: 'Custom split requires split data for each selected member' });
      }
      
      // Validate that split amounts sum to total amount
      const totalSplitAmount = split.reduce((sum, item) => sum + (item.amount || 0), 0);
      if (Math.abs(totalSplitAmount - amount) > 0.01) { // Allow small floating point differences
        return res.status(400).json({ error: `Split amounts (${totalSplitAmount}) must sum to total amount (${amount})` });
      }
      
      // Convert email-based split to user ID-based split
      splitArr = [];
      for (const splitItem of split) {
        const member = populatedActiveMembers.find(m => {
          if (m.user && typeof m.user === 'object' && m.user.email) {
            return m.user.email === splitItem.user;
          }
          return false;
        });
        
        if (!member) {
          return res.status(400).json({ error: `Member with email ${splitItem.user} not found in selected members` });
        }
        
        if (splitItem.amount <= 0) {
          return res.status(400).json({ error: `Amount for ${splitItem.user} must be greater than 0` });
        }
        
        splitArr.push({
          user: member.user._id || member.user,
          amount: splitItem.amount
        });
      }
      
      console.log('Custom split array:', splitArr);
    } else {
      return res.status(400).json({ error: 'Invalid split type' });
    }
    
    // Add expense with selected members
    const expenseData = { 
      description, 
      amount, 
      addedBy: userEmail, 
      date: date ? new Date(date) : new Date(), 
      selectedMembers: selectedMembers,
      split: splitArr 
    };
    console.log('Adding expense with data:', expenseData);
    
    group.expenses.push(expenseData);
    
    // Update balances - only for selected members
    splitArr.forEach(s => {
      const bal = group.balances.find(b => b.user.toString() === s.user.toString());
      if (bal) bal.balance += s.amount;
    });
    const payerBal = group.balances.find(b => b.user.toString() === userId.toString());
    if (payerBal) payerBal.balance -= amount;
    
    console.log('Saving group...');
    await group.save();
    console.log('Group saved successfully');
    
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
    
    console.log('Sending response with updated group');
    res.json({ group: groupObj });
    
    // Log activity for expense addition - all members get notified
    try {
      const creatorInfo = {
        creatorId: userId,
        creatorEmail: req.user.email
      };
      await logGroupActivityForAllMembers('expense_added', group, {
        expenseDescription: description,
        expenseAmount: amount,
        currency: '₹' // Default currency, you might want to make this configurable
      }, null, creatorInfo);
      groupTransactionEmail.sendExpenseAddedEmail(populatedGroup, expenseData, userEmail);
    } catch (e) {
      console.error('Failed to log group activity or send email:', e);
    }
  } catch (err) {
    console.error('Error in addExpense:', err);
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
    
    const createdGroupsCount = groups.filter(g => g.creator && g.creator._id.toString() === userId.toString()).length;

    // Map to summary format
    const groupSummaries = await Promise.all(groups.map(async g => {
      const obj = g.toObject();
      
      // Process expenses to convert Object IDs to emails in addedBy field
      const processedExpenses = await processExpenses(obj.expenses);
      
      return {
        _id: obj._id,
        title: obj.title,
        creator: obj.creator ? { _id: obj.creator._id, email: obj.creator.email } : null,
        members: (obj.members || []).map(m => {
          if (m && m.user) {
            return {
              _id: m.user._id,
              email: m.user.email,
              joinedAt: m.joinedAt,
              leftAt: m.leftAt
            };
          }
          return null;
        }).filter(m => m !== null),
        expenses: processedExpenses,
        balances: obj.balances || [],
        color: obj.color,
        favourite: obj.favourite || [],
        messageCount: obj.messageCount || 0,
        createdAt: obj.createdAt,
        updatedAt: obj.updatedAt
      };
    }));
    
    res.json({ groups: groupSummaries, totalGroups: groupSummaries.length, createdGroupsCount });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}; 

exports.toggleGroupFavourite = async (req, res) => {
  try {
    const { groupId } = req.params;
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }

    const group = await GroupTransaction.findById(groupId);

    if (!group) {
      return res.status(404).json({ error: 'Group not found' });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Check if user is a member of the group
    const isMember = group.members.some(member => member.user.toString() === user._id.toString() && !member.leftAt);
    if (!isMember) {
      return res.status(403).json({ error: 'Only group members can favourite a group' });
    }

    const favouriteIndex = group.favourite.indexOf(email);

    if (favouriteIndex > -1) {
      // Remove from favourites
      group.favourite.splice(favouriteIndex, 1);
    } else {
      // Add to favourites
      group.favourite.push(email);
    }

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
    
    // Delete the group regardless of pending balances
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
    
    // Calculate user's total split amount (pending balance) - excluding settled amounts
    let userBalance = 0;
    for (let expense of group.expenses) {
      for (let splitItem of expense.split) {
        if (splitItem.user.toString() === req.user._id.toString()) {
          // Only include unsettled amounts
          if (!splitItem.settled) {
            userBalance += splitItem.amount;
          }
        }
      }
    }
    
    // Check if user has pending balances
    if (userBalance !== 0) {
      return res.status(400).json({
        error: 'Cannot leave group with pending balances. Please settle your balance first or send a leave request to the group creator.',
        userBalance: userBalance
      });
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

    // Send email notification to the rest of the group
    try {
      groupTransactionEmail.sendMemberLeftEmail(populatedGroup, req.user.email);
    } catch (e) {
      console.error('Failed to send member left email:', e);
    }
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
    
    // Store expense details before removal for activity logging
    const deletedExpense = group.expenses[expenseIndex];
    
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
    
    // Log activity for expense deletion - all members get notified
    try {
      const creatorInfo = {
        creatorId: req.user._id,
        creatorEmail: req.user.email
      };
      await logGroupActivityForAllMembers('expense_deleted', group, {
        expenseDescription: deletedExpense.description,
        expenseAmount: deletedExpense.amount,
        currency: '₹' // Default currency, you might want to make this configurable
      }, null, creatorInfo);
      groupTransactionEmail.sendExpenseDeletedEmail(populatedGroup, deletedExpense, req.user.email);
    } catch (e) {
      console.error('Failed to log group activity or send email:', e);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}; 

// Edit expense (only the person who created the expense)
exports.editExpense = async (req, res) => {
  try {
    const { groupId, expenseId } = req.params;
    const { description, amount, selectedMembers, splitType, customSplitAmounts, date } = req.body;
    // Handle both user and admin tokens (different field names)
    let userEmail = req.user.email;
    const userId = req.user._id;
    
    // Debug: Check what's in req.user
    console.log('req.user object:', req.user);
    console.log('req.user.email:', req.user.email);
    console.log('req.user._id:', req.user._id);
    
    // If email is not in token, fetch it from database
    if (!userEmail) {
      console.log('Email not in token, fetching from database...');
      const User = require('../models/user');
      const Admin = require('../models/admin');
      
      // Try to find user first, then admin
      let user = await User.findById(userId);
      if (user) {
        userEmail = user.email;
        console.log('Found user email from database:', userEmail);
      } else {
        let admin = await Admin.findById(userId);
        if (admin) {
          userEmail = admin.email;
          console.log('Found admin email from database:', userEmail);
        }
      }
    }
    
    const group = await GroupTransaction.findById(groupId)
      .populate('members.user', 'email')
      .populate('creator', 'email');
    if (!group) return res.status(404).json({ error: 'Group not found' });
    
    // Find the expense
    const expenseIndex = group.expenses.findIndex(e => e._id.toString() === expenseId);
    if (expenseIndex === -1) return res.status(404).json({ error: 'Expense not found' });
    
    const expense = group.expenses[expenseIndex];
    
    // Check if the current user is the one who created this expense
    console.log('Expense addedBy:', expense.addedBy);
    console.log('Current user email:', userEmail);
    console.log('Expense data:', expense);
    
    // Normalize email comparison (case-insensitive)
    const normalizedExpenseAddedBy = (expense.addedBy || '').toLowerCase().trim();
    const normalizedUserEmail = (userEmail || '').toLowerCase().trim();
    
    console.log('Normalized expense addedBy:', normalizedExpenseAddedBy);
    console.log('Normalized user email:', normalizedUserEmail);
    
    if (normalizedExpenseAddedBy !== normalizedUserEmail) {
      console.log('Permission denied - emails do not match');
      return res.status(403).json({ 
        error: 'Only the person who created this expense can edit it',
        debug: {
          expenseAddedBy: expense.addedBy,
          userEmail: userEmail,
          normalizedExpenseAddedBy: normalizedExpenseAddedBy,
          normalizedUserEmail: normalizedUserEmail
        }
      });
    }
    
    console.log('Permission granted - proceeding with edit');
    
    // Validate required fields
    if (!description || !amount || amount <= 0) {
      return res.status(400).json({ error: 'Description and valid amount are required' });
    }
    
    // Validate that all selected members are active (haven't left the group)
    const activeMembers = group.members.filter(m => !m.leftAt).map(m => m.user.email);
    const inactiveSelectedMembers = selectedMembers.filter(email => !activeMembers.includes(email));
    if (inactiveSelectedMembers.length > 0) {
      return res.status(400).json({ 
        error: `Cannot include members who have left the group: ${inactiveSelectedMembers.join(', ')}` 
      });
    }
    
    // Remove old expense from balances
    const oldAmount = expense.amount;
    expense.split.forEach(s => {
      const bal = group.balances.find(b => b.user.toString() === s.user.toString());
      if (bal) bal.balance -= s.amount;
    });
    const payerBal = group.balances.find(b => b.user.toString() === userId.toString());
    if (payerBal) payerBal.balance += oldAmount;
    
    // Prepare new split data based on split type
    let splitArr = [];
    if (splitType === 'equal') {
      const splitAmount = amount / selectedMembers.length;
      splitArr = selectedMembers.map(memberEmail => {
        const member = group.members.find(m => m.user.email === memberEmail && !m.leftAt);
        if (!member) {
          throw new Error(`Member with email ${memberEmail} not found`);
        }
        return {
          user: member.user._id,
          amount: splitAmount
        };
      });
    } else if (splitType === 'custom') {
      // Handle custom split with provided amounts
      if (!customSplitAmounts) {
        return res.status(400).json({ error: 'Custom split amounts are required for custom split type' });
      }
      
      splitArr = selectedMembers.map(memberEmail => {
        const member = group.members.find(m => m.user.email === memberEmail && !m.leftAt);
        if (!member) {
          throw new Error(`Member with email ${memberEmail} not found`);
        }
        const customAmount = customSplitAmounts[memberEmail] || 0;
        return {
          user: member.user._id,
          amount: customAmount
        };
      });
    } else {
      return res.status(400).json({ error: 'Invalid split type' });
    }
    
    // Update the expense
    expense.description = description;
    expense.amount = amount;
    expense.date = date ? new Date(date) : new Date();
    expense.selectedMembers = selectedMembers;
    expense.split = splitArr;
    
    // Update balances with new expense
    splitArr.forEach(s => {
      const bal = group.balances.find(b => b.user.toString() === s.user.toString());
      if (bal) bal.balance += s.amount;
    });
    const newPayerBal = group.balances.find(b => b.user.toString() === userId.toString());
    if (newPayerBal) newPayerBal.balance -= amount;
    
    await group.save();
    
    const groupObj = group.toObject();
    
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
    
    // Log activity for expense editing - all members get notified
    try {
      const creatorInfo = {
        creatorId: userId,
        creatorEmail: userEmail
      };
      await logGroupActivityForAllMembers('expense_edited', group, {
        expenseDescription: description,
        expenseAmount: amount,
        currency: '₹' // Default currency, you might want to make this configurable
      }, null, creatorInfo);
      groupTransactionEmail.sendExpenseEditedEmail(group, expense, userEmail);
    } catch (e) {
      console.error('Failed to log group activity or send email:', e);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}; 

exports.settleMemberExpenses = async (req, res) => {
  try {
    const { groupId } = req.params;
    const { email } = req.body;
    const group = await GroupTransaction.findById(groupId);
    
    if (!group) {
      return res.status(404).json({ error: 'Group not found' });
    }
    
    // Check if user is the group creator
    if (group.creator.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Only group creator can settle member expenses' });
    }
    
    // Find the member to settle
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Check if trying to settle the creator
    if (user._id.toString() === group.creator.toString()) {
      return res.status(400).json({ error: 'Cannot settle group creator expenses' });
    }
    
    // Check if user is a member
    const memberIndex = group.members.findIndex(m => m.user.toString() === user._id.toString() && !m.leftAt);
    if (memberIndex === -1) {
      return res.status(400).json({ error: 'User is not an active member of this group' });
    }
    
    console.log(`Settling expenses for member: ${email} in group: ${group.title}`);
    
    // Mark all split amounts for this member as settled in all expenses
    let expensesUpdated = 0;
    const creator = await User.findById(req.user._id);
    if (!creator) {
      return res.status(404).json({ error: 'Creator not found' });
    }
    
    for (let expense of group.expenses) {
      let expenseModified = false;
      
      for (let splitItem of expense.split) {
        if (splitItem.user.toString() === user._id.toString() && !splitItem.settled) {
          // Mark this split as settled (don't change the amount, just mark as settled)
          splitItem.settled = true;
          splitItem.settledAt = new Date();
          splitItem.settledBy = creator.email;
          expenseModified = true;
          console.log(`Marked split amount ${splitItem.amount} as settled for ${email} in expense: ${expense.description}`);
        }
      }
      
      if (expenseModified) {
        expensesUpdated++;
      }
    }
    
    console.log(`Updated ${expensesUpdated} expenses for member ${email}`);
    
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
    
    res.json({ 
      group: groupObj,
      message: `Successfully marked ${expensesUpdated} expenses as settled for ${email}` 
    });
    
    // Log activity for expense settlement - all members get notified
    try {
      const creatorInfo = {
        creatorId: req.user._id,
        creatorEmail: req.user.email
      };
      await logGroupActivityForAllMembers('expense_settled', group, {
        memberEmail: email,
        expensesUpdated: expensesUpdated
      }, null, creatorInfo);
    } catch (e) {
      console.error('Failed to log group activity:', e);
    }
  } catch (err) {
    console.error('Error settling member expenses:', err);
    res.status(500).json({ error: err.message });
  }
};

// Settle expense splits for specific members
exports.settleExpenseSplits = async (req, res) => {
  try {
    const { groupId, expenseId } = req.params;
    const { memberEmails } = req.body; // Array of member emails to settle
    
    if (!req.user || !req.user._id) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    const group = await GroupTransaction.findById(groupId);
    if (!group) {
      return res.status(404).json({ error: 'Group not found' });
    }
    
    // Check if user is the group creator
    if (group.creator.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Only group creator can settle expense splits' });
    }
    
    // Find the expense
    const expense = group.expenses.id(expenseId);
    if (!expense) {
      return res.status(404).json({ error: 'Expense not found' });
    }
    
    // Get creator's email
    const creator = await User.findById(req.user._id);
    if (!creator) {
      return res.status(404).json({ error: 'Creator not found' });
    }
    
    let settledCount = 0;
    let alreadySettledCount = 0;
    let alreadySettledMembers = [];
    
    // Settle splits for the specified members
    for (let splitItem of expense.split) {
      const member = await User.findById(splitItem.user);
      if (member && memberEmails.includes(member.email)) {
        if (splitItem.settled) {
          // Track already settled members
          alreadySettledCount++;
          alreadySettledMembers.push(member.email);
          continue;
        }
        splitItem.settled = true;
        splitItem.settledAt = new Date();
        splitItem.settledBy = creator.email;
        settledCount++;
      }
    }
    
    if (settledCount === 0) {
      if (alreadySettledCount > 0) {
        return res.status(400).json({ 
          error: `All selected members are already settled: ${alreadySettledMembers.join(', ')}` 
        });
      }
      return res.status(400).json({ error: 'No valid splits found to settle' });
    }
    
    await group.save();
    
    // Populate and return updated group
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
    
    let message = `Successfully settled ${settledCount} split(s) in expense`;
    if (alreadySettledCount > 0) {
      message += `. ${alreadySettledCount} member(s) were already settled: ${alreadySettledMembers.join(', ')}`;
    }
    
    res.json({ 
      group: groupObj,
      message: message,
      settledCount: settledCount,
      alreadySettledCount: alreadySettledCount,
      alreadySettledMembers: alreadySettledMembers
    });
    
    // Log activity for expense split settlement - all members get notified
    try {
      const creatorInfo = {
        creatorId: req.user._id,
        creatorEmail: req.user.email
      };
      await logGroupActivityForAllMembers('expense_settled', group, {
        expenseDescription: expense.description,
        settledCount: settledCount,
        memberEmails: memberEmails
      }, null, creatorInfo);
      groupTransactionEmail.sendExpenseSettledEmail(populatedGroup, expense, req.user.email);
    } catch (e) {
      console.error('Failed to log group activity or send email:', e);
    }
  } catch (err) {
    console.error('Error settling expense splits:', err);
    res.status(500).json({ error: err.message });
  }
}; 

// Send leave request to group creator
exports.sendLeaveRequest = async (req, res) => {
  try {
    const { groupId } = req.params;
    const group = await GroupTransaction.findById(groupId)
      .populate('members.user', 'email')
      .populate('creator', 'email');
    
    if (!group) {
      return res.status(404).json({ error: 'Group not found' });
    }
    
    // Check if user is a member (not creator)
    if (group.creator._id.toString() === req.user._id.toString()) {
      return res.status(400).json({ error: 'Group creator cannot send leave request. Use delete group instead.' });
    }
    
    const memberIndex = group.members.findIndex(m => m.user._id.toString() === req.user._id.toString() && !m.leftAt);
    if (memberIndex === -1) {
      return res.status(400).json({ error: 'You are not a member of this group' });
    }
    
    // Calculate user's total split amount (pending balance) - excluding settled amounts
    let userBalance = 0;
    for (let expense of group.expenses) {
      for (let splitItem of expense.split) {
        if (splitItem.user.toString() === req.user._id.toString()) {
          // Only include unsettled amounts
          if (!splitItem.settled) {
            userBalance += splitItem.amount;
          }
        }
      }
    }
    
    // Get user's email
    const user = await User.findById(req.user._id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Prepare group details for email
    const groupDetails = {
      title: group.title,
      members: group.members,
      expenses: group.expenses,
      creator: group.creator
    };
    
    // Send email to group creator
    const emailSent = await sendGroupLeaveRequestEmail(
      group.creator.email,
      groupDetails,
      user.email,
      userBalance
    );
    
    if (emailSent) {
      res.json({ 
        success: true, 
        message: 'Leave request sent to group creator successfully',
        userBalance: userBalance
      });
    } else {
      res.status(500).json({ error: 'Failed to send leave request email' });
    }
  } catch (err) {
    console.error('Error sending leave request:', err);
    res.status(500).json({ error: err.message });
  }
};

exports.generateGroupReceipt = async (req, res) => {
  try {
    const { groupId } = req.params;
    const { action, email } = req.body;

    if (!action || !email) {
      return res.status(400).json({ error: 'Action and email are required' });
    }

    const group = await GroupTransaction.findById(groupId)
      .populate('members.user', 'email name')
      .populate('creator', 'email name');

    if (!group) {
      return res.status(404).json({ error: 'Group not found' });
    }

    // Generate PDF with custom styling
    const doc = new PDFDocument({ 
      margin: 0,
      size: 'A4'
    });
    
    const buffers = [];
    doc.on('data', buffers.push.bind(buffers));
    doc.on('end', async () => {
      const pdfBuffer = Buffer.concat(buffers);

      if (action === 'email') {
        try {
          await sendGroupReceiptEmail(email, group, pdfBuffer);
          await logGroupActivityForAllMembers('receipt_generated', group, { action: 'email', recipient: email }, null, { creatorId: req.user._id, creatorEmail: req.user.email });
          res.json({ success: true, message: 'Group receipt sent to email' });
        } catch (error) {
          console.error('Failed to send group receipt email:', error);
          res.status(500).json({ error: 'Failed to send group receipt email' });
        }
      } else if (action === 'download') {
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `attachment; filename=group-receipt-${group._id}.pdf`);
        await logGroupActivityForAllMembers('receipt_generated', group, { action: 'download' }, null, { creatorId: req.user._id, creatorEmail: req.user.email });
        res.send(pdfBuffer);
      } else {
        res.status(400).json({ error: 'Invalid action' });
      }
    });

    // Define colors
    const limeGreen = '#C5E063';
    const darkText = '#1a1a1a';
    const lightGray = '#f5f5f5';
    const successGreen = '#4CAF50';
    const warningRed = '#F44336';

    // Add lime green header background
    doc.rect(0, 0, 595, 150).fill(limeGreen);

    // Add title "Cash Receipt" in header
    doc.fillColor(darkText)
       .font('Helvetica-Bold')
       .fontSize(36)
       .text('Group Transaction Receipt', 50, 55, { align: 'center' });

    // Create white rounded rectangle for main content
    const contentY = 180;
    const contentX = 50;
    const contentWidth = 495;

    let currentY = contentY;

    // Helper function to check if we need a new page
    const checkPageBreak = (spaceNeeded) => {
      if (currentY + spaceNeeded > 750) {
        doc.addPage();
        currentY = 50;
        return true;
      }
      return false;
    };

    // Draw white background box
    doc.rect(contentX, currentY, contentWidth, 120).fill('#ffffff');
    doc.rect(contentX, currentY, contentWidth, 120).stroke('#e0e0e0');

    // Title inside white box
    doc.fillColor(darkText)
       .font('Helvetica-Bold')
       .fontSize(16)
       .text('GROUP INFORMATION', contentX, currentY + 15, {
         width: contentWidth,
         align: 'center'
       });

    currentY += 50;
    const leftMargin = contentX + 40;

    // Generate receipt number
    const receiptNumber = group._id.toString().slice(-6).toUpperCase();
    
    // Group basic info
    doc.font('Helvetica-Bold')
       .text('Group Title:', leftMargin, currentY)
       .font('Helvetica')
       .text(group.title, leftMargin + 150, currentY);
    currentY += 20;

    doc.font('Helvetica-Bold')
       .text('Creator:', leftMargin, currentY)
       .font('Helvetica')
       .text(`${group.creator.name || group.creator.email}`, leftMargin + 150, currentY);
    currentY += 20;

    doc.font('Helvetica-Bold')
       .text('Created On:', leftMargin, currentY)
       .font('Helvetica')
       .text(new Date(group.createdAt).toLocaleDateString('en-US', { 
         year: 'numeric', 
         month: 'long', 
         day: 'numeric' 
       }), leftMargin + 150, currentY);
    currentY += 20;

    doc.font('Helvetica-Bold')
       .text('Status:', leftMargin, currentY)
       .font('Helvetica')
       .fillColor(group.isActive ? successGreen : warningRed)
       .text(group.isActive ? 'Active' : 'Inactive', leftMargin + 150, currentY);
    
    currentY += 40;
    checkPageBreak(150);

    // MEMBERS SECTION
    doc.fillColor(darkText)
       .font('Helvetica-Bold')
       .fontSize(14)
       .text('GROUP MEMBERS', leftMargin, currentY);
    currentY += 25;

    // Members table header
    doc.rect(leftMargin, currentY, contentWidth - 80, 25).fill(lightGray);
    doc.fillColor(darkText)
       .font('Helvetica-Bold')
       .fontSize(10)
       .text('Member Email', leftMargin + 5, currentY + 8, { width: 180 })
       .text('Joined', leftMargin + 190, currentY + 8, { width: 80 })
       .text('Left', leftMargin + 275, currentY + 8, { width: 80 })
       .text('Status', leftMargin + 360, currentY + 8, { width: 55 });
    currentY += 25;

    // Display members
    group.members.forEach((member, index) => {
      checkPageBreak(20);
      if (index % 2 === 0) {
        doc.rect(leftMargin, currentY, contentWidth - 80, 20).fill('#fafafa');
      }
      
      doc.fillColor(darkText)
         .font('Helvetica')
         .fontSize(9)
         .text(member.user.email.substring(0, 28), leftMargin + 5, currentY + 5, { width: 180 })
         .text(new Date(member.joinedAt).toLocaleDateString(), leftMargin + 190, currentY + 5, { width: 80 })
         .text(member.leftAt ? new Date(member.leftAt).toLocaleDateString() : '-', leftMargin + 275, currentY + 5, { width: 80 });
      
      doc.fillColor(member.leftAt ? warningRed : successGreen)
         .text(member.leftAt ? 'Left' : 'Active', leftMargin + 360, currentY + 5, { width: 55 });
      
      currentY += 20;
    });

    currentY += 30;
    checkPageBreak(150);

    // Display balances
    group.balances.forEach((balance, index) => {
      checkPageBreak(20);
      const member = group.members.find(m => m.user._id.equals(balance.user));
      if (member && member.user) {
        if (index % 2 === 0) {
          doc.rect(leftMargin, currentY, contentWidth - 80, 20).fill('#fafafa');
        }
        
        doc.fillColor(darkText)
           .font('Helvetica')
           .fontSize(9)
           .text(member.user.email, leftMargin + 5, currentY + 5, { width: 280 });
        
        const balanceColor = balance.balance > 0 ? warningRed : (balance.balance < 0 ? successGreen : darkText);
        doc.fillColor(balanceColor)
           .text(balance.balance.toFixed(2), leftMargin + 290, currentY + 5, { width: 125, align: 'right' });
        
        currentY += 20;
      }
    });

    currentY += 30;
    checkPageBreak(150);

    // EXPENSES SECTION
    doc.fillColor(darkText)
       .font('Helvetica-Bold')
       .fontSize(14)
       .text('DETAILED EXPENSES', leftMargin, currentY);
    currentY += 25;

    // Calculate total
    const totalAmount = group.expenses.reduce((sum, exp) => sum + exp.amount, 0);

    // Display each expense with full details
    group.expenses.forEach((expense, expIndex) => {
      checkPageBreak(200);

      // Expense box
      doc.rect(leftMargin, currentY, contentWidth - 80, 25).fill(limeGreen);
      doc.fillColor(darkText)
         .font('Helvetica-Bold')
         .fontSize(11)
         .text(`Expense #${expIndex + 1}: ${expense.description}`, leftMargin + 5, currentY + 7);
      currentY += 25;

      // Expense details
      doc.rect(leftMargin, currentY, contentWidth - 80, 90).fill('#ffffff');
      doc.rect(leftMargin, currentY, contentWidth - 80, 90).stroke('#e0e0e0');
      
      doc.fillColor(darkText)
         .font('Helvetica-Bold')
         .fontSize(9)
         .text('Amount:', leftMargin + 10, currentY + 10)
         .font('Helvetica')
         .text(`₹${expense.amount.toFixed(2)}`, leftMargin + 100, currentY + 10);
      
      doc.font('Helvetica-Bold')
         .text('Added By:', leftMargin + 10, currentY + 25)
         .font('Helvetica')
         .text(expense.addedBy, leftMargin + 100, currentY + 25);
      
      doc.font('Helvetica-Bold')
         .text('Date:', leftMargin + 10, currentY + 40)
         .font('Helvetica')
         .text(new Date(expense.date).toLocaleDateString('en-US', { 
           year: 'numeric', 
           month: 'long', 
           day: 'numeric',
           hour: '2-digit',
           minute: '2-digit'
         }), leftMargin + 100, currentY + 40);
      
      doc.font('Helvetica-Bold')
         .text('Selected Members:', leftMargin + 10, currentY + 55)
         .font('Helvetica')
         .fontSize(8)
         .text(expense.selectedMembers ? expense.selectedMembers.join(', ') : 'N/A', leftMargin + 100, currentY + 55, { width: 300 });
      
      currentY += 95;

      // Split details header
      checkPageBreak(100);
      doc.rect(leftMargin + 10, currentY, contentWidth - 100, 20).fill(lightGray);
      doc.fillColor(darkText)
         .font('Helvetica-Bold')
         .fontSize(9)
         .text('Member', leftMargin + 15, currentY + 6, { width: 150 })
         .text('Amount', leftMargin + 170, currentY + 6, { width: 70, align: 'right' })
         .text('Settled', leftMargin + 245, currentY + 6, { width: 60 })
         .text('Settled At', leftMargin + 310, currentY + 6, { width: 70 })
         .text('Settled By', leftMargin + 385, currentY + 6, { width: 60 });
      currentY += 20;

      // Split items
      expense.split.forEach((split, splitIndex) => {
        checkPageBreak(20);
        const member = group.members.find(m => m.user._id.equals(split.user));
        if (member && member.user) {
          if (splitIndex % 2 === 0) {
            doc.rect(leftMargin + 10, currentY, contentWidth - 100, 18).fill('#fafafa');
          }
          
          doc.fillColor(darkText)
             .font('Helvetica')
             .fontSize(8)
             .text(member.user.email.substring(0, 22), leftMargin + 15, currentY + 4, { width: 150 })
             .text(split.amount.toFixed(2), leftMargin + 170, currentY + 4, { width: 70, align: 'right' });
          
          doc.fillColor(split.settled ? successGreen : warningRed)
             .text(split.settled ? 'Yes' : 'No', leftMargin + 245, currentY + 4, { width: 60 });
          
          doc.fillColor(darkText)
             .text(split.settledAt ? new Date(split.settledAt).toLocaleDateString() : '-', leftMargin + 310, currentY + 4, { width: 70 })
             .text(split.settledBy ? split.settledBy.substring(0, 12) : '-', leftMargin + 385, currentY + 4, { width: 60 });
          
          currentY += 18;
        }
      });

      currentY += 25;
    });

    // Total summary
    checkPageBreak(80);
    doc.rect(leftMargin, currentY, contentWidth - 80, 35).fill(limeGreen);
    doc.fillColor(darkText)
       .font('Helvetica-Bold')
       .fontSize(14)
       .text('TOTAL EXPENSE:', leftMargin + 10, currentY + 10)
       .fontSize(16)
       .text(`₹${totalAmount.toFixed(2)}`, leftMargin + 200, currentY + 8, { width: 215, align: 'right' });
    
    currentY += 50;

    // Footer
    checkPageBreak(50);
    doc.fillColor('#999999')
       .font('Helvetica')
       .fontSize(8)
       .text(
         `Generated on ${new Date().toLocaleString()} | Group ID: ${group._id}`,
         50,
         currentY + 20,
         { align: 'center', width: 495 }
       );

    doc.end();

  } catch (err) {
    console.error('Error generating group receipt:', err);
    res.status(500).json({ error: 'Failed to generate group receipt', details: err.message });
  }
};