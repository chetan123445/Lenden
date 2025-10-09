const Activity = require('../models/activity');
const Transaction = require('../models/transaction');
const GroupTransaction = require('../models/groupTransaction');
const Note = require('../models/note');
const User = require('../models/user');

// Helper function to create activity log
const createActivityLog = async (userId, type, title, description, metadata = {}, relatedDocs = {}) => {
  try {
    const activity = await Activity.create({
      user: userId,
      type,
      title,
      description,
      metadata,
      ...relatedDocs
    });
    return activity;
  } catch (error) {
    console.error('Error creating activity log:', error);
    return null;
  }
};

// Get user activities with pagination and filtering
exports.getUserActivities = async (req, res) => {
  try {
    const userId = req.user._id;
    const { page = 1, limit = 20, type, startDate, endDate, search } = req.query;
    
    // Build query
    const query = { user: userId };
    
    if (type) {
      query.type = type;
    }
    
    if (startDate || endDate) {
      query.createdAt = {};
      if (startDate) query.createdAt.$gte = new Date(startDate);
      if (endDate) query.createdAt.$lte = new Date(endDate);
    }
    
    // Add search functionality
    if (search && search.trim()) {
      const searchRegex = new RegExp(search.trim(), 'i');
      query.$or = [
        { title: searchRegex },
        { description: searchRegex },
        { 'metadata.description': searchRegex },
        { 'metadata.otherParty': searchRegex },
        { 'metadata.clearedBy': searchRegex }
      ];
    }
    
    // Calculate pagination
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    // Get activities with populated references
    const activities = await Activity.find(query)
      .populate('relatedTransaction', 'transactionId amount currency date place')
      .populate('relatedGroup', 'title color')
      .populate('relatedNote', 'title content')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));
    
    // Get total count for pagination
    const total = await Activity.countDocuments(query);
    
    res.json({
      activities,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / parseInt(limit)),
        totalItems: total,
        hasNext: skip + activities.length < total,
        hasPrev: parseInt(page) > 1
      }
    });
  } catch (error) {
    console.error('Error fetching user activities:', error);
    res.status(500).json({ error: 'Failed to fetch activities' });
  }
};

// Get activity statistics
exports.getActivityStats = async (req, res) => {
  try {
    const userId = req.user._id;
    const { startDate, endDate } = req.query;
    
    const query = { user: userId };
    if (startDate || endDate) {
      query.createdAt = {};
      if (startDate) query.createdAt.$gte = new Date(startDate);
      if (endDate) query.createdAt.$lte = new Date(endDate);
    }
    
    // Get activity counts by type
    const activityCounts = await Activity.aggregate([
      { $match: query },
      { $group: { _id: '$type', count: { $sum: 1 } } },
      { $sort: { count: -1 } }
    ]);
    
    // Get total activities
    const totalActivities = await Activity.countDocuments(query);
    
    // Get recent activity (last 7 days)
    const recentQuery = { 
      user: userId, 
      createdAt: { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) } 
    };
    const recentActivities = await Activity.countDocuments(recentQuery);
    
    res.json({
      totalActivities,
      recentActivities,
      activityCounts,
      period: { startDate, endDate }
    });
  } catch (error) {
    console.error('Error fetching activity stats:', error);
    res.status(500).json({ error: 'Failed to fetch activity statistics' });
  }
};

// Create activity for transaction events
exports.logTransactionActivity = async (userId, type, transaction, metadata = {}, creatorInfo = null) => {
  const activityData = {
    title: '',
    description: '',
    amount: transaction.amount,
    currency: transaction.currency,
    relatedTransaction: transaction._id,
    metadata
  };
  
  // Check if this user is the creator/performer of the action
  const isCreator = creatorInfo && creatorInfo.creatorId && creatorInfo.creatorId.toString() === userId.toString();
  const creatorEmail = creatorInfo ? creatorInfo.creatorEmail : null;
  
  switch (type) {
    case 'transaction_created':
      activityData.title = 'Transaction Created';
      if (isCreator) {
        activityData.description = `Created by you (${creatorEmail}) - ${transaction.role} transaction of ${transaction.currency}${transaction.amount} with ${transaction.role === 'lender' ? transaction.counterpartyEmail : transaction.userEmail}`;
      } else {
        activityData.description = `Created by ${creatorEmail} - ${transaction.role} transaction of ${transaction.currency}${transaction.amount} with ${transaction.role === 'lender' ? transaction.counterpartyEmail : transaction.userEmail}`;
      }
      break;
    case 'transaction_cleared':
      activityData.title = 'Transaction Cleared';
      if (isCreator) {
        activityData.description = `Marked as cleared by you (${creatorEmail})`;
      } else {
        activityData.description = `Marked as cleared by ${creatorEmail}`;
      }
      break;
    case 'partial_payment_made':
      activityData.title = 'Partial Payment Made';
      if (isCreator) {
        activityData.description = `Made partial payment of ${transaction.currency}${metadata.paymentAmount} by you (${creatorEmail})`;
      } else {
        activityData.description = `Made partial payment of ${transaction.currency}${metadata.paymentAmount} by ${creatorEmail}`;
      }
      break;
    case 'partial_payment_received':
      activityData.title = 'Partial Payment Received';
      if (isCreator) {
        activityData.description = `Received partial payment of ${transaction.currency}${metadata.paymentAmount} by you (${creatorEmail})`;
      } else {
        activityData.description = `Received partial payment of ${transaction.currency}${metadata.paymentAmount} by ${creatorEmail}`;
      }
      break;
    case 'receipt_generated':
      activityData.title = 'Receipt Generated';
      activityData.description = `Generated a receipt for transaction with ${transaction.counterpartyEmail}`;
      break;
  }
  
  return await createActivityLog(userId, type, activityData.title, activityData.description, metadata, {
    relatedTransaction: transaction._id,
    amount: activityData.amount,
    currency: activityData.currency
  });
};

// Create activity for group events
exports.logGroupActivity = async (userId, type, group, metadata = {}) => {
  const activityData = {
    title: '',
    description: '',
    relatedGroup: group._id,
    metadata
  };
  
  switch (type) {
    case 'group_created':
      activityData.title = 'Group Created';
      activityData.description = `Created group "${group.title}"`;
      break;
    case 'group_joined':
      activityData.title = 'Joined Group';
      activityData.description = `Joined group "${group.title}"`;
      break;
    case 'group_left':
      activityData.title = 'Left Group';
      activityData.description = `Left group "${group.title}"`;
      break;
    case 'member_added':
      activityData.title = 'Member Added';
      activityData.description = `Added ${metadata.memberEmail} to group "${group.title}"`;
      break;
    case 'member_removed':
      activityData.title = 'Member Removed';
      activityData.description = `Removed ${metadata.memberEmail} from group "${group.title}"`;
      break;
    case 'expense_added':
      activityData.title = 'Expense Added';
      activityData.description = `Added expense "${metadata.expenseDescription}" of ${metadata.currency}${metadata.expenseAmount} to group "${group.title}"`;
      activityData.amount = metadata.expenseAmount;
      activityData.currency = metadata.currency;
      break;
    case 'expense_edited':
      activityData.title = 'Expense Edited';
      activityData.description = `Edited expense "${metadata.expenseDescription}" in group "${group.title}"`;
      break;
    case 'expense_deleted':
      activityData.title = 'Expense Deleted';
      activityData.description = `Deleted expense "${metadata.expenseDescription}" from group "${group.title}"`;
      break;
    case 'expense_settled':
      activityData.title = 'Expense Settled';
      activityData.description = `Settled expense "${metadata.expenseDescription}" in group "${group.title}"`;
      break;
  }
  
  return await createActivityLog(userId, type, activityData.title, activityData.description, metadata, {
    relatedGroup: group._id,
    amount: activityData.amount,
    currency: activityData.currency
  });
};

// Create activity for all group members
exports.logGroupActivityForAllMembers = async (type, group, metadata = {}, excludeUserId = null, creatorInfo = null) => {
  const activityData = {
    title: '',
    description: '',
    relatedGroup: group._id,
    metadata
  };
  
  // Get creator information
  const creatorEmail = creatorInfo ? creatorInfo.creatorEmail : null;
  
  switch (type) {
    case 'group_created':
      activityData.title = 'Group Created';
      activityData.description = `Created group "${group.title}"`;
      break;
    case 'group_joined':
      activityData.title = 'Joined Group';
      activityData.description = `Joined group "${group.title}"`;
      break;
    case 'group_left':
      activityData.title = 'Left Group';
      activityData.description = `Left group "${group.title}"`;
      break;
    case 'member_added':
      activityData.title = 'Member Added';
      activityData.description = `Added ${metadata.memberEmail} to group "${group.title}"`;
      break;
    case 'member_removed':
      activityData.title = 'Member Removed';
      activityData.description = `Removed ${metadata.memberEmail} from group "${group.title}"`;
      break;
    case 'expense_added':
      activityData.title = 'Expense Added';
      activityData.description = `Added expense "${metadata.expenseDescription}" of ${metadata.currency}${metadata.expenseAmount} to group "${group.title}"`;
      activityData.amount = metadata.expenseAmount;
      activityData.currency = metadata.currency;
      break;
    case 'expense_edited':
      activityData.title = 'Expense Edited';
      activityData.description = `Edited expense "${metadata.expenseDescription}" in group "${group.title}"`;
      break;
    case 'expense_deleted':
      activityData.title = 'Expense Deleted';
      activityData.description = `Deleted expense "${metadata.expenseDescription}" from group "${group.title}"`;
      break;
    case 'expense_settled':
      activityData.title = 'Expense Settled';
      activityData.description = `Settled expense "${metadata.expenseDescription}" in group "${group.title}"`;
      break;
    case 'receipt_generated':
      activityData.title = 'Group Receipt Generated';
      activityData.description = `Generated a receipt for group "${group.title}"`;
      break;
  }
  
  // Get all active group members (excluding the specified user if provided)
  const memberIds = group.members
    .filter(member => !member.leftAt) // Only active members
    .map(member => member.user._id.toString())
    .filter(memberId => !excludeUserId || memberId !== excludeUserId.toString());
  
  // Log activity for all members with context-specific messages
  const activityPromises = memberIds.map(userId => {
    // Check if this user is the creator/performer of the action
    const isCreator = creatorInfo && creatorInfo.creatorId && creatorInfo.creatorId.toString() === userId.toString();
    
    let contextDescription = activityData.description;
    
    // Add context-specific prefix for group activities
    if (creatorEmail && type !== 'group_created' && type !== 'group_joined' && type !== 'group_left') {
      if (isCreator) {
        contextDescription = `By you (${creatorEmail}) - ${activityData.description}`;
      } else {
        contextDescription = `By ${creatorEmail} - ${activityData.description}`;
      }
    }
    
    return createActivityLog(userId, type, activityData.title, contextDescription, metadata, {
      relatedGroup: group._id,
      amount: activityData.amount,
      currency: activityData.currency
    });
  });
  
  return await Promise.all(activityPromises);
};

// Create activity for note events
exports.logNoteActivity = async (userId, type, note, metadata = {}, creatorInfo = null) => {
  const activityData = {
    title: '',
    description: '',
    relatedNote: note._id,
    metadata
  };
  
  // Check if this user is the creator/performer of the action
  const isCreator = creatorInfo && creatorInfo.creatorId && creatorInfo.creatorId.toString() === userId.toString();
  const creatorEmail = creatorInfo ? creatorInfo.creatorEmail : null;
  
  switch (type) {
    case 'note_created':
      activityData.title = 'Note Created';
      if (isCreator) {
        activityData.description = `Created by you (${creatorEmail}) - note "${note.title}"`;
      } else {
        activityData.description = `Created by ${creatorEmail} - note "${note.title}"`;
      }
      break;
    case 'note_edited':
      activityData.title = 'Note Edited';
      if (isCreator) {
        activityData.description = `Edited by you (${creatorEmail}) - note "${note.title}"`;
      } else {
        activityData.description = `Edited by ${creatorEmail} - note "${note.title}"`;
      }
      break;
    case 'note_deleted':
      activityData.title = 'Note Deleted';
      if (isCreator) {
        activityData.description = `Deleted by you (${creatorEmail}) - note "${note.title}"`;
      } else {
        activityData.description = `Deleted by ${creatorEmail} - note "${note.title}"`;
      }
      break;
  }
  
  return await createActivityLog(userId, type, activityData.title, activityData.description, metadata, {
    relatedNote: note._id
  });
};

// Create activity for quick transaction events
exports.logQuickTransactionActivity = async (userId, type, transaction, metadata = {}) => {
  const activityData = {
    title: '',
    description: '',
    metadata
  };

  switch (type) {
    case 'quick_transaction_created':
      activityData.title = 'Quick Transaction Created';
      activityData.description = `You added a quick transaction of ${transaction.amount} ${transaction.currency} for "${transaction.description}" with ${metadata.counterpartyEmail}`;
      break;
    case 'quick_transaction_updated':
      activityData.title = 'Quick Transaction Updated';
      activityData.description = `You updated a quick transaction to ${transaction.amount} ${transaction.currency} for "${transaction.description}"`;
      break;
    case 'quick_transaction_deleted':
      activityData.title = 'Quick Transaction Deleted';
      activityData.description = `You deleted a quick transaction of ${transaction.amount} ${transaction.currency} for "${transaction.description}"`;
      break;
    case 'quick_transaction_cleared':
      activityData.title = 'Quick Transaction Cleared';
      activityData.description = `You cleared a quick transaction of ${transaction.amount} ${transaction.currency} for "${transaction.description}"`;
      break;
    case 'quick_transaction_cleared_all':
      activityData.title = 'All Quick Transactions Cleared';
      activityData.description = 'You cleared all your quick transactions.';
      break;
  }

  return await createActivityLog(userId, type, activityData.title, activityData.description, metadata);
};


// Create activity for profile events
exports.logProfileActivity = async (userId, type, metadata = {}) => {
  const activityData = {
    title: '',
    description: '',
    metadata
  };
  
  switch (type) {
    case 'profile_updated':
      activityData.title = 'Profile Updated';
      activityData.description = 'Updated profile information';
      break;
    case 'password_changed':
      activityData.title = 'Password Changed';
      activityData.description = 'Changed account password';
      break;
    case 'login':
      activityData.title = 'Login';
      activityData.description = 'Logged into account';
      break;
    case 'logout':
      activityData.title = 'Logout';
      activityData.description = 'Logged out of account';
      break;
  }
  
  return await createActivityLog(userId, type, activityData.title, activityData.description, metadata);
};

// Delete a specific activity
exports.deleteActivity = async (req, res) => {
  try {
    const userId = req.user._id;
    const { activityId } = req.params;
    
    // Find the activity and ensure it belongs to the user
    const activity = await Activity.findOne({ _id: activityId, user: userId });
    
    if (!activity) {
      return res.status(404).json({ error: 'Activity not found or you do not have permission to delete it' });
    }
    
    // Delete the activity
    await Activity.findByIdAndDelete(activityId);
    
    res.json({ 
      message: 'Activity deleted successfully',
      deletedActivityId: activityId
    });
  } catch (error) {
    console.error('Error deleting activity:', error);
    res.status(500).json({ error: 'Failed to delete activity' });
  }
};

// Delete old activities (cleanup function)
exports.cleanupOldActivities = async (req, res) => {
  try {
    const { days = 365 } = req.body; // Default to 1 year
    const cutoffDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    
    const result = await Activity.deleteMany({
      createdAt: { $lt: cutoffDate }
    });
    
    res.json({
      message: `Deleted ${result.deletedCount} activities older than ${days} days`,
      deletedCount: result.deletedCount
    });
  } catch (error) {
    console.error('Error cleaning up old activities:', error);
    res.status(500).json({ error: 'Failed to cleanup old activities' });
  }
};

// Export helper functions for use in other controllers
module.exports.createActivityLog = createActivityLog; 