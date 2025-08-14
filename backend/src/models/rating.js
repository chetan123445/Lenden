const mongoose = require('mongoose');

const ratingSchema = new mongoose.Schema({
  rater: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }, // Who gave the rating
  ratee: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }, // Who is being rated
  rating: { type: Number, min: 1, max: 5, required: true },
  comment: { type: String },
  createdAt: { type: Date, default: Date.now },
}, { timestamps: true });

ratingSchema.index({ rater: 1, ratee: 1 }, { unique: true }); // Only one rating per rater-ratee pair

module.exports = mongoose.model('Rating', ratingSchema);
