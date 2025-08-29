const admin = require('firebase-admin');
const DeviceToken = require('../models/DeviceToken');



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

exports.sendToUser = async (userId, title, body) => {
  try {
    console.log(`🔔 Attempting to send notification to user: ${userId}`);
    console.log(`📧 Title: ${title}, Body: ${body}`);
    
    const device = await DeviceToken.findOne({ userId: userId.toString() });
    if (!device) {
      console.log(`❌ No device token found for user: ${userId}`);
      return { success: false, error: 'No device token found' };
    }

    console.log(`📱 Found device token: ${device.token.substring(0, 20)}...`);
    
    const message = {
      notification: { 
        title, 
        body 
      },
      token: device.token,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        }
      },
    };

    const response = await admin.messaging().send(message);
    console.log('✅ Notification sent successfully:', response);
    return { success: true, response };
    
  } catch (err) {
    console.error('❌ Error sending notification:', err);
    
    // Handle invalid token
    if (err.code === 'messaging/registration-token-not-registered' || 
        err.code === 'messaging/invalid-registration-token') {
      console.log('🗑️ Invalid token, removing from database');
      await DeviceToken.deleteOne({ userId: userId.toString() });
    }
    
    return { success: false, error: err.message };
  }
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
