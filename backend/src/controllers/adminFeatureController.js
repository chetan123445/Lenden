const SubscriptionPlan = require('../models/subscriptionPlan');
const PremiumBenefit = require('../models/premiumBenefit');
const Faq = require('../models/faq');
const Subscription = require('../models/subscription');
const User = require('../models/user');

// Subscription Plan Controllers
exports.createSubscriptionPlan = async (req, res) => {
    try {
        const { name, price, duration, features, offer, discount, free } = req.body;
        const newPlan = new SubscriptionPlan({ name, price, duration, features, offer, discount, free });
        await newPlan.save();
        res.status(201).json({ message: 'Subscription plan created successfully', plan: newPlan });
    } catch (error) {
        res.status(500).json({ message: 'Error creating subscription plan', error: error.message });
    }
};

exports.getSubscriptionPlans = async (req, res) => {
    try {
        const plans = await SubscriptionPlan.find();
        res.status(200).json(plans);
    } catch (error) {
        res.status(500).json({ message: 'Error fetching subscription plans', error: error.message });
    }
};

exports.updateSubscriptionPlan = async (req, res) => {
    try {
        const { id } = req.params;
        const { name, price, duration, features, isAvailable, offer, discount, free } = req.body;
        const updatedPlan = await SubscriptionPlan.findByIdAndUpdate(id, { name, price, duration, features, isAvailable, offer, discount, free }, { new: true });
        if (!updatedPlan) {
            return res.status(404).json({ message: 'Subscription plan not found' });
        }
        res.status(200).json({ message: 'Subscription plan updated successfully', plan: updatedPlan });
    } catch (error) {
        res.status(500).json({ message: 'Error updating subscription plan', error: error.message });
    }
};

exports.deleteSubscriptionPlan = async (req, res) => {
    try {
        const { id } = req.params;
        const deletedPlan = await SubscriptionPlan.findByIdAndDelete(id);
        if (!deletedPlan) {
            return res.status(404).json({ message: 'Subscription plan not found' });
        }
        res.status(200).json({ message: 'Subscription plan deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Error deleting subscription plan', error: error.message });
    }
};

// Premium Benefit Controllers
exports.createPremiumBenefit = async (req, res) => {
    try {
        const { text } = req.body;
        const newBenefit = new PremiumBenefit({ text });
        await newBenefit.save();
        res.status(201).json({ message: 'Premium benefit created successfully', benefit: newBenefit });
    } catch (error) {
        res.status(500).json({ message: 'Error creating premium benefit', error: error.message });
    }
};

exports.getPremiumBenefits = async (req, res) => {
    try {
        const benefits = await PremiumBenefit.find();
        res.status(200).json(benefits);
    } catch (error) {
        res.status(500).json({ message: 'Error fetching premium benefits', error: error.message });
    }
};

exports.updatePremiumBenefit = async (req, res) => {
    try {
        const { id } = req.params;
        const { text } = req.body;
        const updatedBenefit = await PremiumBenefit.findByIdAndUpdate(id, { text }, { new: true });
        if (!updatedBenefit) {
            return res.status(404).json({ message: 'Premium benefit not found' });
        }
        res.status(200).json({ message: 'Premium benefit updated successfully', benefit: updatedBenefit });
    } catch (error) {
        res.status(500).json({ message: 'Error updating premium benefit', error: error.message });
    }
};

exports.deletePremiumBenefit = async (req, res) => {
    try {
        const { id } = req.params;
        const deletedBenefit = await PremiumBenefit.findByIdAndDelete(id);
        if (!deletedBenefit) {
            return res.status(404).json({ message: 'Premium benefit not found' });
        }
        res.status(200).json({ message: 'Premium benefit deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Error deleting premium benefit', error: error.message });
    }
};

// FAQ Controllers
exports.createFaq = async (req, res) => {
    try {
        const { question, answer } = req.body;
        const newFaq = new Faq({ question, answer });
        await newFaq.save();
        res.status(201).json({ message: 'FAQ created successfully', faq: newFaq });
    } catch (error) {
        res.status(500).json({ message: 'Error creating FAQ', error: error.message });
    }
};

exports.getFaqs = async (req, res) => {
    try {
        const faqs = await Faq.find();
        res.status(200).json(faqs);
    } catch (error) {
        res.status(500).json({ message: 'Error fetching FAQs', error: error.message });
    }
};

exports.updateFaq = async (req, res) => {
    try {
        const { id } = req.params;
        const { question, answer } = req.body;
        const updatedFaq = await Faq.findByIdAndUpdate(id, { question, answer }, { new: true });
        if (!updatedFaq) {
            return res.status(404).json({ message: 'FAQ not found' });
        }
        res.status(200).json({ message: 'FAQ updated successfully', faq: updatedFaq });
    } catch (error) {
        res.status(500).json({ message: 'Error updating FAQ', error: error.message });
    }
};

exports.deleteFaq = async (req, res) => {
    try {
        const { id } = req.params;
        const deletedFaq = await Faq.findByIdAndDelete(id);
        if (!deletedFaq) {
            return res.status(404).json({ message: 'FAQ not found' });
        }
        res.status(200).json({ message: 'FAQ deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Error deleting FAQ', error: error.message });
    }
};

// Manage Subscriptions
exports.getAllSubscriptions = async (req, res) => {
    try {
        const { search } = req.query;
        let subscriptions;

        if (search) {
            const users = await User.find({
                $or: [
                    { name: { $regex: search, $options: 'i' } },
                    { email: { $regex: search, $options: 'i' } },
                ],
            });

            if (users.length === 0) {
                return res.status(404).json({ message: 'User not found' });
            }

            const userIds = users.map(user => user._id);

            subscriptions = await Subscription.find({ user: { $in: userIds }, status: 'active' }).populate('user', 'name email');

            if (subscriptions.length === 0) {
                return res.status(404).json({ message: 'No active subscription found for this user' });
            }
        } else {
            subscriptions = await Subscription.find({ status: 'active' }).populate('user', 'name email');
        }

        res.status(200).json(subscriptions);
    } catch (error) {
        res.status(500).json({ message: 'Error fetching subscriptions', error: error.message });
    }
};

exports.updateUserSubscription = async (req, res) => {
    try {
        const { id } = req.params;
        const { subscriptionPlan, duration, price, discount, free, endDate } = req.body;
        const updatedSubscription = await Subscription.findByIdAndUpdate(id, { subscriptionPlan, duration, price, discount, free, endDate }, { new: true });
        if (!updatedSubscription) {
            return res.status(404).json({ message: 'Subscription not found' });
        }
        res.status(200).json({ message: 'Subscription updated successfully', subscription: updatedSubscription });
    } catch (error) {
        res.status(500).json({ message: 'Error updating subscription', error: error.message });
    }
};

exports.deactivateUserSubscription = async (req, res) => {
    try {
        const { id } = req.params;
        const updatedSubscription = await Subscription.findByIdAndUpdate(id, { status: 'expired' }, { new: true });
        if (!updatedSubscription) {
            return res.status(404).json({ message: 'Subscription not found' });
        }
        res.status(200).json({ message: 'Subscription deactivated successfully', subscription: updatedSubscription });
    } catch (error) {
        res.status(500).json({ message: 'Error deactivating subscription', error: error.message });
    }
};