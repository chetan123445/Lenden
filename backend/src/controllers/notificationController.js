const Notification = require('../models/notification');
const User = require('../models/user');
const Admin = require('../models/admin');

exports.createNotification = async (req, res) => {
  try {
    const { message, recipientType, recipients } = req.body;
    console.log('req.user:', req.user);
    console.log('req.user._id:', req.user ? req.user._id : 'undefined');
    const sender = req.user._id;

    let recipientIds = [];
    let recipientModel;
    let invalidRecipients = [];

    if (recipientType === 'all-users') {
      const users = await User.find({}, '_id');
      recipientIds = users.map((user) => user._id);
      recipientModel = 'User';
    } else if (recipientType === 'all-admins') {
      const admins = await Admin.find({}, '_id');
      recipientIds = admins.map((admin) => admin._id);
      recipientModel = 'Admin';
    } else if (recipientType === 'specific-users') {
      const users = await User.find({ $or: [{ username: { $in: recipients } }, { email: { $in: recipients } }] }, 'username email _id'); // Fetch username/email to identify invalid ones
      recipientIds = users.map((user) => user._id);
      recipientModel = 'User';

      const foundUsernames = users.map(user => user.username);
      const foundEmails = users.map(user => user.email);

      invalidRecipients = recipients.filter(rec => 
        !foundUsernames.includes(rec) && !foundEmails.includes(rec)
      );

    } else if (recipientType === 'specific-admins') {
        const admins = await Admin.find({ $or: [{ username: { $in: recipients } }, { email: { $in: recipients } }] }, 'username email _id'); // Fetch username/email to identify invalid ones
        recipientIds = admins.map((admin) => admin._id);
        recipientModel = 'Admin';

        const foundAdminUsernames = admins.map(admin => admin.username);
        const foundAdminEmails = admins.map(admin => admin.email);

        invalidRecipients = recipients.filter(rec => 
            !foundAdminUsernames.includes(rec) && !foundAdminEmails.includes(rec)
        );
    }

    // Check for invalid recipients before proceeding
    if (invalidRecipients.length > 0) {
        return res.status(400).json({ message: `The following recipients were not found: ${invalidRecipients.join(', ')}` });
    }

    // If specific users/admins were selected but no valid recipients were found
    if ((recipientType === 'specific-users' || recipientType === 'specific-admins') && recipientIds.length === 0 && recipients.length > 0) {
        return res.status(400).json({ message: 'No valid recipients found for the specified type among the provided list.' });
    }


    const notification = new Notification({
      sender,
      recipientType,
      recipients: recipientIds,
      recipientModel,
      message,
    });

    await notification.save();

    res.status(201).json({ message: 'Notification sent successfully' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getNotifications = async (req, res) => {
    try {
        const { viewAll } = req.query;
        const userId = req.user._id;
        const userRole = req.user.role;

        let query;

        if (userRole === 'user') {
            // Final attempt: Using $in for a more explicit array match.
            query = Notification.find({
                recipientModel: 'User',
                recipients: { $in: [userId] }, 
            })
            .populate({
                path: 'recipients',
                select: 'username email',
            })
            .populate('readBy', 'username email')
            .sort({ createdAt: -1 });
        } else if (userRole === 'admin') {
            query = Notification.find({
                $or: [
                    { recipientType: 'all-admins', recipientModel: 'Admin' },
                    { recipientType: 'specific-admins', recipientModel: 'Admin', recipients: userId },
                    { sender: userId } 
                ],
            })
            .populate({
                path: 'recipients',
                select: 'username email',
            })
            .populate('readBy', 'username email')
            .sort({ createdAt: -1 });
        }

        if (viewAll !== 'true') {
            query = query.limit(3);
        }

        const notifications = await query;
        res.json(notifications);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};


exports.getSentNotifications = async (req, res) => {
  try {
    const { viewAll } = req.query;

    let query = Notification.find({ sender: req.user._id })
      .populate({
        path: 'recipients',
        select: 'username email',
      })
      .sort({ createdAt: -1 });

    if (viewAll !== 'true') {
      query = query.limit(3);
    }

    const notifications = await query;
    res.json(notifications);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getNotificationById = async (req, res) => {
  try {
    const notificationId = req.params.id;
    const notification = await Notification.findById(notificationId)
      .populate({
        path: 'recipients',
        select: 'username email',
      });

    if (!notification) {
      return res.status(404).json({ message: 'Notification not found' });
    }

    res.status(200).json(notification);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.deleteNotification = async (req, res) => {
  try {
    const notificationId = req.params.id;
    const userId = req.user._id; // Authenticated user's ID

    const notification = await Notification.findById(notificationId);

    if (!notification) {
      return res.status(404).json({ message: 'Notification not found' });
    }

    // Check if the authenticated user is the sender of the notification
    if (notification.sender.toString() !== userId.toString()) {
      return res.status(403).json({ message: 'Unauthorized: You can only delete your own notifications' });
    }

    await notification.deleteOne(); // Use deleteOne() for Mongoose 6+

    res.status(200).json({ message: 'Notification deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.updateNotification = async (req, res) => {
  try {
    const notificationId = req.params.id;
    const userId = req.user._id; // Authenticated user's ID
    const { message, recipientType, recipients } = req.body;

    const notification = await Notification.findById(notificationId);

    if (!notification) {
      return res.status(404).json({ message: 'Notification not found' });
    }

    // Check if the authenticated user is the sender of the notification
    if (notification.sender.toString() !== userId.toString()) {
      return res.status(403).json({ message: 'Unauthorized: You can only edit your own notifications' });
    }

    // Update fields
    notification.message = message || notification.message;
    notification.recipientType = recipientType || notification.recipientType;

    // Handle recipients update if provided
    if (recipients) {
      let recipientIds = [];
      let recipientModel;
      let invalidRecipients = []; // Added for validation

      if (recipientType === 'all-users') {
        const users = await User.find({}, '_id');
        recipientIds = users.map((user) => user._id);
        recipientModel = 'User';
      } else if (recipientType === 'all-admins') {
        const admins = await Admin.find({}, '_id');
        recipientIds = admins.map((admin) => admin._id);
        recipientModel = 'Admin';
      } else if (recipientType === 'specific-users') {
        const users = await User.find({ $or: [{ username: { $in: recipients } }, { email: { $in: recipients } }] }, 'username email _id');
        recipientIds = users.map((user) => user._id);
        recipientModel = 'User';

        const foundUsernames = users.map(user => user.username);
        const foundEmails = users.map(user => user.email);

        invalidRecipients = recipients.filter(rec => 
          !foundUsernames.includes(rec) && !foundEmails.includes(rec)
        );

      } else if (recipientType === 'specific-admins') {
        const admins = await Admin.find({ $or: [{ username: { $in: recipients } }, { email: { $in: recipients } }] }, 'username email _id');
        recipientIds = admins.map((admin) => admin._id);
        recipientModel = 'Admin';

        const foundAdminUsernames = admins.map(admin => admin.username);
        const foundAdminEmails = admins.map(admin => admin.email);

        invalidRecipients = recipients.filter(rec => 
          !foundAdminUsernames.includes(rec) && !foundAdminEmails.includes(rec)
        );
      }

      // Check for invalid recipients before proceeding
      if (invalidRecipients.length > 0) {
          return res.status(400).json({ message: `The following recipients were not found: ${invalidRecipients.join(', ')}` });
      }

      // If specific users/admins were selected but no valid recipients were found
      if ((recipientType === 'specific-users' || recipientType === 'specific-admins') && recipientIds.length === 0 && recipients.length > 0) {
          return res.status(400).json({ message: 'No valid recipients found for the specified type among the provided list.' });
      }

      notification.recipients = recipientIds;
      notification.recipientModel = recipientModel;
    }

    await notification.save();

    res.status(200).json({ message: 'Notification updated successfully', notification });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getUnreadNotificationCount = async (req, res) => {
  try {
    const userId = req.user._id;
    const count = await Notification.countDocuments({
      recipients: userId,
      readBy: { $ne: userId }
    });
    res.json({ count });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.markNotificationsAsRead = async (req, res) => {
  try {
    const userId = req.user._id;
    await Notification.updateMany(
      { recipients: userId, readBy: { $ne: userId } },
      { $addToSet: { readBy: userId } }
    );
    res.status(200).json({ message: 'Notifications marked as read' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
