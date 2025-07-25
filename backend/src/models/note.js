const mongoose = require('mongoose');

const noteSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, required: true, refPath: 'role' },
  role: { type: String, enum: ['User', 'Admin'], required: true },
  content: { type: String, required: true },
}, { timestamps: true });

module.exports = mongoose.model('Note', noteSchema); 