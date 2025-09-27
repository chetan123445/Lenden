const User = require('../models/user');
const Admin = require('../models/admin');
const bcrypt = require('bcrypt');
const { sendRegistrationOTP } = require('../utils/registrationemailotp');
const { sendLoginOTP } = require('../utils/loginsendotp');
const { sendLoginNotificationEmail } = require('../utils/loginNotificationEmail');
const jwt = require('jsonwebtoken');
const { logProfileActivity } = require('./activityController');
const { v4: uuidv4 } = require('uuid');

// In-memory OTP store (for demo; use DB or cache in production)
const otpStore = {};
const OTP_EXPIRY_MS = 2 * 60 * 1000; // 2 minutes

function isPasswordValid(password) {
  const lengthValid = password.length >= 8 && password.length <= 30;
  const hasUpper = /[A-Z]/.test(password);
  const hasLower = /[a-z]/.test(password);
  const hasSpecial = /[^A-Za-z0-9]/.test(password);
  return lengthValid && hasUpper && hasLower && hasSpecial;
}

// Register user with OTP
exports.register = async (req, res) => {
  try {
  let { name, username, email, password, gender } = req.body;
    email = email.trim().toLowerCase();
    if (!name || !username || !email || !password || !gender || !['Male', 'Female', 'Other'].includes(gender)) {
      return res.status(400).json({ error: 'All fields including gender are required and must be valid.' });
    }
    
  // Rating validation removed
    
    // Check if user/email/username exists in users or admins
    const userExists = await User.findOne({ $or: [{ username }, { email }] });
    const adminExists = await Admin.findOne({ $or: [{ username }, { email }] });
    if (userExists || adminExists) {
      return res.status(400).json({ error: 'Username or email already exists' });
    }
    // Password constraints
    if (!isPasswordValid(password)) {
      return res.status(400).json({ error: 'Password must be 8-30 characters, include uppercase, lowercase, and special character.' });
    }
    // Generate OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
  otpStore[email] = { otp, data: { name, username, password, email, gender }, created: Date.now() };
    await sendRegistrationOTP(email, otp);
    res.status(200).json({ message: 'OTP sent to email' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// Resend OTP
exports.resendOtp = async (req, res) => {
  try {
    const { email } = req.body;
    const entry = otpStore[email];
    if (!entry) {
      return res.status(400).json({ error: 'No registration in progress for this email.' });
    }
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    otpStore[email].otp = otp;
    otpStore[email].created = Date.now();
    await sendRegistrationOTP(email, otp);
    res.status(200).json({ message: 'New OTP sent to email' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// Verify OTP and complete registration
exports.verifyOtp = async (req, res) => {
  try {
    const { email, otp } = req.body;
    const entry = otpStore[email];
    if (!entry) {
      return res.status(400).json({ error: 'No OTP found for this email' });
    }
    const now = Date.now();
    if (now - entry.created > OTP_EXPIRY_MS) {
      delete otpStore[email];
      return res.status(400).json({ error: 'OTP expired. Please request a new OTP.' });
    }
    if (entry.otp !== otp) {
      return res.status(400).json({ error: 'Invalid OTP' });
    }
    // Register user
  const { name, username, password, gender } = entry.data;
    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = new User({
      name,
      username,
      email,
      password: hashedPassword,
      gender,
      memberSince: new Date(), // Set member since date
    });
    await newUser.save();
    delete otpStore[email];
    res.status(201).json({ message: 'User registered successfully' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// Login user or admin
exports.login = async (req, res) => {
  try {
    let { username, password } = req.body;
    console.log('🔐 Login attempt for username/email:', username);
    console.log('📝 Request body:', req.body);
    
    if (username && username.includes('@')) username = username.trim().toLowerCase();
    console.log('🔍 Searching for user or admin with username or email:', username);
    
    // Search in both User and Admin tables
    const user = await User.findOne({ $or: [{ username }, { email: username }] });
    const admin = await Admin.findOne({ $or: [{ username }, { email: username }] });
    
    console.log('👤 User found:', !!user);
    console.log('👨‍💼 Admin found:', !!admin);
    
    if (user) {
      console.log('👤 User details:', { id: user._id, username: user.username, email: user.email });
    }
    if (admin) {
      console.log('👨‍💼 Admin details:', { id: admin._id, username: admin.username, email: admin.email });
    }
    
    if (!user && !admin) {
      console.log('❌ User/Admin not found for:', username);
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Check if it's a user
    if (user) {
      console.log('🔑 Comparing passwords for user...');
      console.log('🔑 Input password length:', password.length);
      console.log('🔑 Stored password hash length:', user.password.length);
      const match = await bcrypt.compare(password, user.password);
      console.log('🔑 Password match:', match);
      
      if (!match) {
        console.log('❌ Incorrect password for user:', username);
        return res.status(401).json({ error: 'Incorrect password' });
      }
      
      // Generate JWT for user
      const jwtSecret = process.env.JWT_SECRET || 'fallback-secret-key-for-development';
      // Generate a deviceId for this session
      const deviceId = req.body.deviceId || uuidv4();
      const token = jwt.sign(
        { _id: user._id, email: user.email, role: 'user', deviceId },
        jwtSecret,
        { expiresIn: '7d' }
      );
      console.log('✅ Login successful for user:', username);
      console.log('🎫 Token generated successfully');
      
      // Log login activity
      try {
        await logProfileActivity(user._id, 'login', {
          ipAddress: req.ip,
          userAgent: req.get('User-Agent')
        });
      } catch (e) {
        console.error('Failed to log login activity:', e);
      }

      // Send login notification email if enabled
      if (user.loginNotifications !== false) { // default true if undefined
        try {
          await sendLoginNotificationEmail({
            to: user.email,
            name: user.name,
            ipAddress: req.ip,
            userAgent: req.get('User-Agent'),
            loginTime: new Date()
          });
        } catch (e) {
          console.error('Failed to send login notification email:', e);
        }
      }

      // Device management: enforce single-device login if needed
      if (user.deviceManagement === false) {
        // Remove all other devices
        user.devices = [];
      }
      // Add/update this device
      const userAgent = req.get('User-Agent');
      const ipAddress = req.ip;
      const now = new Date();
      // Remove any existing entry for this deviceId
      user.devices = user.devices.filter(d => d.deviceId !== deviceId);
      user.devices.push({
        deviceId,
        userAgent,
        ipAddress,
        lastActive: now,
        createdAt: now
      });
      await user.save();

      res.json({ message: 'Login successful', user, token, deviceId });
      return;
    }
    
    // Check if it's an admin
    if (admin) {
      console.log('🔑 Comparing passwords for admin...');
      console.log('🔑 Input password length:', password.length);
      console.log('🔑 Stored password hash length:', admin.password.length);
      const match = await bcrypt.compare(password, admin.password);
      console.log('🔑 Password match:', match);
      
      if (!match) {
        console.log('❌ Incorrect password for admin:', username);
        return res.status(401).json({ error: 'Incorrect password' });
      }
      
      // Generate JWT for admin
      const jwtSecret = process.env.JWT_SECRET || 'fallback-secret-key-for-development';
      const token = jwt.sign({ _id: admin._id, email: admin.email, role: 'admin' }, jwtSecret, { expiresIn: '7d' });
      console.log('✅ Login successful for admin:', username);
      console.log('🎫 Token generated successfully');
      
      res.json({ message: 'Login successful', admin, token });
      return;
    }
    
  } catch (err) {
    console.error('❌ Login error:', err.message);
    console.error('❌ Full error:', err);
    res.status(500).json({ error: err.message });
  }
};

// Check if username is unique across users and admins
exports.checkUsername = async (req, res) => {
  try {
    const { username } = req.body;
    console.log('Checking username:', username);
    const userExists = await User.findOne({ username });
    const adminExists = await Admin.findOne({ username });
    console.log('User exists:', !!userExists, 'Admin exists:', !!adminExists);
    if (userExists || adminExists) {
      return res.status(200).json({ unique: false });
    }
    return res.status(200).json({ unique: true });
  } catch (err) {
    res.status(500).json({ unique: false, error: err.message });
  }
};

// Check if email is unique across users and admins
exports.checkEmail = async (req, res) => {
  try {
    let { email } = req.body;
    email = email.trim().toLowerCase();
    console.log('Checking email:', email);
    const userExists = await User.findOne({ email });
    console.log('User exists:', !!userExists);
    if (userExists) {
      return res.status(200).json({ unique: false });
    }
    return res.status(200).json({ unique: true });
  } catch (err) {
    res.status(500).json({ unique: false, error: err.message });
  }
};

// Debug endpoint to list all users (for testing)
exports.listUsers = async (req, res) => {
  try {
    const users = await User.find({}).select('username email name');
    console.log('📋 All users in database:', users);
    res.json({ users });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Send OTP for login (checks both admin and user tables)
exports.sendLoginOtp = async (req, res) => {
  try {
    const { email } = req.body;
    console.log('🔍 Looking for user with email:', email);
    
    let userType = null;
    let name = null;
    const user = await User.findOne({ email });
    const admin = await Admin.findOne({ email });
    
    console.log('👤 User found:', !!user);
    console.log('👨‍💼 Admin found:', !!admin);
    
    if (user) {
      userType = 'user';
      name = user.name;
      console.log('✅ User found, sending OTP to:', email);
    } else if (admin) {
      userType = 'admin';
      name = admin.name;
      console.log('✅ Admin found, sending OTP to:', email);
    } else {
      console.log('❌ No user or admin found with email:', email);
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Generate OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    otpStore[email] = { otp, userType, created: Date.now() };
    
    console.log('📧 Sending OTP email to:', email);
    await sendLoginOTP(email, otp);
    console.log('✅ OTP sent successfully');
    
    res.status(200).json({ message: 'OTP sent to email', userType, name });
  } catch (err) {
    console.error('❌ Error in sendLoginOtp:', err.message);
    res.status(400).json({ error: err.message });
  }
};

// Verify OTP for login
exports.verifyLoginOtp = async (req, res) => {
  try {
    const { email, otp } = req.body;
    console.log('🔐 OTP verification attempt for email:', email);
    console.log('🔐 OTP provided:', otp);
    
    const entry = otpStore[email];
    if (!entry) {
      console.log('❌ No OTP found for email:', email);
      return res.status(400).json({ error: 'No OTP found for this email' });
    }
    
    const now = Date.now();
    if (now - entry.created > OTP_EXPIRY_MS) {
      console.log('❌ OTP expired for email:', email);
      delete otpStore[email];
      return res.status(400).json({ error: 'OTP expired. Please request a new OTP.' });
    }
    
    if (entry.otp !== otp) {
      console.log('❌ Invalid OTP for email:', email);
      return res.status(400).json({ error: 'Invalid OTP' });
    }
    
    console.log('✅ OTP verified successfully for email:', email);
    console.log('👤 User type from OTP store:', entry.userType);
    
    // Find user or admin
    let user = null;
    let admin = null;
    if (entry.userType === 'user') {
      user = await User.findOne({ email });
      if (!user) {
        console.log('❌ User not found in database for email:', email);
        return res.status(404).json({ error: 'User not found' });
      }
      
      console.log('✅ User found in database:', { id: user._id, name: user.name, email: user.email });
      
      // Generate JWT token for user
      const jwtSecret = process.env.JWT_SECRET || 'fallback-secret-key-for-development';
      const token = jwt.sign({ _id: user._id, email: user.email, role: 'user' }, jwtSecret, { expiresIn: '7d' });
      console.log('✅ OTP login successful for user:', email);
      console.log('🎫 User token generated successfully');
      console.log('🎫 Token length:', token.length);
      
      delete otpStore[email];
      return res.status(200).json({ message: 'Login successful', userType: 'user', user, token });
    } else if (entry.userType === 'admin') {
      admin = await Admin.findOne({ email });
      if (!admin) {
        console.log('❌ Admin not found in database for email:', email);
        return res.status(404).json({ error: 'User not found' });
      }
      
      console.log('✅ Admin found in database:', { id: admin._id, name: admin.name, email: admin.email });
      
      // Generate JWT token for admin
      const jwtSecret = process.env.JWT_SECRET || 'fallback-secret-key-for-development';
      const token = jwt.sign({ _id: admin._id, email: admin.email, role: 'admin' }, jwtSecret, { expiresIn: '7d' });
      console.log('✅ OTP login successful for admin:', email);
      console.log('🎫 Admin token generated successfully');
      console.log('🎫 Token length:', token.length);
      
      delete otpStore[email];
      return res.status(200).json({ message: 'Login successful', userType: 'admin', admin, token });
    }
    
    console.log('❌ Unknown user type:', entry.userType);
    return res.status(404).json({ error: 'User not found' });
  } catch (err) {
    console.error('❌ Error in verifyLoginOtp:', err);
    res.status(400).json({ error: err.message });
  }
};

// List active devices for the current user
exports.listDevices = async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select('devices');
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({ devices: user.devices || [] });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
};

// Logout a specific device
exports.logoutDevice = async (req, res) => {
  try {
    const { deviceId } = req.body;
    if (!deviceId) return res.status(400).json({ error: 'deviceId required' });
    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ error: 'User not found' });
    user.devices = (user.devices || []).filter(d => d.deviceId !== deviceId);
    await user.save();
    res.json({ message: 'Device logged out successfully' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
};