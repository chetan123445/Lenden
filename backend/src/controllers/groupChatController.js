const GroupChat = require('../models/groupChat');
const GroupTransaction = require('../models/groupTransaction');
const User = require('../models/user');

module.exports = (io) => {
    let users = {};

    io.on('connection', (socket) => {
        socket.on('joinGroup', (groupTransactionId) => {
            if (groupTransactionId) {
                socket.join(groupTransactionId);
            }
        });

        socket.on('createGroupMessage', async (data) => {
            try {
                const { groupTransactionId, senderId, message, parentMessageId } = data;

                const groupTransaction = await GroupTransaction.findById(groupTransactionId);
                if (!groupTransaction) {
                    socket.emit('createGroupMessageError', { ...data, error: 'Group transaction not found' });
                    return;
                }

                const sender = await User.findById(senderId);
                if (!sender) {
                    socket.emit('createGroupMessageError', { ...data, error: 'User not found' });
                    return;
                }

                let chat = new GroupChat({
                    groupTransactionId,
                    senderId,
                    message,
                    parentMessageId,
                });

                await chat.save();

                chat = await GroupChat.findById(chat._id)
                    .populate('senderId', 'name')
                    .populate({
                        path: 'parentMessageId',
                        populate: {
                            path: 'senderId',
                            select: 'name'
                        }
                    });

                io.to(groupTransactionId).emit('newGroupMessage', chat);
            } catch (error) {
                console.error('Error in createGroupMessage socket handler:', error);
                socket.emit('createGroupMessageError', { ...data, error: 'An error occurred while sending the message.' });
            }
        });

        // Add handlers for edit, delete, reactions for group chat messages as well
        // For brevity, I will omit them here but they should be implemented similarly to chatController.js
    });

    const exports = {};

    exports.getGroupMessages = async (req, res) => {
        try {
            const { groupTransactionId } = req.params;
            const { userId } = req.query;

            const messages = await GroupChat.find({
                groupTransactionId,
                deletedFor: { $ne: userId }
            })
            .populate('senderId', 'name')
            .populate({
                path: 'parentMessageId',
                populate: {
                    path: 'senderId',
                    select: 'name'
                }
            })
            .sort({ createdAt: 'asc' });

            res.status(200).json(messages);
        } catch (error) {
            res.status(500).json({ message: 'Error fetching group messages', error });
        }
    };

    return exports;
};