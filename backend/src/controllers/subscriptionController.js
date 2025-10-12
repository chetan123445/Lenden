const User = require('../models/user');

exports.updateSubscription = async (req, res) => {
  try {
    const { userId, isSubscribed } = req.body;

    if (typeof isSubscribed !== 'boolean') {
      return res.status(400).json({ error: 'isSubscribed must be a boolean' });
    }

    const user = await User.findById(userId);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    user.subscription = isSubscribed ? 'premium' : 'free';
    await user.save();

    res.status(200).json({ message: 'Subscription updated successfully', user });
  } catch (error) {
    res.status(500).json({ error: 'An error occurred while updating subscription' });
  }
};