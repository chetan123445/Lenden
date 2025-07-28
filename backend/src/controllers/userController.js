const User = require('../models/user');
const Admin = require('../models/admin');
const bcrypt = require('bcrypt');
const { sendRegistrationOTP } = require('../utils/registrationemailotp');
const { sendLoginOTP } = require('../utils/loginsendotp');
const jwt = require('jsonwebtoken');

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
    });
    await newUser.save();
    delete otpStore[email];
    res.status(201).json({ message: 'User registered successfully' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// Login user
exports.login = async (req, res) => {
  try {
    let { username, password } = req.body;
    console.log('🔐 Login attempt for username/email:', username);
    
    if (username && username.includes('@')) username = username.trim().toLowerCase();
    const user = await User.findOne({ $or: [{ username }, { email: username }] });
    
    console.log('👤 User found:', !!user);
    
    if (!user) {
      console.log('❌ User not found for:', username);
      return res.status(404).json({ error: 'User not found' });
    }
    
    const match = await bcrypt.compare(password, user.password);
    console.log('🔑 Password match:', match);
    
    if (!match) {
      console.log('❌ Incorrect password for user:', username);
      return res.status(401).json({ error: 'Incorrect password' });
    }
    
    // Generate JWT
    const token = jwt.sign({ _id: user._id, email: user.email, role: 'user' }, process.env.JWT_SECRET, { expiresIn: '7d' });
    console.log('✅ Login successful for user:', username);
    res.json({ message: 'Login successful', user, token });
  } catch (err) {
    console.error('❌ Login error:', err.message);
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
    // Find user or admin
    let user = null;
    let admin = null;
    if (entry.userType === 'user') {
      user = await User.findOne({ email });
      if (!user) return res.status(404).json({ error: 'User not found' });
      delete otpStore[email];
      return res.status(200).json({ message: 'Login successful', userType: 'user', user });
    } else if (entry.userType === 'admin') {
      admin = await Admin.findOne({ email });
      if (!admin) return res.status(404).json({ error: 'User not found' });
      delete otpStore[email];
      return res.status(200).json({ message: 'Login successful', userType: 'admin', admin });
    }
    return res.status(404).json({ error: 'User not found' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
}; 