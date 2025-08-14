// GET /api/ratings/user-avg?usernameOrEmail=... - Get avg rating for any user by username or email
exports.getUserAvgRating = async (req, res) => {
  try {
    const { usernameOrEmail } = req.query;
    if (!usernameOrEmail) {
      return res.status(400).json({ error: 'Username or email is required.' });
    }
    const user = await User.findOne({
      $or: [
        { username: usernameOrEmail },
        { email: usernameOrEmail }
      ]
    });
    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }
    return res.json({
      username: user.username,
      name: user.name,
      email: user.email,
      avgRating: user.avgRating || 0
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
const Rating = require('../models/rating');
const User = require('../models/user');

// POST /api/ratings - Rate a user
exports.rateUser = async (req, res) => {
  try {
    const raterId = req.user._id;
    const { usernameOrEmail, rating } = req.body;
    if (!usernameOrEmail || !rating) {
      return res.status(400).json({ error: 'Username/email and rating are required.' });
    }
    // Find user by username or email
    const ratee = await User.findOne({
      $or: [
        { username: usernameOrEmail },
        { email: usernameOrEmail }
      ]
    });
    if (!ratee) {
      return res.status(404).json({ error: 'User not found.' });
    }
    if (ratee._id.equals(raterId)) {
      return res.status(400).json({ error: 'You cannot rate yourself.' });
    }
    // Only allow one rating per rater-ratee
    let ratingDoc = await Rating.findOne({ rater: raterId, ratee: ratee._id });
    if (ratingDoc) {
      return res.status(400).json({ error: 'You have already rated this user.' });
    }
    ratingDoc = new Rating({ rater: raterId, ratee: ratee._id, rating });
    await ratingDoc.save();
    // Update avgRating for the ratee
    const ratings = await Rating.find({ ratee: ratee._id });
    const avg = ratings.reduce((sum, r) => sum + r.rating, 0) / ratings.length;
    ratee.avgRating = avg;
    await ratee.save();
    res.status(201).json({ message: 'Rating submitted.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /api/ratings/me - Get my ratings and avg
exports.getMyRatings = async (req, res) => {
  try {
    const userId = req.user._id;
    const user = await User.findById(userId);
    // Ratings received
    const received = await Rating.find({ ratee: userId }).populate('rater', 'username name');
    // Ratings given
    const given = await Rating.find({ rater: userId }).populate('ratee', 'username name');
    res.json({
      avgRating: user.avgRating || 0,
      ratingsReceived: received.map(r => ({
        rater: r.rater._id,
        raterName: r.rater.name || r.rater.username,
        rating: r.rating,
        comment: r.comment,
        createdAt: r.createdAt
      })),
      ratingsGiven: given.map(r => ({
        ratee: r.ratee._id,
        rateeName: r.ratee.name || r.ratee.username,
        rating: r.rating,
        comment: r.comment,
        createdAt: r.createdAt
      }))
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
