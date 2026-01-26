const GiftCard = require('../models/giftCard');

// Create a new gift card
exports.createGiftCard = async (req, res) => {
    try {
        const { name, value } = req.body;
        const createdBy = req.user._id; // Admin ID from auth middleware

        if (!name || !value) {
            return res.status(400).json({ message: 'Name and value are required.' });
        }

        const newGiftCard = new GiftCard({
            name,
            value,
            createdBy,
        });

        await newGiftCard.save();

        res.status(201).json({ message: 'Gift card created successfully', giftCard: newGiftCard });
    } catch (error) {
        res.status(500).json({ message: 'Error creating gift card', error: error.message });
    }
};

// Get all gift cards
exports.getGiftCards = async (req, res) => {
    try {
        const giftCards = await GiftCard.find().populate('createdBy', 'name');
        res.status(200).json(giftCards);
    } catch (error) {
        res.status(500).json({ message: 'Error fetching gift cards', error: error.message });
    }
};

// Update a gift card
exports.updateGiftCard = async (req, res) => {
    try {
        const { id } = req.params;
        const { name, value } = req.body;
        const adminId = req.user._id;

        const giftCard = await GiftCard.findById(id);

        if (!giftCard) {
            return res.status(404).json({ message: 'Gift card not found' });
        }

        if (giftCard.createdBy.toString() !== adminId) {
            return res.status(403).json({ message: 'You are not authorized to edit this gift card.' });
        }

        giftCard.name = name || giftCard.name;
        giftCard.value = value || giftCard.value;

        const updatedGiftCard = await giftCard.save();

        res.status(200).json({ message: 'Gift card updated successfully', giftCard: updatedGiftCard });
    } catch (error) {
        res.status(500).json({ message: 'Error updating gift card', error: error.message });
    }
};

// Delete a gift card
exports.deleteGiftCard = async (req, res) => {
    try {
        const { id } = req.params;
        const adminId = req.user._id;

        const giftCard = await GiftCard.findById(id);

        if (!giftCard) {
            return res.status(404).json({ message: 'Gift card not found' });
        }

        if (giftCard.createdBy.toString() !== adminId) {
            return res.status(403).json({ message: 'You are not authorized to delete this gift card.' });
        }

        await giftCard.deleteOne();

        res.status(200).json({ message: 'Gift card deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Error deleting gift card', error: error.message });
    }
};
