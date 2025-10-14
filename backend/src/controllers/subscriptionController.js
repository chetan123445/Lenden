const Subscription = require('../models/subscription');
const User = require('../models/user');
const mongoose = require('mongoose');

// Update or create a subscription
exports.updateSubscription = async (req, res) => {
    const { subscriptionPlan, duration, price, discount } = req.body; // duration in months
    const userId = req.user._id;

    try {
        // Expire all existing subscriptions for the user
        await Subscription.updateMany({ user: userId }, { $set: { status: 'expired' } });

        const subscribedDate = new Date();
        const endDate = new Date(subscribedDate);
        endDate.setMonth(endDate.getMonth() + duration);

        const actualPrice = price - (price * (discount / 100));

        // Create new subscription
        const subscription = new Subscription({
            user: userId,
            subscribed: true,
            subscriptionPlan,
            duration,
            price,
            discount,
            actualPrice,
            subscribedDate,
            endDate,
            status: 'active'
        });
        await subscription.save();

        res.status(200).json({ message: 'Subscription updated successfully', subscription });
    } catch (error) {
        res.status(500).json({ message: 'Error updating subscription', error: error.message });
    }
};

// Get subscription status for the logged-in user
exports.getSubscriptionStatus = async (req, res) => {
    try {
        console.log('Fetching subscription status for user:', req.user._id);
        const subscription = await Subscription.findOne({ user: req.user._id, status: 'active' }).sort({ subscribedDate: -1 });
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

// Get subscription history for the logged-in user
exports.getSubscriptionHistory = async (req, res) => {
    try {
        const subscriptions = await Subscription.find({ user: req.user._id }).sort({ subscribedDate: -1 });
        res.status(200).json(subscriptions);
    } catch (error) {
        res.status(500).json({ message: 'Error fetching subscription history', error: error.message });
    }
};
