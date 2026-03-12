const ContactConfig = require('../models/contactConfig');

const ensureContactConfig = async () =>
  ContactConfig.findOneAndUpdate(
    { singletonKey: 'default' },
    { $setOnInsert: { singletonKey: 'default' } },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

const normalizeText = (value, fallback = '') => {
  if (typeof value !== 'string') return fallback;
  return value.trim();
};

const normalizeChannel = (input = {}, fallback = {}) => ({
  label: normalizeText(input.label, fallback.label || ''),
  value: normalizeText(input.value, fallback.value || ''),
  url: normalizeText(input.url, fallback.url || ''),
  enabled: input.enabled !== false,
});

const serializeConfig = (config) => ({
  heroTitle: config.heroTitle || '',
  heroDescription: config.heroDescription || '',
  email: normalizeChannel(config.email, { label: 'Email' }),
  facebook: normalizeChannel(config.facebook, { label: 'Facebook' }),
  whatsapp: normalizeChannel(config.whatsapp, { label: 'WhatsApp' }),
  instagram: normalizeChannel(config.instagram, { label: 'Instagram' }),
});

exports.getPublicContactConfig = async (_req, res) => {
  try {
    const config = await ensureContactConfig();
    res.json(serializeConfig(config));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getAdminContactConfig = async (_req, res) => {
  try {
    const config = await ensureContactConfig();
    res.json(serializeConfig(config));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.updateAdminContactConfig = async (req, res) => {
  try {
    const config = await ensureContactConfig();
    const payload = req.body || {};

    if (payload.heroTitle !== undefined) {
      const heroTitle = normalizeText(payload.heroTitle);
      if (!heroTitle) {
        return res.status(400).json({ error: 'heroTitle is required.' });
      }
      config.heroTitle = heroTitle;
    }

    if (payload.heroDescription !== undefined) {
      const heroDescription = normalizeText(payload.heroDescription);
      if (!heroDescription) {
        return res.status(400).json({ error: 'heroDescription is required.' });
      }
      config.heroDescription = heroDescription;
    }

    ['email', 'facebook', 'whatsapp', 'instagram'].forEach((key) => {
      if (payload[key] !== undefined) {
        config[key] = normalizeChannel(payload[key], config[key] || {});
      }
    });

    await config.save();

    res.json({
      success: true,
      message: 'Contact information updated.',
      ...serializeConfig(config),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
