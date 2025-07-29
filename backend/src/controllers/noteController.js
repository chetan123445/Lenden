const Note = require('../models/note');

// Create a new note
exports.createNote = async (req, res) => {
  try {
    const { title, content } = req.body;
    console.log('📝 Creating note:', { title, content });
    console.log('👤 User from JWT:', req.user);
    
    if (!title || !content) return res.status(400).json({ error: 'Title and content are required' });
    const user = req.user;
    const role = user.role === 'admin' ? 'Admin' : 'User';
    const userId = user._id || user.id; // Handle both user and admin JWT structures
    
    console.log('🔧 Note creation details:', { userId, role, title, content });
    
    const note = await Note.create({ user: userId, role, title, content });
    console.log('✅ Note created successfully:', note._id);
    res.status(201).json({ note });
  } catch (err) {
    console.error('❌ Failed to create note:', err.message);
    res.status(500).json({ error: 'Failed to create note', details: err.message });
  }
};

// Get all notes for the logged-in user/admin
exports.getNotes = async (req, res) => {
  try {
    const user = req.user;
    const role = user.role === 'admin' ? 'Admin' : 'User';
    const userId = user._id || user.id; // Handle both user and admin JWT structures
    
    console.log('📋 Fetching notes for:', { userId, role });
    
    const notes = await Note.find({ user: userId, role }).sort({ updatedAt: -1 });
    console.log('📋 Found notes count:', notes.length);
    res.json({ notes });
  } catch (err) {
    console.error('❌ Failed to fetch notes:', err.message);
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
    const userId = user._id || user.id; // Handle both user and admin JWT structures
    const update = {};
    if (title) update.title = title;
    if (content) update.content = content;
    const note = await Note.findOneAndUpdate({ _id: id, user: userId, role }, update, { new: true });
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
    const userId = user._id || user.id; // Handle both user and admin JWT structures
    const note = await Note.findOneAndDelete({ _id: id, user: userId, role });
    if (!note) return res.status(404).json({ error: 'Note not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete note', details: err.message });
  }
}; 