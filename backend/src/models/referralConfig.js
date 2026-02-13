const mongoose = require('mongoose');

const referralOptionSchema = new mongoose.Schema(
  {
    key: { type: String, required: true, trim: true },
    label: { type: String, required: true, trim: true },
    icon: { type: String, required: true, trim: true }, // e.g. whatsapp, telegram, email
    urlTemplate: {
      type: String,
      required: true,
      trim: true,
      // Supports {message}, {inviteLink}, {subject}
    },
    enabled: { type: Boolean, default: true },
    sortOrder: { type: Number, default: 0 },
  },
  { _id: false }
);

const referralConfigSchema = new mongoose.Schema(
  {
    singletonKey: { type: String, default: 'default', unique: true },
    inviteBaseUrl: {
      type: String,
      default: 'https://lenden-seven.vercel.app',
      trim: true,
    },
    inviterRewardCoins: { type: Number, default: 20 },
    refereeRewardCoins: { type: Number, default: 10 },
    shareOptions: {
      type: [referralOptionSchema],
      default: [
        {
          key: 'whatsapp',
          label: 'WhatsApp',
          icon: 'whatsapp',
          urlTemplate: 'https://wa.me/?text={message}',
          enabled: true,
          sortOrder: 1,
        },
        {
          key: 'telegram',
          label: 'Telegram',
          icon: 'telegram',
          urlTemplate: 'https://t.me/share/url?url={inviteLink}&text={message}',
          enabled: true,
          sortOrder: 2,
        },
        {
          key: 'email',
          label: 'Email',
          icon: 'email',
          urlTemplate: 'mailto:?subject={subject}&body={message}',
          enabled: true,
          sortOrder: 3,
        },
        {
          key: 'sms',
          label: 'SMS',
          icon: 'sms',
          urlTemplate: 'sms:?body={message}',
          enabled: true,
          sortOrder: 4,
        },
        {
          key: 'copy',
          label: 'Copy Text',
          icon: 'copy',
          urlTemplate: 'copy:{message}',
          enabled: true,
          sortOrder: 5,
        },
        {
          key: 'snapchat',
          label: 'Snapchat',
          icon: 'snapchat',
          urlTemplate: 'https://www.snapchat.com/scan?attachmentUrl={inviteLink}',
          enabled: true,
          sortOrder: 6,
        },
        {
          key: 'twitter',
          label: 'Twitter',
          icon: 'twitter',
          urlTemplate: 'https://twitter.com/intent/tweet?text={message}',
          enabled: true,
          sortOrder: 7,
        },
        {
          key: 'linkedin',
          label: 'LinkedIn',
          icon: 'linkedin',
          urlTemplate: 'https://www.linkedin.com/sharing/share-offsite/?url={inviteLink}',
          enabled: true,
          sortOrder: 8,
        },
        {
          key: 'instagram',
          label: 'Instagram',
          icon: 'instagram',
          urlTemplate: 'https://www.instagram.com/',
          enabled: true,
          sortOrder: 9,
        },
      ],
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('ReferralConfig', referralConfigSchema);
