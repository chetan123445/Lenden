const Feedback = require('../models/feedback');

exports.submitFeedback = async (req, res) => {
  try {
    const { feedback } = req.body;
    if (!feedback) {
      return res.status(400).json({ error: 'Feedback is required.' });
    }
    const newFeedback = new Feedback({
      user: req.user._id,
      feedback,
    });
    await newFeedback.save();
    res.json({ success: true, message: 'Feedback submitted successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getUserFeedbacks = async (req, res) => {
  try {
    const feedbacks = await Feedback.find({ user: req.user._id }).sort({ createdAt: -1 });
    res.json({ feedbacks });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
         

