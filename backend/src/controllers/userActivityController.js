const Activity = require('../models/activity');
const User = require('../models/user');

exports.getUserActivity = async (req, res) => {
  try {
    const { searchTerm } = req.params;

    // Find user by email or username
    const user = await User.findOne({
      $or: [{ email: searchTerm }, { username: searchTerm }],
    });

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Find activities for the user
    const activities = await Activity.find({ user: user._id }).sort({ timestamp: -1 });

    res.status(200).json({ activities });
  } catch (error) {
    res.status(500).json({ error: 'An error occurred while fetching user activities' });
  }
};
