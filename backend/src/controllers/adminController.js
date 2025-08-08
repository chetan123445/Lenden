const User = require('../models/user');
const Admin = require('../models/admin');
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
    const admins = await Admin.find({}, '-password');
    res.json({
      success: true,
      admins
    });
  } catch (error) {
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
};