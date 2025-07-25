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
  profileImage: { type: Buffer }, // Store image as binary
}, { timestamps: true });

userSchema.index({ email: 1 });
userSchema.index({ username: 1 });
userSchema.index({ phone: 1 });

module.exports = mongoose.model('User', userSchema); 