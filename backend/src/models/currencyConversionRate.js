const mongoose = require('mongoose');

const currencyConversionRateSchema = new mongoose.Schema(
  {
    baseCurrency: {
      type: String,
      required: true,
      uppercase: true,
      trim: true,
    },
    quoteCurrency: {
      type: String,
      required: true,
      uppercase: true,
      trim: true,
    },
    rate: {
      type: Number,
      required: true,
      min: 0,
    },
    updatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Admin',
      required: true,
    },
    isAutoDerived: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true }
);

currencyConversionRateSchema.index(
  { baseCurrency: 1, quoteCurrency: 1 },
  { unique: true }
);

module.exports = mongoose.model(
  'CurrencyConversionRate',
  currencyConversionRateSchema
);
