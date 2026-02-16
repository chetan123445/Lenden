const Offer = require('../models/offer');
const OfferClaim = require('../models/offerClaim');
const User = require('../models/user');
const Notification = require('../models/notification');
const { createActivityLog } = require('./activityController');

const ensureValidDate = (value, fieldName) => {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`${fieldName} must be a valid date`);
  }
  return parsed;
};

const rollbackOfferClaimsForUpdate = async (offerId) => {
  const claims = await OfferClaim.find({ offer: offerId }).select('user coinsAwarded');
  if (!claims.length) {
    return { affectedUsers: 0, revertedCoins: 0, revertedClaims: 0 };
  }

  const coinsByUser = new Map();
  let revertedCoins = 0;
  for (const claim of claims) {
    const userId = claim.user.toString();
    const coins = Number(claim.coinsAwarded || 0);
    revertedCoins += coins;
    coinsByUser.set(userId, (coinsByUser.get(userId) || 0) + coins);
  }

  const bulkOps = [...coinsByUser.entries()].map(([userId, coins]) => ({
    updateOne: {
      filter: { _id: userId },
      update: { $inc: { lenDenCoins: -coins } },
    },
  }));

  if (bulkOps.length) {
    await User.bulkWrite(bulkOps);
  }

  const deleteResult = await OfferClaim.deleteMany({ offer: offerId });
  return {
    affectedUsers: coinsByUser.size,
    revertedCoins,
    revertedClaims: deleteResult.deletedCount || 0,
  };
};

const cleanupExpiredOffers = async () => {
  const now = new Date();
  const expiredOffers = await Offer.find({ endsAt: { $lt: now } }).select('_id');
  if (!expiredOffers.length) return { deletedOffers: 0, deletedClaims: 0 };

  const offerIds = expiredOffers.map((o) => o._id);
  const claimDelete = await OfferClaim.deleteMany({ offer: { $in: offerIds } });
  const offerDelete = await Offer.deleteMany({ _id: { $in: offerIds } });
  return {
    deletedOffers: offerDelete.deletedCount || 0,
    deletedClaims: claimDelete.deletedCount || 0,
  };
};

const resolveRecipientUserIds = async ({ recipientType, recipientUserIds, recipientEmails }) => {
  if (recipientType !== 'specific-users') {
    return [];
  }

  const ids = Array.isArray(recipientUserIds)
    ? recipientUserIds.map((v) => v.toString().trim()).filter(Boolean)
    : [];
  const emails = Array.isArray(recipientEmails)
    ? recipientEmails.map((v) => v.toString().trim().toLowerCase()).filter(Boolean)
    : [];

  let users = [];
  if (ids.length) {
    const byId = await User.find({ _id: { $in: ids } }, '_id');
    users = users.concat(byId);
  }
  if (emails.length) {
    const byEmail = await User.find({ email: { $in: emails } }, '_id');
    users = users.concat(byEmail);
  }

  const uniqueIds = [...new Set(users.map((u) => u._id.toString()))];
  if (!uniqueIds.length) {
    throw new Error('No valid users found for specific-users offer');
  }
  return uniqueIds;
};

const sendOfferNotificationToUsers = async ({
  adminId,
  message,
  recipientType = 'all-users',
  recipientIds = [],
}) => {
  let recipients = [];
  let notificationRecipientType = 'all-users';

  if (recipientType === 'specific-users') {
    notificationRecipientType = 'specific-users';
    recipients = recipientIds;
    if (!recipients.length) return;
  } else {
    const users = await User.find({}, '_id');
    recipients = users.map((u) => u._id);
    if (!recipients.length) return;
  }

  const notification = new Notification({
    sender: adminId,
    senderModel: 'Admin',
    recipientType: notificationRecipientType,
    recipients,
    recipientModel: 'User',
    message,
  });
  await notification.save();
};

exports.cleanupExpiredOffers = cleanupExpiredOffers;

exports.createOffer = async (req, res) => {
  try {
    const {
      name,
      description,
      coins,
      startsAt,
      endsAt,
      isActive,
      recipientType = 'all-users',
      recipientUserIds,
      recipientEmails,
    } = req.body;
    if (!name || !coins || !startsAt || !endsAt) {
      return res.status(400).json({ error: 'name, coins, startsAt and endsAt are required' });
    }
    if (!['all-users', 'specific-users'].includes(recipientType)) {
      return res.status(400).json({ error: 'recipientType must be all-users or specific-users' });
    }

    const startDate = ensureValidDate(startsAt, 'startsAt');
    const endDate = ensureValidDate(endsAt, 'endsAt');
    if (endDate <= startDate) {
      return res.status(400).json({ error: 'endsAt must be later than startsAt' });
    }
    const resolvedRecipientIds = await resolveRecipientUserIds({
      recipientType,
      recipientUserIds,
      recipientEmails,
    });

    const newOffer = await Offer.create({
      name: name.toString().trim(),
      description: (description || '').toString().trim(),
      coins: Number(coins),
      startsAt: startDate,
      endsAt: endDate,
      isActive: typeof isActive === 'boolean' ? isActive : true,
      recipientType,
      recipients: resolvedRecipientIds,
      createdBy: req.user._id,
      updatedBy: req.user._id,
    });

    await sendOfferNotificationToUsers({
      adminId: req.user._id,
      message: `New offer: "${newOffer.name}" (+${newOffer.coins} coins). Accept before ${newOffer.endsAt.toLocaleString()}.`,
      recipientType: newOffer.recipientType,
      recipientIds: newOffer.recipients,
    });

    const populated = await Offer.findById(newOffer._id)
      .populate('createdBy', 'name email username')
      .populate('updatedBy', 'name email username')
      .populate('recipients', 'name username email');
    return res.status(201).json(populated);
  } catch (error) {
    return res.status(400).json({ error: error.message });
  }
};

exports.getAdminOffers = async (req, res) => {
  try {
    await cleanupExpiredOffers();
    const { includeInactive = 'true' } = req.query;
    const query = {};
    if (includeInactive !== 'true') query.isActive = true;

    const offers = await Offer.find(query)
      .populate('createdBy', 'name email username')
      .populate('updatedBy', 'name email username')
      .populate('recipients', 'name username email')
      .sort({ createdAt: -1 });

    return res.json(offers);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.updateOffer = async (req, res) => {
  try {
    await cleanupExpiredOffers();
    const { offerId } = req.params;
    const offer = await Offer.findById(offerId);
    if (!offer) return res.status(404).json({ error: 'Offer not found' });

    const {
      name,
      description,
      coins,
      startsAt,
      endsAt,
      isActive,
      recipientType,
      recipientUserIds,
      recipientEmails,
    } = req.body;

    if (name !== undefined) offer.name = name.toString().trim();
    if (description !== undefined) offer.description = description.toString().trim();
    if (coins !== undefined) offer.coins = Number(coins);
    if (startsAt !== undefined) offer.startsAt = ensureValidDate(startsAt, 'startsAt');
    if (endsAt !== undefined) offer.endsAt = ensureValidDate(endsAt, 'endsAt');
    if (isActive !== undefined) offer.isActive = Boolean(isActive);
    if (recipientType !== undefined) {
      if (!['all-users', 'specific-users'].includes(recipientType)) {
        return res.status(400).json({ error: 'recipientType must be all-users or specific-users' });
      }
      offer.recipientType = recipientType;
      const resolvedRecipientIds = await resolveRecipientUserIds({
        recipientType,
        recipientUserIds,
        recipientEmails,
      });
      offer.recipients = resolvedRecipientIds;
    } else if (offer.recipientType === 'specific-users') {
      // If recipient type remains specific-users and caller sent recipient updates only.
      const recipientInputsProvided =
        recipientUserIds !== undefined || recipientEmails !== undefined;
      if (recipientInputsProvided) {
        const resolvedRecipientIds = await resolveRecipientUserIds({
          recipientType: 'specific-users',
          recipientUserIds,
          recipientEmails,
        });
        offer.recipients = resolvedRecipientIds;
      }
    }
    if (offer.endsAt <= offer.startsAt) {
      return res.status(400).json({ error: 'endsAt must be later than startsAt' });
    }

    offer.updatedBy = req.user._id;
    await offer.save();

    // Reset previous acceptances on any offer update:
    // users can accept updated offer again; old accepted coins are reverted first.
    const rollbackSummary = await rollbackOfferClaimsForUpdate(offer._id);

    if (offer.isActive && offer.endsAt > new Date()) {
      await sendOfferNotificationToUsers({
        adminId: req.user._id,
        message: `Offer updated: "${offer.name}" (+${offer.coins} coins). Accept before ${offer.endsAt.toLocaleString()}. Please accept again to claim updated coins.`,
        recipientType: offer.recipientType,
        recipientIds: offer.recipients,
      });
    }

    const populated = await Offer.findById(offer._id)
      .populate('createdBy', 'name email username')
      .populate('updatedBy', 'name email username')
      .populate('recipients', 'name username email');
    return res.json({
      offer: populated,
      rollbackSummary,
    });
  } catch (error) {
    return res.status(400).json({ error: error.message });
  }
};

exports.deleteOffer = async (req, res) => {
  try {
    const { offerId } = req.params;
    const offer = await Offer.findById(offerId);
    if (!offer) return res.status(404).json({ error: 'Offer not found' });

    await OfferClaim.deleteMany({ offer: offer._id });
    await offer.deleteOne();
    return res.json({ message: 'Offer deleted successfully' });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.getAvailableOffers = async (req, res) => {
  try {
    await cleanupExpiredOffers();
    const userId = req.user._id;
    const now = new Date();

    const offers = await Offer.find({
      isActive: true,
      startsAt: { $lte: now },
      endsAt: { $gte: now },
      $or: [
        { recipientType: 'all-users' },
        { recipientType: 'specific-users', recipients: userId },
      ],
    }).sort({ endsAt: 1, createdAt: -1 });

    if (!offers.length) return res.json([]);

    const offerIds = offers.map((o) => o._id);
    const claims = await OfferClaim.find({
      user: userId,
      offer: { $in: offerIds },
    }).select('offer claimedAt coinsAwarded');

    const claimMap = new Map(
      claims.map((c) => [c.offer.toString(), { claimedAt: c.claimedAt, coinsAwarded: c.coinsAwarded }])
    );

    const response = offers.map((offer) => {
      const claim = claimMap.get(offer._id.toString());
      return {
        _id: offer._id,
        name: offer.name,
        description: offer.description,
        coins: offer.coins,
        startsAt: offer.startsAt,
        endsAt: offer.endsAt,
        createdAt: offer.createdAt,
        recipientType: offer.recipientType,
        claimed: Boolean(claim),
        claimedAt: claim?.claimedAt || null,
        claimedCoins: claim?.coinsAwarded || null,
      };
    });

    return res.json(response);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.acceptOffer = async (req, res) => {
  try {
    await cleanupExpiredOffers();
    const { offerId } = req.params;
    const userId = req.user._id;

    const offer = await Offer.findById(offerId);
    if (!offer) return res.status(404).json({ error: 'Offer not found or expired' });
    if (!offer.isActive) return res.status(400).json({ error: 'Offer is not active' });
    const allowedForUser =
      offer.recipientType === 'all-users' ||
      (offer.recipientType === 'specific-users' &&
        offer.recipients.some((id) => id.toString() === userId.toString()));
    if (!allowedForUser) {
      return res.status(403).json({ error: 'This offer is not assigned to your account' });
    }

    const now = new Date();
    if (offer.startsAt > now) return res.status(400).json({ error: 'Offer has not started yet' });
    if (offer.endsAt < now) return res.status(400).json({ error: 'Offer has already ended' });

    const alreadyClaimed = await OfferClaim.findOne({ offer: offer._id, user: userId });
    if (alreadyClaimed) return res.status(409).json({ error: 'Offer already accepted' });

    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ error: 'User not found' });

    await OfferClaim.create({
      offer: offer._id,
      user: userId,
      coinsAwarded: offer.coins,
      claimedAt: now,
    });

    user.lenDenCoins = (user.lenDenCoins || 0) + offer.coins;
    await user.save();
    await createActivityLog(
      userId,
      'offer_accepted',
      'Offer Accepted',
      `Accepted offer "${offer.name}" and earned ${offer.coins} LenDen coins`,
      {
        offerId: offer._id,
        offerName: offer.name,
        coinsAwarded: offer.coins,
      }
    );

    return res.json({
      message: 'Offer accepted successfully',
      coinsAwarded: offer.coins,
      totalCoins: user.lenDenCoins,
      offerId: offer._id,
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.getMyOfferClaims = async (req, res) => {
  try {
    await cleanupExpiredOffers();
    const claims = await OfferClaim.find({ user: req.user._id })
      .populate('offer', 'name description coins startsAt endsAt')
      .sort({ claimedAt: -1 });
    return res.json(claims);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

exports.searchUsersForOffers = async (req, res) => {
  try {
    const { search = '', limit = 20 } = req.query;
    const parsedLimit = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 100);
    const trimmed = search.toString().trim();

    const query = trimmed
      ? {
          $or: [
            { email: { $regex: trimmed, $options: 'i' } },
            { username: { $regex: trimmed, $options: 'i' } },
            { name: { $regex: trimmed, $options: 'i' } },
          ],
        }
      : {};

    const users = await User.find(query, '_id name username email createdAt')
      .sort({ createdAt: -1 })
      .limit(parsedLimit);
    return res.json({ users });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
