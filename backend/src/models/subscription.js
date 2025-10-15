const mongoose = require('mongoose');

const subscriptionSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    status: {
        type: String,
        enum: ['active', 'expired'],
        default: 'active'
    },
    subscribed: {
        type: Boolean,
        default: false
    },
    subscriptionPlan: {
        type: String,
        default: null
    },
    duration: {
        type: Number,
        default: 0
    },
    price: {
        type: Number,
        default: 0
    },
    discount: {
        type: Number,
        default: 0
    },
    actualPrice: {
        type: Number,
        default: 0
    },
    free: {
        type: Number,
        default: 0
    },
    endDate: {
        type: Date
    },
    subscribedDate: {
        type: Date
    }
}, { timestamps: true });

module.exports = mongoose.model('Subscription', subscriptionSchema);