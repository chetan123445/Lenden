const mongoose = require('mongoose');

const adminSchema = new mongoose.Schema({
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
  profileImage: { type: Buffer }, // Store image as binary
}, { timestamps: true });

adminSchema.index({ email: 1 });
adminSchema.index({ username: 1 });
adminSchema.index({ phone: 1 });

adminSchema.statics.createDefaultAdmin = async function() {
  const Admin = this;
  const username = process.env.DEFAULT_ADMIN_USERNAME;
  const email = process.env.DEFAULT_ADMIN_EMAIL;
  const password = process.env.DEFAULT_ADMIN_PASSWORD;
  const name = process.env.DEFAULT_ADMIN_NAME;
  const gender = process.env.DEFAULT_ADMIN_GENDER;
  if (!username || !email || !password || !name || !gender) {
    console.warn('Default admin credentials not set in .env');
    return;
  }
  const exists = await Admin.findOne({ username });
  if (!exists) {
    const bcrypt = require('bcrypt');
    const hashedPassword = await bcrypt.hash(password, 10);
    await Admin.create({
      name,
      username,
      password: hashedPassword,
      email,
      gender,
    });
  }
};

module.exports = mongoose.model('Admin', adminSchema); 