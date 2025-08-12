const User = require('../models/user');
const Admin = require('../models/admin');
const Transaction = require('../models/transaction');
const GroupTransaction = require('../models/groupTransaction');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { sendAdminWelcomeEmail, sendAdminRemovalEmail } = require('../utils/adminEmailNotifications');

// Admin registration
const register = async (req, res) => {
  try {
    const { username, email, password, name } = req.body;

    // Check if admin already exists
    const existingAdmin = await Admin.findOne({ 
      $or: [{ email }, { username }]
    });

    if (existingAdmin) {
      return res.status(400).json({
        success: false,
        message: 'Admin with this email or username already exists'
      });
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // Create admin
    const admin = new Admin({
      username,
      email,
      password: hashedPassword,
      name,
      gender: 'Other', // Default gender for admin
    });

    await admin.save();

    // Generate JWT token
    const jwtSecret = process.env.JWT_SECRET || 'fallback-secret-key-for-development';
    const token = jwt.sign(
      { userId: admin._id, role: admin.role },
      jwtSecret,
      { expiresIn: '24h' }
    );

    res.status(201).json({
      success: true,
      message: 'Admin registered successfully',
      token,
      admin: {
        id: admin._id,
        username: admin.username,
        email: admin.email,
        name: admin.name,
        role: admin.role
      }
    });
  } catch (error) {
    console.error('Error registering admin:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to register admin'
    });
  }
};



// Get all users (for admin)
const getAllUsers = async (req, res) => {
  try {
    const users = await User.find({}, '-password').sort({ createdAt: -1 });
    
    res.json({
      success: true,
      users: users
    });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch users'
    });
  }
};

// Get user details with stats
const getUserDetails = async (req, res) => {
  try {
    const { userId } = req.params;
    
    const user = await User.findById(userId, '-password');
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Mock data for user stats (in a real app, you'd aggregate from transactions)
    const userStats = {
      totalTransactions: Math.floor(Math.random() * 100),
      totalAmount: Math.floor(Math.random() * 10000),
      successfulTransactions: Math.floor(Math.random() * 80),
      failedTransactions: Math.floor(Math.random() * 20),
      averageTransaction: Math.floor(Math.random() * 500),
      largestTransaction: Math.floor(Math.random() * 2000),
      totalGroups: Math.floor(Math.random() * 10),
      totalFriends: Math.floor(Math.random() * 50),
      daysActive: Math.floor(Math.random() * 365),
      lastActivity: new Date(),
      loginCount: Math.floor(Math.random() * 100),
      profileViews: Math.floor(Math.random() * 1000)
    };

    // Mock recent transactions
    const recentTransactions = [
      {
        id: '1',
        amount: 150.00,
        type: 'send',
        status: 'completed',
        createdAt: new Date()
      },
      {
        id: '2',
        amount: 75.50,
        type: 'receive',
        status: 'completed',
        createdAt: new Date(Date.now() - 86400000)
      }
    ];

    // Mock user activity
    const userActivity = [
      {
        action: 'login',
        timestamp: new Date()
      },
      {
        action: 'transaction',
        timestamp: new Date(Date.now() - 3600000)
      },
      {
        action: 'profile_update',
        timestamp: new Date(Date.now() - 86400000)
      }
    ];

    res.json({
      success: true,
      user: user,
      stats: userStats,
      recentTransactions: recentTransactions,
      userActivity: userActivity
    });
  } catch (error) {
    console.error('Error fetching user details:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch user details'
    });
  }
};

// Update user status (activate/deactivate)
const updateUserStatus = async (req, res) => {
  try {
    const { userId } = req.params;
    const { isActive } = req.body;

    const user = await User.findByIdAndUpdate(
      userId,
      { isActive: isActive },
      { new: true, select: '-password' }
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.json({
      success: true,
      message: `User ${isActive ? 'activated' : 'deactivated'} successfully`,
      user: user
    });
  } catch (error) {
    console.error('Error updating user status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update user status'
    });
  }
};

// Update user information
const updateUser = async (req, res) => {
  try {
    const { userId } = req.params;
    const updateData = req.body;

    // Remove sensitive fields that shouldn't be updated directly
    delete updateData.password;
    delete updateData.email; // Email should be updated through a separate process
    delete updateData.username; // Username should be updated through a separate process

    const user = await User.findByIdAndUpdate(
      userId,
      updateData,
      { new: true, select: '-password' }
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.json({
      success: true,
      message: 'User updated successfully',
      user: user
    });
  } catch (error) {
    console.error('Error updating user:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update user'
    });
  }
};

// Delete user
const deleteUser = async (req, res) => {
  try {
    const { userId } = req.params;

    const user = await User.findByIdAndDelete(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.json({
      success: true,
      message: 'User deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete user'
    });
  }
};

// Get system settings
const getSystemSettings = async (req, res) => {
  try {
    // In a real app, you'd store these in a separate SystemSettings model
    const systemSettings = {
      maintenanceMode: false,
      userRegistrationEnabled: true,
      emailVerificationRequired: true,
      phoneVerificationRequired: false,
      autoApproveUsers: false,
      enableNotifications: true,
      enableAnalytics: true,
      maxTransactionAmount: 10000,
      minTransactionAmount: 1,
      dailyTransactionLimit: 50000,
      monthlyTransactionLimit: 500000,
      defaultCurrency: 'USD',
      timezone: 'UTC',
      dateFormat: 'MM/DD/YYYY',
      timeFormat: '12-hour',
      language: 'English'
    };

    res.json({
      success: true,
      settings: systemSettings
    });
  } catch (error) {
    console.error('Error fetching system settings:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch system settings'
    });
  }
};

// Update system settings
const updateSystemSettings = async (req, res) => {
  try {
    const settings = req.body;

    // In a real app, you'd save these to a SystemSettings model
    console.log('System settings updated:', settings);

    res.json({
      success: true,
      message: 'System settings updated successfully'
    });
  } catch (error) {
    console.error('Error updating system settings:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update system settings'
    });
  }
};

// Get analytics settings
const getAnalyticsSettings = async (req, res) => {
  try {
    const analyticsSettings = {
      enableAnalytics: true,
      enableUserTracking: true,
      enableTransactionAnalytics: true,
      enablePerformanceMonitoring: true,
      enableErrorTracking: true,
      enableUsageAnalytics: true,
      reportFrequency: 'daily',
      reportFormat: 'pdf',
      autoGenerateReports: true,
      emailReports: false,
      reportEmail: '',
      dataRetentionPeriod: '1_year',
      anonymizeData: false,
      enableDataExport: true,
      enableDataBackup: true
    };

    res.json({
      success: true,
      settings: analyticsSettings
    });
  } catch (error) {
    console.error('Error fetching analytics settings:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch analytics settings'
    });
  }
};

// Update analytics settings
const updateAnalyticsSettings = async (req, res) => {
  try {
    const settings = req.body;

    console.log('Analytics settings updated:', settings);

    res.json({
      success: true,
      message: 'Analytics settings updated successfully'
    });
  } catch (error) {
    console.error('Error updating analytics settings:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update analytics settings'
    });
  }
};

// Get security settings
const getSecuritySettings = async (req, res) => {
  try {
    const securitySettings = {
      requireTwoFactorAuth: true,
      enableSessionTimeout: true,
      sessionTimeoutMinutes: 30,
      enableLoginNotifications: true,
      enableFailedLoginAlerts: true,
      maxFailedAttempts: 5,
      lockoutDuration: 15,
      enableIpWhitelist: false,
      allowedIps: '',
      enableGeolocationRestriction: false,
      allowedCountries: '',
      enableTimeBasedAccess: false,
      accessStartTime: '09:00',
      accessEndTime: '17:00',
      requireStrongPasswords: true,
      enablePasswordExpiry: true,
      passwordExpiryDays: 90,
      preventPasswordReuse: true,
      passwordHistoryCount: 5,
      enableAccountLockout: true
    };

    res.json({
      success: true,
      settings: securitySettings
    });
  } catch (error) {
    console.error('Error fetching security settings:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch security settings'
    });
  }
};

// Update security settings
const updateSecuritySettings = async (req, res) => {
  try {
    const settings = req.body;

    console.log('Security settings updated:', settings);

    res.json({
      success: true,
      message: 'Security settings updated successfully'
    });
  } catch (error) {
    console.error('Error updating security settings:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update security settings'
    });
  }
};

// Get notification settings
const getNotificationSettings = async (req, res) => {
  try {
    const notificationSettings = {
      systemAlerts: true,
      maintenanceAlerts: true,
      errorAlerts: true,
      performanceAlerts: true,
      securityAlerts: true,
      backupAlerts: true,
      newUserAlerts: true,
      suspiciousActivityAlerts: true,
      accountLockoutAlerts: true,
      failedLoginAlerts: true,
      userDeletionAlerts: true,
      bulkActionAlerts: true,
      largeTransactionAlerts: true,
      failedTransactionAlerts: true,
      suspiciousTransactionAlerts: true,
      dailyTransactionSummary: true,
      weeklyTransactionSummary: true,
      monthlyTransactionSummary: false,
      emailNotifications: true,
      pushNotifications: true,
      smsNotifications: false,
      inAppNotifications: true,
      notificationFrequency: 'immediate',
      quietHoursEnabled: false,
      quietHoursStart: '22:00',
      quietHoursEnd: '08:00',
      timezone: 'UTC'
    };

    res.json({
      success: true,
      settings: notificationSettings
    });
  } catch (error) {
    console.error('Error fetching notification settings:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch notification settings'
    });
  }
};

// Update notification settings
const updateNotificationSettings = async (req, res) => {
  try {
    const settings = req.body;

    console.log('Notification settings updated:', settings);

    res.json({
      success: true,
      message: 'Notification settings updated successfully'
    });
  } catch (error) {
    console.error('Error updating notification settings:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update notification settings'
    });
  }
};

// Get all admins
const getAllAdmins = async (req, res) => {
  try {
    const { search } = req.query;
    let query = {};

    if (search) {
      query = {
        $or: [
          { email: { $regex: search, $options: 'i' } },
          { username: { $regex: search, $options: 'i' } },
          { name: { $regex: search, $options: 'i' } }
        ]
      };
    }

    const admins = await Admin.find(query, '-password').sort({ createdAt: -1 });
    
    res.json({
      success: true,
      admins,
      total: admins.length
    });
  } catch (error) {
    console.error('Error fetching admins:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch admins'
    });
  }
};

function isPasswordValid(password) {
  const lengthValid = password.length >= 8 && password.length <= 30;
  const hasUpper = /[A-Z]/.test(password);
  const hasLower = /[a-z]/.test(password);
  const hasSpecial = /[^A-Za-z0-9]/.test(password);
  return lengthValid && hasUpper && hasLower && hasSpecial;
}

// Add new admin
const addAdmin = async (req, res) => {
  try {
    const { username, email, password, name, gender } = req.body;

    // Password validation
    if (!isPasswordValid(password)) {
      return res.status(400).json({
        success: false,
        message: 'Password must be 8-30 characters and include uppercase, lowercase, and special character'
      });
    }

    // Check in Admin collection
    const existingAdmin = await Admin.findOne({ 
      $or: [{ email }, { username }]
    });

    if (existingAdmin) {
      return res.status(400).json({
        success: false,
        message: existingAdmin.email === email ? 
          'Email already registered as an admin' : 
          'Username already taken by an admin'
      });
    }

    // Check in User collection
    const existingUser = await User.findOne({
      $or: [{ email }, { username }]
    });

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: existingUser.email === email ? 
          'Email already registered as a user' : 
          'Username already taken by a user'
      });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const admin = new Admin({
      username,
      email,
      password: hashedPassword,
      name,
      gender: gender || 'Other',
      isSuperAdmin: false
    });

    await admin.save();

    // Send welcome email with credentials
    await sendAdminWelcomeEmail(email, {
      name,
      username,
      email,
      password: password
    });

    res.status(201).json({
      success: true,
      message: 'Admin added successfully and welcome email sent',
      admin: {
        id: admin._id,
        username: admin.username,
        email: admin.email,
        name: admin.name
      }
    });
  } catch (error) {
    console.error('Error adding admin:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Failed to add admin'
    });
  }
};

// Remove admin
const removeAdmin = async (req, res) => {
  try {
    const { adminId } = req.params;
    
    const adminToRemove = await Admin.findById(adminId);
    
    if (!adminToRemove) {
      return res.status(404).json({
        success: false,
        message: 'Admin not found'
      });
    }

    // Check if trying to remove protected admin
    if (adminToRemove.isProtectedAdmin()) {
      return res.status(403).json({
        success: false,
        message: 'Cannot remove protected admin account'
      });
    }

    // Send removal notification email before deleting
    await sendAdminRemovalEmail(adminToRemove.email, adminToRemove.name);
    
    await Admin.findByIdAndDelete(adminId);

    res.json({
      success: true,
      message: 'Admin removed successfully and notification email sent'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to remove admin'
    });
  }
};

// Get all transactions (for admin)
const getAllTransactions = async (req, res) => {
  try {
    const { page = 1, limit = 10, sortBy = 'date', order = 'desc' } = req.query;
    const sortOrder = order === 'asc' ? 1 : -1;
    const transactions = await Transaction.find({})
      .sort({ [sortBy]: sortOrder })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));
    const totalTransactions = await Transaction.countDocuments();
    res.json({
      success: true,
      transactions,
      totalPages: Math.ceil(totalTransactions / limit),
      currentPage: parseInt(page),
    });
  } catch (error) {
    console.error('Error fetching transactions:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch transactions'
    });
  }
};

// Update a transaction (for admin)
const updateTransaction = async (req, res) => {
  try {
    const { transactionId } = req.params;
    const updateData = req.body;
    const transaction = await Transaction.findByIdAndUpdate(
      transactionId,
      updateData,
      { new: true }
    );
    if (!transaction) {
      return res.status(404).json({
        success: false,
        message: 'Transaction not found'
      });
    }
    res.json({
      success: true,
      message: 'Transaction updated successfully',
      transaction
    });
  } catch (error) {
    console.error('Error updating transaction:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update transaction'
    });
  }
};

// Delete a transaction (for admin)
const deleteTransaction = async (req, res) => {
  try {
    const { transactionId } = req.params;
    const transaction = await Transaction.findByIdAndDelete(transactionId);
    if (!transaction) {
      return res.status(404).json({
        success: false,
        message: 'Transaction not found'
      });
    }
    res.json({
      success: true,
      message: 'Transaction deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting transaction:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete transaction'
    });
  }
};

// Get all group transactions (for admin)
const getAllGroupTransactions = async (req, res) => {
  try {
    const { page = 1, limit = 10, sortBy = 'createdAt', order = 'desc' } = req.query;
    const sortOrder = order === 'asc' ? 1 : -1;
    const groups = await GroupTransaction.find({})
      .populate('members.user', 'email')
      .populate('creator', 'email')
      .sort({ [sortBy]: sortOrder })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));
    const totalGroups = await GroupTransaction.countDocuments();

    const groupSummaries = groups.map(g => {
      const obj = g.toObject();
      obj.members = obj.members.map(m => ({
        _id: m.user._id,
        email: m.user.email,
        joinedAt: m.joinedAt,
        leftAt: m.leftAt
      }));
      obj.creator = {
        _id: obj.creator._id,
        email: obj.creator.email
      };
      return obj;
    });

    res.json({
      success: true,
      groups: groupSummaries,
      totalPages: Math.ceil(totalGroups / limit),
      currentPage: parseInt(page),
    });
  } catch (error) {
    console.error('Error fetching group transactions:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch group transactions'
    });
  }
};

// Update a group transaction (for admin)
const updateGroupTransaction = async (req, res) => {
  try {
    const { groupId } = req.params;
    const updateData = req.body;

    const group = await GroupTransaction.findByIdAndUpdate(
      groupId,
      updateData,
      { new: true }
    );

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Group transaction not found'
      });
    }

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

    res.json({
      success: true,
      message: 'Group transaction updated successfully',
      group: groupObj
    });
  } catch (error) {
    console.error('Error updating group transaction:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update group transaction'
    });
  }
};

// Delete a group transaction (for admin)
const deleteGroupTransaction = async (req, res) => {
  try {
    const { groupId } = req.params;
    const group = await GroupTransaction.findByIdAndDelete(groupId);
    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Group transaction not found'
      });
    }
    res.json({
      success: true,
      message: 'Group transaction deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting group transaction:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete group transaction'
    });
  }
};

// Add member to group (for admin)
const addMemberToGroup = async (req, res) => {
  try {
    const { groupId } = req.params;
    const { email } = req.body;

    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: 'User not found' });

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
  } catch (error) {
    console.error('Error adding member to group:', error);
    res.status(500).json({ error: error.message });
  }
};

// Remove member from group (for admin)
const removeMemberFromGroup = async (req, res) => {
  try {
    const { groupId, memberId } = req.params;

    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const user = await User.findById(memberId);
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
  } catch (error) {
    console.error('Error removing member from group:', error);
    res.status(500).json({ error: error.message });
  }
};

// Add expense to group (for admin)
const addExpenseToGroup = async (req, res) => {
  try {
    const { groupId } = req.params;
    const { description, amount, splitType, split, date, selectedMembers, addedByEmail } = req.body;

    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const addedByUser = await User.findOne({ email: addedByEmail });
    if (!addedByUser) return res.status(404).json({ error: 'User who added expense not found' });

    if (!group.members.some(m => m.user.toString() === addedByUser._id.toString() && !m.leftAt)) return res.status(403).json({ error: 'User who added expense is not a group member' });
    if (!description || !amount || amount <= 0) return res.status(400).json({ error: 'Description and positive amount required' });

    // Validate selected members
    if (!selectedMembers || !Array.isArray(selectedMembers) || selectedMembers.length === 0) {
      return res.status(400).json({ error: 'At least one member must be selected for the expense' });
    }

    const activeMembers = group.members.filter(m => !m.leftAt);
    const activeMemberEmails = await Promise.all(activeMembers.map(async m => {
      const user = await User.findById(m.user);
      return user ? user.email : null;
    })).then(emails => emails.filter(email => email !== null));

    const invalidMembers = selectedMembers.filter(email => !activeMemberEmails.includes(email));
    if (invalidMembers.length > 0) {
      return res.status(400).json({ error: `Invalid members selected: ${invalidMembers.join(', ')}` });
    }

    let splitArr = [];
    if (splitType === 'equal') {
      const per = parseFloat((amount / selectedMembers.length).toFixed(2));
      let total = per * selectedMembers.length;
      let diff = parseFloat((amount - total).toFixed(2));

      splitArr = await Promise.all(selectedMembers.map(async (email, i) => {
        const member = await User.findOne({ email });
        return { user: member._id, amount: per + (i === 0 ? diff : 0) };
      }));
    } else if (splitType === 'custom') {
      if (!Array.isArray(split) || split.length === 0) {
        return res.status(400).json({ error: 'Custom split requires split data for each selected member' });
      }

      const totalSplitAmount = split.reduce((sum, item) => sum + (item.amount || 0), 0);
      if (Math.abs(totalSplitAmount - amount) > 0.01) {
        return res.status(400).json({ error: `Split amounts (${totalSplitAmount}) must sum to total amount (${amount})` });
      }

      splitArr = await Promise.all(split.map(async splitItem => {
        const member = await User.findOne({ email: splitItem.user });
        if (!member) throw new Error(`Member with email ${splitItem.user} not found`);
        if (splitItem.amount <= 0) throw new Error(`Amount for ${splitItem.user} must be greater than 0`);
        return { user: member._id, amount: splitItem.amount };
      }));
    } else {
      return res.status(400).json({ error: 'Invalid split type' });
    }

    const expenseData = {
      description,
      amount,
      addedBy: addedByEmail,
      date: date ? new Date(date) : new Date(),
      selectedMembers,
      split: splitArr
    };

    group.expenses.push(expenseData);

    splitArr.forEach(s => {
      const bal = group.balances.find(b => b.user.toString() === s.user.toString());
      if (bal) bal.balance += s.amount;
    });
    const payerBal = group.balances.find(b => b.user.toString() === addedByUser._id.toString());
    if (payerBal) payerBal.balance -= amount;

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
  } catch (error) {
    console.error('Error adding expense to group:', error);
    res.status(500).json({ error: error.message });
  }
};

// Update expense in group (for admin)
const updateExpenseInGroup = async (req, res) => {
  try {
    const { groupId, expenseId } = req.params;
    const { description, amount, selectedMembers, splitType, customSplitAmounts, date, addedByEmail } = req.body;

    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const expenseIndex = group.expenses.findIndex(e => e._id.toString() === expenseId);
    if (expenseIndex === -1) return res.status(404).json({ error: 'Expense not found' });

    const expense = group.expenses[expenseIndex];

    const addedByUser = await User.findOne({ email: addedByEmail });
    if (!addedByUser) return res.status(404).json({ error: 'User who added expense not found' });

    if (!description || !amount || amount <= 0) {
      return res.status(400).json({ error: 'Description and valid amount are required' });
    }

    const activeMembers = group.members.filter(m => !m.leftAt);
    const activeMemberEmails = await Promise.all(activeMembers.map(async m => {
      const user = await User.findById(m.user);
      return user ? user.email : null;
    })).then(emails => emails.filter(email => email !== null));

    const invalidMembers = selectedMembers.filter(email => !activeMemberEmails.includes(email));
    if (invalidMembers.length > 0) {
      return res.status(400).json({ 
        error: `Cannot include members who have left the group: ${invalidMembers.join(', ')}` 
      });
    }

    // Remove old expense from balances
    const oldAmount = expense.amount;
    const oldAddedBy = expense.addedBy;
    const oldSplit = expense.split;

    oldSplit.forEach(s => {
      const bal = group.balances.find(b => b.user.toString() === s.user.toString());
      if (bal) bal.balance -= s.amount;
    });
    const oldPayerBal = group.balances.find(b => b.user.toString() === addedByUser._id.toString());
    if (oldPayerBal) oldPayerBal.balance += oldAmount;

    let splitArr = [];
    if (splitType === 'equal') {
      const per = parseFloat((amount / selectedMembers.length).toFixed(2));
      let total = per * selectedMembers.length;
      let diff = parseFloat((amount - total).toFixed(2));

      splitArr = await Promise.all(selectedMembers.map(async (email, i) => {
        const member = await User.findOne({ email });
        return { user: member._id, amount: per + (i === 0 ? diff : 0) };
      }));
    } else if (splitType === 'custom') {
      if (!customSplitAmounts) {
        return res.status(400).json({ error: 'Custom split amounts are required for custom split type' });
      }

      splitArr = await Promise.all(selectedMembers.map(async memberEmail => {
        const member = await User.findOne({ email: memberEmail });
        if (!member) throw new Error(`Member with email ${memberEmail} not found`);
        const customAmount = customSplitAmounts[memberEmail] || 0;
        return { user: member._id, amount: customAmount };
      }));

      const totalSplitAmount = splitArr.reduce((sum, item) => sum + (item.amount || 0), 0);
      if (Math.abs(totalSplitAmount - amount) > 0.01) {
        return res.status(400).json({ error: `Split amounts (${totalSplitAmount}) must sum to total amount (${amount})` });
      }
    } else {
      return res.status(400).json({ error: 'Invalid split type' });
    }

    expense.description = description;
    expense.amount = amount;
    expense.addedBy = addedByEmail;
    expense.date = date ? new Date(date) : new Date();
    expense.selectedMembers = selectedMembers;
    expense.split = splitArr;

    splitArr.forEach(s => {
      const bal = group.balances.find(b => b.user.toString() === s.user.toString());
      if (bal) bal.balance += s.amount;
    });
    const newPayerBal = group.balances.find(b => b.user.toString() === addedByUser._id.toString());
    if (newPayerBal) newPayerBal.balance -= amount;

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
  } catch (error) {
    console.error('Error updating expense in group:', error);
    res.status(500).json({ error: error.message });
  }
};

// Delete expense from group (for admin)
const deleteExpenseFromGroup = async (req, res) => {
  try {
    const { groupId, expenseId } = req.params;

    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const expenseIndex = group.expenses.findIndex(e => e._id.toString() === expenseId);
    if (expenseIndex === -1) return res.status(404).json({ error: 'Expense not found' });

    group.expenses.splice(expenseIndex, 1);
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
  } catch (error) {
    console.error('Error deleting expense from group:', error);
    res.status(500).json({ error: error.message });
  }
};

// Settle expense splits in group (for admin)
const settleExpenseSplitsInGroup = async (req, res) => {
  try {
    const { groupId, expenseId } = req.params;
    const { memberEmails } = req.body;

    const group = await GroupTransaction.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const expense = group.expenses.id(expenseId);
    if (!expense) return res.status(404).json({ error: 'Expense not found' });

    let settledCount = 0;
    let alreadySettledCount = 0;
    let alreadySettledMembers = [];

    for (let splitItem of expense.split) {
      const member = await User.findById(splitItem.user);
      if (member && memberEmails.includes(member.email)) {
        if (splitItem.settled) {
          alreadySettledCount++;
          alreadySettledMembers.push(member.email);
          continue;
        }
        splitItem.settled = true;
        splitItem.settledAt = new Date();
        splitItem.settledBy = req.user.email; // Admin's email
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
  } catch (error) {
    console.error('Error settling expense splits in group:', error);
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
  register,
  getAllUsers,
  getUserDetails,
  updateUserStatus,
  updateUser,
  deleteUser,
  getSystemSettings,
  updateSystemSettings,
  getAnalyticsSettings,
  updateAnalyticsSettings,
  getSecuritySettings,
  updateSecuritySettings,
  getNotificationSettings,
  updateNotificationSettings,
  getAllAdmins,
  addAdmin,
  removeAdmin,
  getAllTransactions,
  updateTransaction,
  deleteTransaction,
  getAllGroupTransactions,
  updateGroupTransaction,
  deleteGroupTransaction,
  addMemberToGroup,
  removeMemberFromGroup,
  addExpenseToGroup,
  updateExpenseInGroup,
  deleteExpenseFromGroup,
  settleExpenseSplitsInGroup,
};