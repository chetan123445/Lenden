const Rating = require('../models/Apprating');

// POST /api/rating - Submit app rating (one per user)
exports.submitRating = async (req, res) => {
  try {
    const { rating } = req.body;
    const userId = req.user._id;
    // Only allow one rating per user
    const existing = await Rating.findOne({ user: userId });
    if (existing) {
      return res.status(400).json({ message: 'You have already rated the app.' });
    }
    const newRating = new Rating({ user: userId, rating });
    await newRating.save();
    res.json({ message: 'Rating submitted successfully.' });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// GET /api/rating/my - Get my app rating
exports.getMyRating = async (req, res) => {
  try {
    const userId = req.user._id;
    const rating = await Rating.findOne({ user: userId });
    res.json({ rating });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// GET /api/rating/app-ratings - Return average app rating and total ratings count
exports.getAppRatings = async (req, res) => {
  try {
    const ratings = await Rating.find();
    if (!ratings.length) {
      return res.json({ average: 0, count: 0 });
    }
    const total = ratings.reduce((sum, r) => sum + (r.rating || 0), 0);
    const avg = total / ratings.length;
    res.json({ average: Number(avg.toFixed(2)), count: ratings.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
