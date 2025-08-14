const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  username: { type: String, required: true, unique: true },
  password: { type: String, required: true }, // Will be hashed
  email: {
    type: String,
    required: true,
    unique: true,
  },
  gender: {
    type: String,
    enum: ['Male', 'Female', 'Other'],
    required: true,
  },
  birthday: { type: Date },
  address: { type: String },
  phone: { type: String },
  altEmail: { type: String },
  altEmailOTP: {
    code: { type: String },
    email: { type: String },
    expiry: { type: Date }
  },
  memberSince: { type: Date, default: Date.now },
  avgRating: {
    type: Number,
    min: 0,
    max: 5,
    default: 0
  },
  profileImage: { type: Buffer }, // Store image as binary
  role: { type: String, enum: ['user', 'admin'], default: 'user' },
  isActive: { type: Boolean, default: true },
  isVerified: { type: Boolean, default: false },
  
  // Notification Settings
  notificationSettings: {
    transactionNotifications: { type: Boolean, default: true },
    paymentReminders: { type: Boolean, default: true },
    chatNotifications: { type: Boolean, default: true },
    groupNotifications: { type: Boolean, default: true },
    emailNotifications: { type: Boolean, default: true },
    pushNotifications: { type: Boolean, default: true },
    smsNotifications: { type: Boolean, default: false },
    reminderFrequency: { type: String, enum: ['daily', 'weekly', 'monthly'], default: 'daily' },
    quietHoursStart: { type: String, default: '22:00' },
    quietHoursEnd: { type: String, default: '08:00' },
    quietHoursEnabled: { type: Boolean, default: false },
  },
  
  // Privacy Settings
  privacySettings: {
    profileVisibility: { type: Boolean, default: true },
    transactionHistory: { type: Boolean, default: true },
    contactSharing: { type: Boolean, default: false },
    analyticsSharing: { type: Boolean, default: true },
    marketingEmails: { type: Boolean, default: false },
    dataCollection: { type: Boolean, default: true },
    twoFactorAuth: { type: Boolean, default: false },
    loginNotifications: { type: Boolean, default: true },
    deviceManagement: { type: Boolean, default: true },
    sessionTimeout: { type: Number, default: 30 }, // minutes
  },
}, { timestamps: true });

userSchema.index({ email: 1 });
userSchema.index({ username: 1 });
userSchema.index({ phone: 1 });

module.exports = mongoose.model('User', userSchema); 