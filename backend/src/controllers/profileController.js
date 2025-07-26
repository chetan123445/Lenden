const User = require('../models/user');
const Admin = require('../models/admin');

exports.getUserProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select('-password');
    if (!user) return res.status(404).json({ error: 'User not found' });
    const userObj = user.toObject();
    if (userObj.profileImage) {
      userObj.profileImage = `${req.protocol}://${req.get('host')}/api/users/${userObj._id}/profile-image`;
    }
    res.json(userObj);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getAdminProfile = async (req, res) => {
  try {
    const admin = await Admin.findById(req.user._id).select('-password');
    if (!admin) return res.status(404).json({ error: 'Admin not found' });
    const adminObj = admin.toObject();
    if (adminObj.profileImage) {
      adminObj.profileImage = `${req.protocol}://${req.get('host')}/api/admins/${adminObj._id}/profile-image`;
    }
    res.json(adminObj);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getUserProfileImage = async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('profileImage');
    if (!user || !user.profileImage) return res.status(404).send('Not found');
    res.set('Content-Type', 'image/jpeg'); // You may want to store the type in DB for flexibility
    res.send(user.profileImage);
  } catch (err) {
    res.status(500).send('Error');
  }
};

exports.getAdminProfileImage = async (req, res) => {
  try {
    const admin = await Admin.findById(req.params.id).select('profileImage');
    if (!admin || !admin.profileImage) return res.status(404).send('Not found');
    res.set('Content-Type', 'image/jpeg');
    res.send(admin.profileImage);
  } catch (err) {
    res.status(500).send('Error');
  }
};

exports.getUserProfileByEmail = async (req, res) => {
  try {
    const { email } = req.query;
    if (!email) return res.status(400).json({ error: 'Email is required' });
    const user = await User.findOne({ email }).select('-password');
    if (!user) return res.status(404).json({ error: 'User not found' });
    const userObj = user.toObject();
    if (userObj.profileImage) {
      userObj.profileImage = `${req.protocol}://${req.get('host')}/api/users/${userObj._id}/profile-image`;
    }
    res.json(userObj);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}; 