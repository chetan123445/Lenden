const mongoose = require('mongoose');

const contactChannelSchema = new mongoose.Schema(
  {
    label: { type: String, trim: true, default: '' },
    value: { type: String, trim: true, default: '' },
    url: { type: String, trim: true, default: '' },
    enabled: { type: Boolean, default: true },
  },
  { _id: false }
);

const contactConfigSchema = new mongoose.Schema(
  {
    singletonKey: { type: String, default: 'default', unique: true },
    heroTitle: {
      type: String,
      trim: true,
      default: 'Contact Us',
    },
    heroDescription: {
      type: String,
      trim: true,
      default:
        'We would love to hear from you! Reach out to us through any of the following ways:',
    },
    email: {
      type: contactChannelSchema,
      default: () => ({
        label: 'Email',
        value: 'chetandudi791@gmail.com',
        url: 'mailto:chetandudi791@gmail.com',
        enabled: true,
      }),
    },
    facebook: {
      type: contactChannelSchema,
      default: () => ({
        label: 'Facebook',
        value: 'Lenden App',
        url: '',
        enabled: true,
      }),
    },
    whatsapp: {
      type: contactChannelSchema,
      default: () => ({
        label: 'WhatsApp',
        value: '+91-XXXXXXXXXX',
        url: '',
        enabled: true,
      }),
    },
    instagram: {
      type: contactChannelSchema,
      default: () => ({
        label: 'Instagram',
        value: '_Chetan_Dudi',
        url: '',
        enabled: true,
      }),
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('ContactConfig', contactConfigSchema);
