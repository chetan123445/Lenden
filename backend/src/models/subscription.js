const mongoose = require('mongoose');

const subscriptionSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        unique: true
    },
    subscribed: {
        type: Boolean,
        default: false
    },
    subscriptionPlan: {
        type: String,
        enum: ['1 month', '2 months', '3 months', '6 months', '1 year', null],
        default: null
    },
    endDate: {
        type: Date
    },
    subscribedDate: {
        type: Date
    }
}, { timestamps: true });

module.exports = mongoose.model('Subscription', subscriptionSchema);