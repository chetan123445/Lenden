const Activity = require('../models/activity');
const User = require('../models/user');

const createActivityLog = async (userId, type, title, description, metadata = {}) => {
  try {
    const activity = await Activity.create({
      user: userId,
      type,
      title,
      description,
      metadata,
    });
    return activity;
  } catch (error) {
    console.error('Error creating activity log:', error);
    return null;
  }
};

exports.logFriendActivity = async (userId, type, metadata = {}) => {
  let title = 'Friend Activity';
  let description = 'Friend activity update';

  switch (type) {
    case 'friend_request_sent':
      title = 'Friend Request Sent';
      description = `You sent a friend request to ${metadata.to ?? ''}`.trim();
      break;
    case 'friend_request_received':
      title = 'Friend Request Received';
      description = `You received a friend request from ${metadata.from ?? ''}`.trim();
      break;
    case 'friend_request_accepted':
      title = 'Friend Request Accepted';
      description = metadata.with
        ? `${metadata.with} accepted your request`
        : 'Friend request accepted';
      break;
    case 'friend_request_declined':
      title = 'Friend Request Declined';
      description = metadata.with
        ? `${metadata.with} declined your request`
        : 'Friend request declined';
      break;
    case 'friend_request_canceled':
      title = 'Friend Request Canceled';
      description = metadata.with
        ? `${metadata.with} canceled the request`
        : 'Friend request canceled';
      break;
    case 'friend_removed':
      title = 'Friend Removed';
      description = metadata.with
        ? `Friend removed: ${metadata.with}`
        : 'Friend removed';
      break;
    case 'user_blocked':
      title = 'User Blocked';
      description = metadata.by
        ? `You were blocked by ${metadata.by}`
        : 'User blocked';
      break;
    case 'user_unblocked':
      title = 'User Unblocked';
      description = metadata.by
        ? `You were unblocked by ${metadata.by}`
        : 'User unblocked';
      break;
  }

  return await createActivityLog(userId, type, title, description, metadata);
};

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
