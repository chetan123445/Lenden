const User = require('../models/user');
const ReferralConfig = require('../models/referralConfig');

const DEFAULT_SHARE_OPTIONS = [
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
];

const randomCode = () => {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = 'LD';
  for (let i = 0; i < 8; i += 1) {
    out += chars[Math.floor(Math.random() * chars.length)];
  }
  return out;
};

const generateUniqueReferralCode = async () => {
  for (let i = 0; i < 20; i += 1) {
    const code = randomCode();
    const exists = await User.findOne({ referralCode: code }).select('_id');
    if (!exists) return code;
  }
  throw new Error('Could not generate unique referral code');
};

const ensureUserReferralCode = async (userId) => {
  const user = await User.findById(userId).select('referralCode');
  if (!user) return null;
  if (user.referralCode) return user.referralCode;
  const code = await generateUniqueReferralCode();
  user.referralCode = code;
  await user.save();
  return code;
};

const getReferralConfig = async () => {
  let config = await ReferralConfig.findOne({ singletonKey: 'default' });
  if (!config) {
    config = await ReferralConfig.create({ singletonKey: 'default' });
    return config;
  }
  const existing = new Set((config.shareOptions || []).map((o) => (o.key || '').toLowerCase()));
  const missing = DEFAULT_SHARE_OPTIONS.filter((o) => !existing.has(o.key));
  if (missing.length > 0) {
    config.shareOptions = [...(config.shareOptions || []), ...missing];
    await config.save();
  }
  return config;
};

const processReferralRewardOnFirstCreation = async (userId) => {
  const user = await User.findById(userId).select(
    '_id email referredByUser referralRewardGranted lenDenCoins'
  );
  if (!user) return { granted: false, reason: 'user_not_found' };
  if (!user.referredByUser) return { granted: false, reason: 'no_referrer' };
  if (user.referralRewardGranted) {
    return { granted: false, reason: 'already_granted' };
  }

  const [QuickTransaction, Transaction, GroupTransaction] = [
    require('../models/quickTransaction'),
    require('../models/transaction'),
    require('../models/groupTransaction'),
  ];

  const [quickCount, userTxnCount, groupCount] = await Promise.all([
    QuickTransaction.countDocuments({ creatorEmail: user.email }),
    Transaction.countDocuments({ userEmail: user.email }),
    GroupTransaction.countDocuments({ creator: user._id }),
  ]);

  const totalCreated = quickCount + userTxnCount + groupCount;
  if (totalCreated < 1) return { granted: false, reason: 'no_creation' };

  const referrer = await User.findById(user.referredByUser).select('lenDenCoins');
  if (!referrer) return { granted: false, reason: 'referrer_not_found' };

  const config = await getReferralConfig();
  const inviterReward = Number(config.inviterRewardCoins || 20);
  const refereeReward = Number(config.refereeRewardCoins || 10);

  referrer.lenDenCoins = (referrer.lenDenCoins || 0) + inviterReward;
  user.lenDenCoins = (user.lenDenCoins || 0) + refereeReward;
  user.referralRewardGranted = true;
  user.referralConvertedAt = new Date();
  await Promise.all([referrer.save(), user.save()]);

  return {
    granted: true,
    inviterReward,
    refereeReward,
    referrerId: referrer._id,
  };
};

module.exports = {
  generateUniqueReferralCode,
  ensureUserReferralCode,
  getReferralConfig,
  processReferralRewardOnFirstCreation,
};
