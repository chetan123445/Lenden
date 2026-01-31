const User = require('../models/user');
const Subscription = require('../models/subscription');
const Activity = require('../models/activity');

const handleUsage = (featureType) => {
  return async (req, res, next) => {
    try {
      const user = await User.findById(req.user._id);
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      const subscription = await Subscription.findOne({ user: user._id, status: 'active' });

      if (subscription) {
        // Premium user, unlimited usage
        req.user = user;
        return next();
      }

      let usageField;
      let activityType;
      let activityTitle;

      switch (featureType) {
        case 'quickTransaction':
          usageField = 'freeQuickTransactionsRemaining';
          activityType = 'quick_transaction_created';
          activityTitle = 'Quick Transaction Created';
          break;
        case 'userTransaction':
          usageField = 'freeUserTransactionsRemaining';
          activityType = 'transaction_created';
          activityTitle = 'User Transaction Created';
          break;
        case 'group':
          usageField = 'freeGroupsRemaining';
          activityType = 'group_created';
          activityTitle = 'Group Created';
          break;
        default:
          return res.status(400).json({ error: 'Invalid feature type' });
      }

      if (user[usageField] > 0) {
        // Reserve the free credit and only consume it if the request succeeds.
        // Attach a response finish listener to decrement and log on success.
        req.user = user; // attach fresh user to request
        let consumed = false;

        const finishHandler = async () => {
          // Only decrement once and only for successful responses
          if (consumed) return;
          consumed = true;
          try {
            if (res.statusCode && res.statusCode < 400) {
              // Decrement and save
              user[usageField] = Math.max(0, user[usageField] - 1);
              await user.save();

              // Log the activity
              const newActivity = new Activity({
                user: user._id,
                type: activityType,
                title: activityTitle,
                description: `Used one free credit for ${featureType}. ${user[usageField]} remaining.`,
                ipAddress: req.ip,
                userAgent: req.headers['user-agent'],
              });
              await newActivity.save();
            }
          } catch (e) {
            console.error('Error consuming free usage after response:', e);
          } finally {
            // cleanup listener
            res.removeListener('finish', finishHandler);
            res.removeListener('close', finishHandler);
          }
        };

        res.on('finish', finishHandler);
        // Also listen for close in case connection is aborted
        res.on('close', finishHandler);

        next();
      } else {
        return res.status(403).json({
          error: `You have run out of free ${featureType}s. Please upgrade to premium for unlimited usage.`,
        });
      }
    } catch (error) {
      console.error('Error in handleUsage middleware:', error);
      res.status(500).json({ error: 'An error occurred while handling feature usage' });
    }
  };
};

module.exports = handleUsage;
