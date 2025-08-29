const admin = require('firebase-admin');
const DeviceToken = require('../models/DeviceToken');

// Initialize Firebase Admin SDK (use your service account JSON)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

exports.registerToken = async (req, res) => {
  const { userId, token } = req.body;
  if (!userId || !token) return res.status(400).json({ error: 'Missing fields' });
  await DeviceToken.findOneAndUpdate(
    { userId },
    { token },
    { upsert: true, new: true }
  );
  res.json({ message: 'Token registered' });
};

exports.sendNotification = async (req, res) => {
  const { userId, title, body } = req.body;
  const device = await DeviceToken.findOne({ userId });
  if (!device) return res.status(404).json({ error: 'Device token not found' });

  const message = {
    notification: { title, body },
    token: device.token,
  };

  try {
    await admin.messaging().send(message);
    res.json({ message: 'Notification sent' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Utility to send notification by userId (for use in other controllers)
exports.sendToUser = async (userId, title, body) => {
  const device = await DeviceToken.findOne({ userId });
  if (!device) return;
  await admin.messaging().send({
    notification: { title, body },
    token: device.token,
  });
};

exports.sendToAdmins = async (title, body) => {
  const admins = await DeviceToken.find({ isAdmin: true });
  const messages = admins.map(admin => ({
    notification: { title, body },
    token: admin.token,
  }));

  try {
    await Promise.all(messages.map(message => admin.messaging().send(message)));
  } catch (err) {
    console.error('Error sending notifications to admins:', err);
  }
};
