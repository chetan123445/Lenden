const Note = require('../models/note');

// Create a new note
exports.createNote = async (req, res) => {
  try {
    const { title, content } = req.body;
    if (!title || !content) return res.status(400).json({ error: 'Title and content are required' });
    const user = req.user;
    const role = user.role === 'admin' ? 'Admin' : 'User';
    const note = await Note.create({ user: user.id, role, title, content });
    res.status(201).json({ note });
  } catch (err) {
    res.status(500).json({ error: 'Failed to create note', details: err.message });
  }
};

// Get all notes for the logged-in user/admin
exports.getNotes = async (req, res) => {
  try {
    const user = req.user;
    const role = user.role === 'admin' ? 'Admin' : 'User';
    const notes = await Note.find({ user: user.id, role }).sort({ updatedAt: -1 });
    res.json({ notes });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch notes', details: err.message });
  }
};

// Update a note
exports.updateNote = async (req, res) => {
  try {
    const { id } = req.params;
    const { title, content } = req.body;
    if (!title && !content) return res.status(400).json({ error: 'Title or content required' });
    const user = req.user;
    const role = user.role === 'admin' ? 'Admin' : 'User';
    const update = {};
    if (title) update.title = title;
    if (content) update.content = content;
    const note = await Note.findOneAndUpdate({ _id: id, user: user.id, role }, update, { new: true });
    if (!note) return res.status(404).json({ error: 'Note not found' });
    res.json({ note });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update note', details: err.message });
  }
};

// Delete a note
exports.deleteNote = async (req, res) => {
  try {
    const { id } = req.params;
    const user = req.user;
    const role = user.role === 'admin' ? 'Admin' : 'User';
    const note = await Note.findOneAndDelete({ _id: id, user: user.id, role });
    if (!note) return res.status(404).json({ error: 'Note not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete note', details: err.message });
  }
}; 