const mongoose = require('mongoose');
const fs = require('fs');
const Admin = require('../models/admin');
const AppUpdate = require('../models/appUpdate');
const AppAd = require('../models/appAd');
const { getAdMediaBucket } = require('../utils/adMediaBucket');

const normalizeCreator = (creator) => {
  if (!creator) return null;
  if (creator._id) {
    return {
      _id: creator._id,
      name: creator.name || '',
      email: creator.email || '',
      isSuperAdmin: creator.isSuperAdmin === true,
    };
  }
  return creator;
};

const canManageContent = (admin, content) => {
  if (!admin || !content) return false;
  if (admin.isSuperAdmin === true) return true;
  const creatorId = content.createdBy?._id || content.createdBy;
  return creatorId?.toString() === admin._id.toString();
};

const toUpdateResponse = (req, update, currentAdmin = null) => ({
  _id: update._id,
  title: update.title,
  body: update.body,
  versionTag: update.versionTag || '',
  pinned: !!update.pinned,
  publishedAt: update.publishedAt,
  createdAt: update.createdAt,
  updatedAt: update.updatedAt,
  createdBy: normalizeCreator(update.createdBy),
  canManage: currentAdmin ? canManageContent(currentAdmin, update) : undefined,
});

const toAdResponse = (req, ad, currentAdmin = null) => ({
  _id: ad._id,
  title: ad.title,
  body: ad.body || '',
  callToActionText: ad.callToActionText || '',
  callToActionUrl: ad.callToActionUrl || '',
  mediaKind: ad.mediaKind || 'none',
  mediaFilename: ad.mediaFilename || '',
  mediaMimeType: ad.mediaMimeType || '',
  videoCloseAtPercent: normalizeVideoClosePercent(ad.videoCloseAtPercent),
  mediaUrl:
    ad.mediaFileId != null
      ? `${req.protocol}://${req.get('host')}/api/ads/media/${ad.mediaFileId}`
      : null,
  active: !!ad.active,
  startsAt: ad.startsAt,
  endsAt: ad.endsAt,
  createdAt: ad.createdAt,
  updatedAt: ad.updatedAt,
  createdBy: normalizeCreator(ad.createdBy),
  canManage: currentAdmin ? canManageContent(currentAdmin, ad) : undefined,
});

const getCurrentAdmin = async (req) => {
  if (!req.user?._id || req.user.role !== 'admin') return null;
  return Admin.findById(req.user._id).select('_id email name isSuperAdmin').lean();
};

const detectMediaKind = (mimeType = '') => {
  if (mimeType.startsWith('image/')) return 'image';
  if (mimeType.startsWith('video/')) return 'video';
  return 'none';
};

const normalizeVideoClosePercent = (value) => {
  const parsed = Number.parseInt(value, 10);
  return [25, 50, 75, 100].includes(parsed) ? parsed : 100;
};

const uploadAdMedia = async (file) => {
  if (!file) {
    return {
      mediaFileId: null,
      mediaFilename: '',
      mediaMimeType: '',
      mediaKind: 'none',
    };
  }

  const bucket = getAdMediaBucket();
  const uploadStream = bucket.openUploadStream(file.originalname, {
    contentType: file.mimetype,
    metadata: {
      uploadedAt: new Date(),
      originalName: file.originalname,
    },
  });

  try {
    await new Promise((resolve, reject) => {
      uploadStream.on('error', reject);
      uploadStream.on('finish', resolve);

      if (file.path) {
        const readStream = fs.createReadStream(file.path);
        readStream.on('error', reject);
        readStream.pipe(uploadStream);
        return;
      }

      uploadStream.end(file.buffer, (error) => {
        if (error) reject(error);
      });
    });
  } finally {
    if (file.path) {
      fs.promises.unlink(file.path).catch(() => {});
    }
  }

  return {
    mediaFileId: uploadStream.id,
    mediaFilename: file.originalname,
    mediaMimeType: file.mimetype || '',
    mediaKind: detectMediaKind(file.mimetype),
  };
};

const removeAdMedia = async (fileId) => {
  if (!fileId) return;
  try {
    const bucket = getAdMediaBucket();
    await bucket.delete(
      typeof fileId === 'string' ? new mongoose.Types.ObjectId(fileId) : fileId
    );
  } catch (error) {
    console.error('Failed to delete ad media from GridFS:', error);
  }
};

exports.listUpdates = async (req, res) => {
  try {
    const currentAdmin = await getCurrentAdmin(req);
    const updates = await AppUpdate.find({})
      .populate('createdBy', 'name email isSuperAdmin')
      .sort({ pinned: -1, publishedAt: -1 })
      .lean();

    res.json({
      updates: updates.map((update) => toUpdateResponse(req, update, currentAdmin)),
    });
  } catch (error) {
    console.error('Failed to list updates:', error);
    res.status(500).json({ error: 'Failed to load updates' });
  }
};

exports.createUpdate = async (req, res) => {
  try {
    const { title, body, versionTag, pinned } = req.body;
    if (!title?.trim() || !body?.trim()) {
      return res.status(400).json({ error: 'Title and body are required.' });
    }

    const update = await AppUpdate.create({
      title: title.trim(),
      body: body.trim(),
      versionTag: (versionTag || '').trim(),
      pinned: pinned === true || pinned === 'true',
      createdBy: req.user._id,
    });

    const populated = await AppUpdate.findById(update._id)
      .populate('createdBy', 'name email isSuperAdmin')
      .lean();
    const currentAdmin = await getCurrentAdmin(req);

    res.status(201).json({
      message: 'Update published successfully.',
      update: toUpdateResponse(req, populated, currentAdmin),
    });
  } catch (error) {
    console.error('Failed to create update:', error);
    res.status(500).json({ error: 'Failed to publish update' });
  }
};

exports.updateUpdate = async (req, res) => {
  try {
    const currentAdmin = await getCurrentAdmin(req);
    const existing = await AppUpdate.findById(req.params.updateId)
      .populate('createdBy', 'name email isSuperAdmin')
      .lean();
    if (!existing) {
      return res.status(404).json({ error: 'Update not found.' });
    }
    if (!canManageContent(currentAdmin, existing)) {
      return res.status(403).json({ error: 'You can only edit your own updates unless you are a superadmin.' });
    }

    const { title, body, versionTag, pinned } = req.body;
    if (!title?.trim() || !body?.trim()) {
      return res.status(400).json({ error: 'Title and body are required.' });
    }

    const update = await AppUpdate.findByIdAndUpdate(
      req.params.updateId,
      {
        title: title.trim(),
        body: body.trim(),
        versionTag: (versionTag || '').trim(),
        pinned: pinned === true || pinned === 'true',
      },
      { new: true }
    )
      .populate('createdBy', 'name email isSuperAdmin')
      .lean();

    res.json({
      message: 'Update edited successfully.',
      update: toUpdateResponse(req, update, currentAdmin),
    });
  } catch (error) {
    console.error('Failed to update update:', error);
    res.status(500).json({ error: 'Failed to edit update' });
  }
};

exports.deleteUpdate = async (req, res) => {
  try {
    const currentAdmin = await getCurrentAdmin(req);
    const update = await AppUpdate.findById(req.params.updateId)
      .populate('createdBy', 'name email isSuperAdmin')
      .lean();
    if (!update) {
      return res.status(404).json({ error: 'Update not found.' });
    }
    if (!canManageContent(currentAdmin, update)) {
      return res.status(403).json({ error: 'You can only delete your own updates unless you are a superadmin.' });
    }
    await AppUpdate.findByIdAndDelete(req.params.updateId);
    res.json({ message: 'Update deleted successfully.' });
  } catch (error) {
    console.error('Failed to delete update:', error);
    res.status(500).json({ error: 'Failed to delete update' });
  }
};

exports.listAdminAds = async (req, res) => {
  try {
    const currentAdmin = await getCurrentAdmin(req);
    const ads = await AppAd.find({})
      .populate('createdBy', 'name email isSuperAdmin')
      .sort({ createdAt: -1 })
      .lean();

    res.json({
      ads: ads.map((ad) => toAdResponse(req, ad, currentAdmin)),
    });
  } catch (error) {
    console.error('Failed to load ads:', error);
    res.status(500).json({ error: 'Failed to load ads' });
  }
};

exports.createAd = async (req, res) => {
  try {
    const {
      title,
      body,
      callToActionText,
      callToActionUrl,
      startsAt,
      endsAt,
      videoCloseAtPercent,
    } = req.body;

    if (!title?.trim()) {
      return res.status(400).json({ error: 'Ad title is required.' });
    }

    if (callToActionUrl && !/^https?:\/\//i.test(callToActionUrl.trim())) {
      return res
        .status(400)
        .json({ error: 'Call-to-action URL must start with http:// or https://.' });
    }

    const media = await uploadAdMedia(req.file);
    const ad = await AppAd.create({
      title: title.trim(),
      body: (body || '').trim(),
      callToActionText: (callToActionText || '').trim(),
      callToActionUrl: (callToActionUrl || '').trim(),
      videoCloseAtPercent: normalizeVideoClosePercent(videoCloseAtPercent),
      startsAt: startsAt ? new Date(startsAt) : new Date(),
      endsAt: endsAt ? new Date(endsAt) : null,
      createdBy: req.user._id,
      ...media,
    });

    const saved = await AppAd.findById(ad._id).lean();
    const populated = await AppAd.findById(saved._id)
      .populate('createdBy', 'name email isSuperAdmin')
      .lean();
    const currentAdmin = await getCurrentAdmin(req);
    res.status(201).json({
      message: 'Ad created successfully.',
      ad: toAdResponse(req, populated, currentAdmin),
    });
  } catch (error) {
    console.error('Failed to create ad:', error);
    res.status(500).json({ error: 'Failed to create ad' });
  }
};

exports.updateAd = async (req, res) => {
  try {
    const currentAdmin = await getCurrentAdmin(req);
    const existing = await AppAd.findById(req.params.adId)
      .populate('createdBy', 'name email isSuperAdmin')
      .lean();
    if (!existing) {
      return res.status(404).json({ error: 'Ad not found.' });
    }
    if (!canManageContent(currentAdmin, existing)) {
      return res.status(403).json({ error: 'You can only edit your own ads unless you are a superadmin.' });
    }

    const {
      title,
      body,
      callToActionText,
      callToActionUrl,
      startsAt,
      endsAt,
      active,
      videoCloseAtPercent,
    } = req.body;

    if (!title?.trim()) {
      return res.status(400).json({ error: 'Ad title is required.' });
    }
    if (callToActionUrl && !/^https?:\/\//i.test(callToActionUrl.trim())) {
      return res
        .status(400)
        .json({ error: 'Call-to-action URL must start with http:// or https://.' });
    }

    let mediaUpdate = {};
    if (req.file) {
      await removeAdMedia(existing.mediaFileId);
      mediaUpdate = await uploadAdMedia(req.file);
    }

    const ad = await AppAd.findByIdAndUpdate(
      req.params.adId,
      {
        title: title.trim(),
        body: (body || '').trim(),
        callToActionText: (callToActionText || '').trim(),
        callToActionUrl: (callToActionUrl || '').trim(),
        videoCloseAtPercent: normalizeVideoClosePercent(videoCloseAtPercent),
        startsAt: startsAt ? new Date(startsAt) : new Date(),
        endsAt: endsAt ? new Date(endsAt) : null,
        active: active === true || active === 'true',
        ...mediaUpdate,
      },
      { new: true }
    )
      .populate('createdBy', 'name email isSuperAdmin')
      .lean();

    res.json({
      message: 'Ad edited successfully.',
      ad: toAdResponse(req, ad, currentAdmin),
    });
  } catch (error) {
    console.error('Failed to edit ad:', error);
    res.status(500).json({ error: 'Failed to edit ad' });
  }
};

exports.toggleAd = async (req, res) => {
  try {
    const currentAdmin = await getCurrentAdmin(req);
    const existing = await AppAd.findById(req.params.adId)
      .populate('createdBy', 'name email isSuperAdmin')
      .lean();
    if (!existing) {
      return res.status(404).json({ error: 'Ad not found.' });
    }
    if (!canManageContent(currentAdmin, existing)) {
      return res.status(403).json({ error: 'You can only edit your own ads unless you are a superadmin.' });
    }

    const { active } = req.body;
    const ad = await AppAd.findByIdAndUpdate(
      req.params.adId,
      { active: active === true || active === 'true' },
      { new: true }
    ).populate('createdBy', 'name email isSuperAdmin').lean();

    res.json({
      message: 'Ad status updated.',
      ad: toAdResponse(req, ad, currentAdmin),
    });
  } catch (error) {
    console.error('Failed to update ad:', error);
    res.status(500).json({ error: 'Failed to update ad' });
  }
};

exports.deleteAd = async (req, res) => {
  try {
    const currentAdmin = await getCurrentAdmin(req);
    const ad = await AppAd.findById(req.params.adId)
      .populate('createdBy', 'name email isSuperAdmin')
      .lean();
    if (!ad) {
      return res.status(404).json({ error: 'Ad not found.' });
    }
    if (!canManageContent(currentAdmin, ad)) {
      return res.status(403).json({ error: 'You can only delete your own ads unless you are a superadmin.' });
    }

    await AppAd.findByIdAndDelete(req.params.adId);
    await removeAdMedia(ad.mediaFileId);
    res.json({ message: 'Ad deleted successfully.' });
  } catch (error) {
    console.error('Failed to delete ad:', error);
    res.status(500).json({ error: 'Failed to delete ad' });
  }
};

exports.getRandomActiveAd = async (req, res) => {
  try {
    const now = new Date();
    const ads = await AppAd.aggregate([
      {
        $match: {
          active: true,
          startsAt: { $lte: now },
          $or: [{ endsAt: null }, { endsAt: { $gte: now } }],
        },
      },
      { $sample: { size: 1 } },
    ]);

    const ad = ads[0];
    if (!ad) {
      return res.json({ ad: null });
    }

    res.json({ ad: toAdResponse(req, ad) });
  } catch (error) {
    console.error('Failed to fetch random ad:', error);
    res.status(500).json({ error: 'Failed to fetch ad' });
  }
};

exports.streamAdMedia = async (req, res) => {
  try {
    const fileId = new mongoose.Types.ObjectId(req.params.fileId);
    const bucket = getAdMediaBucket();
    const files = await bucket.find({ _id: fileId }).toArray();
    const file = files[0];

    if (!file) {
      return res.status(404).json({ error: 'Media not found.' });
    }

    const range = req.headers.range;
    const contentType = file.contentType || 'application/octet-stream';

    if (range) {
      const parts = range.replace(/bytes=/, '').split('-');
      const start = parseInt(parts[0], 10);
      const end = parts[1] ? parseInt(parts[1], 10) : file.length - 1;
      const chunkSize = end - start + 1;

      res.status(206);
      res.set({
        'Content-Range': `bytes ${start}-${end}/${file.length}`,
        'Accept-Ranges': 'bytes',
        'Content-Length': chunkSize,
        'Content-Type': contentType,
      });

      bucket.openDownloadStream(fileId, { start, end: end + 1 }).pipe(res);
      return;
    }

    res.set({
      'Content-Length': file.length,
      'Content-Type': contentType,
      'Accept-Ranges': 'bytes',
    });

    bucket.openDownloadStream(fileId).pipe(res);
  } catch (error) {
    console.error('Failed to stream ad media:', error);
    res.status(500).json({ error: 'Failed to stream media' });
  }
};
