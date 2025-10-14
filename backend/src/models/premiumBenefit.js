const mongoose = require('mongoose');

const premiumBenefitSchema = new mongoose.Schema({
    text: {
        type: String,
        required: true
    }
}, { timestamps: true });

module.exports = mongoose.model('PremiumBenefit', premiumBenefitSchema);
