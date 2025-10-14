const Subscription = require('../models/subscription');
const User = require('../models/user');
const mongoose = require('mongoose');

// Update or create a subscription
exports.updateSubscription = async (req, res) => {
    const { subscriptionPlan, duration } = req.body; // duration in months
    const userId = req.user._id;

    try {
        let subscription = await Subscription.findOne({ user: userId });

        const subscribedDate = new Date();
        const endDate = new Date(subscribedDate);
        endDate.setMonth(endDate.getMonth() + duration);

        if (subscription) {
            // Update existing subscription
            subscription.subscribed = true;
            subscription.subscriptionPlan = subscriptionPlan;
            subscription.subscribedDate = subscribedDate;
            subscription.endDate = endDate;
            await subscription.save();
        } else {
            // Create new subscription
            subscription = new Subscription({
                user: userId,
                subscribed: true,
                subscriptionPlan,
                subscribedDate,
                endDate
            });
            await subscription.save();
        }

        res.status(200).json({ message: 'Subscription updated successfully', subscription });
    } catch (error) {
        res.status(500).json({ message: 'Error updating subscription', error: error.message });
    }
};

// Get subscription status for the logged-in user
exports.getSubscriptionStatus = async (req, res) => {
    try {
        console.log('Fetching subscription status for user:', req.user._id);
        const subscription = await Subscription.findOne({ user: req.user._id });
        console.log('Found subscription:', subscription);

        if (subscription && subscription.subscribed && subscription.endDate >= new Date()) {
            res.status(200).json({
                subscribed: true,
                subscriptionPlan: subscription.subscriptionPlan,
                subscribedDate: subscription.subscribedDate,
                endDate: subscription.endDate
            });
        } else {
            res.status(200).json({ subscribed: false });
        }
    } catch (error) {
        console.error('Error fetching subscription status:', error);
        res.status(500).json({ message: 'Error fetching subscription status', error: error.message });
    }
};
