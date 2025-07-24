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
    if (username && username.includes('@')) username = username.trim().toLowerCase();
    const admin = await Admin.findOne({ $or: [{ username }, { email: username }] });
    if (!admin) return res.status(404).json({ error: 'User not found' });
    const match = await bcrypt.compare(password, admin.password);
    if (!match) return res.status(401).json({ error: 'Incorrect password' });
    // Generate JWT
    const token = jwt.sign({ id: admin._id, role: 'admin' }, process.env.JWT_SECRET, { expiresIn: '7d' });
    res.json({ message: 'Login successful', admin, token });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}; 