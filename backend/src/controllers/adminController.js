const Admin = require('../models/admin');
const User = require('../models/user');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

// Register admin with uniqueness check
exports.register = async (req, res) => {
  try {
    let { name, username, email, password, gender } = req.body;
    email = email.trim().toLowerCase();
    if (!name || !username || !email || !password || !gender || !['Male', 'Female', 'Other'].includes(gender)) {
      return res.status(400).json({ error: 'All fields including gender are required and must be valid.' });
    }
    // Check if admin/email/username exists in admins or users
    const adminExists = await Admin.findOne({ $or: [{ username }, { email }] });
    const userExists = await User.findOne({ $or: [{ username }, { email }] });
    if (adminExists || userExists) {
      return res.status(400).json({ error: 'Username or email already exists' });
    }
    const hashedPassword = await bcrypt.hash(password, 10);
    const newAdmin = new Admin({
      name,
      username,
      email,
      password: hashedPassword,
      gender,
    });
    await newAdmin.save();
    res.status(201).json({ message: 'Admin registered successfully' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// Login admin
exports.login = async (req, res) => {
  try {
    let { username, password } = req.body;
    console.log('🔐 Admin login attempt for username/email:', username);
    console.log('📝 Admin request body:', req.body);
    
    if (username && username.includes('@')) username = username.trim().toLowerCase();
    console.log('🔍 Searching for admin with username or email:', username);
    
    const admin = await Admin.findOne({ $or: [{ username }, { email: username }] });
    console.log('👤 Admin found:', !!admin);
    if (admin) {
      console.log('👤 Admin details:', { id: admin._id, username: admin.username, email: admin.email });
    }
    
    if (!admin) {
      console.log('❌ Admin not found for:', username);
      return res.status(404).json({ error: 'User not found' });
    }
    
    console.log('🔑 Comparing admin passwords...');
    const match = await bcrypt.compare(password, admin.password);
    console.log('🔑 Admin password match:', match);
    
    if (!match) {
      console.log('❌ Incorrect password for admin:', username);
      return res.status(401).json({ error: 'Incorrect password' });
    }
    
    // Generate JWT
    const token = jwt.sign({ id: admin._id, email: admin.email, role: 'admin' }, process.env.JWT_SECRET, { expiresIn: '7d' });
    console.log('✅ Admin login successful for:', username);
    console.log('🎫 Admin token generated successfully');
    res.json({ message: 'Login successful', admin, token });
  } catch (err) {
    console.error('❌ Admin login error:', err.message);
    console.error('❌ Full admin error:', err);
    res.status(500).json({ error: err.message });
  }
}; 