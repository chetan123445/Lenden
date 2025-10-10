const Chat = require('../models/chat');
const Transaction = require('../models/transaction');
const User = require('../models/user');

module.exports = (io) => {
    let users = {};

    io.on('connection', (socket) => {
        socket.on('join', (userId) => {
            if (userId) {
                users[userId] = socket.id;
                socket.join(userId);
            }
        });

        socket.on('disconnect', () => {
            for (let userId in users) {
                if (users[userId] === socket.id) {
                    delete users[userId];
                    break;
                }
            }
        });

        socket.on('createMessage', async (data) => {
            try {
                const { transactionId, senderId, receiverId, message, parentMessageId } = data;

                const transaction = await Transaction.findById(transactionId);
                if (!transaction) {
                    socket.emit('createMessageError', { ...data, error: 'Transaction not found' });
                    return;
                }

                const sender = await User.findById(senderId);
                const receiver = await User.findById(receiverId);
                if (!sender || !receiver) {
                    socket.emit('createMessageError', { ...data, error: 'User not found' });
                    return;
                }

                let chat = new Chat({
                    transactionId,
                    senderId,
                    receiverId,
                    message,
                    parentMessageId,
                });

                await chat.save();

                // Increment message count on the transaction
                await Transaction.findByIdAndUpdate(transactionId, { $inc: { messageCount: 1 } });

                chat = await Chat.findById(chat._id)
                    .populate('senderId', 'name')
                    .populate('receiverId', 'name')
                    .populate({
                        path: 'parentMessageId',
                        populate: {
                            path: 'senderId',
                            select: 'name'
                        }
                    });

                io.to(senderId).to(receiverId).emit('newMessage', chat);
            } catch (error) {
                console.error('Error in createMessage socket handler:', error);
                socket.emit('createMessageError', { ...data, error: 'An error occurred while sending the message.' });
            }
        });

        socket.on('editMessage', async (data) => {
            try {
                const { messageId, userId, message } = data;
                let chat = await Chat.findById(messageId);
                if (!chat || chat.senderId.toString() !== userId) return;

                const senderIdStr = chat.senderId.toString();
                const receiverIdStr = chat.receiverId.toString();

                const now = new Date();
                const messageTime = new Date(chat.createdAt);
                const diffInMinutes = (now.getTime() - messageTime.getTime()) / 60000;

                if (diffInMinutes > 2) {
                    socket.emit('editMessageError', { messageId, error: 'You can no longer edit this message.' });
                    return;
                }

                chat.message = message;
                chat.isEdited = true;
                await chat.save();
                let populatedChat = await Chat.findById(chat._id)
                    .populate('senderId', 'name')
                    .populate('receiverId', 'name')
                    .populate({
                        path: 'parentMessageId',
                        populate: {
                            path: 'senderId',
                            select: 'name'
                        }
                    });

                io.to(senderIdStr).to(receiverIdStr).emit('messageUpdated', populatedChat);
            } catch (error) {
                console.error('Error in editMessage socket handler:', error);
            }
        });

        socket.on('deleteMessage', async (data) => {
            try {
                const { messageId, userId, forEveryone } = data;
                const chat = await Chat.findById(messageId);
                if (!chat) return;

                const senderId = chat.senderId.toString();
                const receiverId = chat.receiverId.toString();

                if (forEveryone && senderId === userId) {
                    await Chat.findByIdAndDelete(messageId);
                    io.to(senderId).to(receiverId).emit('messageDeleted', { messageId, forEveryone: true, transactionId: chat.transactionId });
                } else {
                    chat.deletedFor.push(userId);
                    await chat.save();
                    io.to(userId).emit('messageDeleted', { messageId, forEveryone: false, transactionId: chat.transactionId });
                }
            } catch (error) {
                console.error('Error in deleteMessage socket handler:', error);
            }
        });

        socket.on('addReaction', async (data) => {
            try {
                const { messageId, userId, emoji } = data;
                let chat = await Chat.findById(messageId);
                if (!chat) return;

                const senderIdStr = chat.senderId.toString();
                const receiverIdStr = chat.receiverId.toString();

                const existingReactionIndex = chat.reactions.findIndex(r => r.userId.toString() === userId);

                if (existingReactionIndex > -1) {
                    if (chat.reactions[existingReactionIndex].emoji === emoji) {
                        chat.reactions.splice(existingReactionIndex, 1);
                    } else {
                        chat.reactions[existingReactionIndex].emoji = emoji;
                    }
                } else {
                    chat.reactions.push({ userId, emoji });
                }

                await chat.save();
                let populatedChat = await Chat.findById(chat._id)
                    .populate('senderId', 'name')
                    .populate('receiverId', 'name')
                    .populate({
                        path: 'parentMessageId',
                        populate: {
                            path: 'senderId',
                            select: 'name'
                        }
                    });

                io.to(senderIdStr).to(receiverIdStr).emit('messageUpdated', populatedChat);
            } catch (error) {
                console.error('Error in addReaction socket handler:', error);
            }
        });
    });

    const exports = {};

    exports.getMessages = async (req, res) => {
        try {
            const { transactionId } = req.params;
            const { userId } = req.query;

            const messages = await Chat.find({
                transactionId,
                deletedFor: { $ne: userId }
            })
            .populate('senderId', 'name')
            .populate('receiverId', 'name')
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
            res.status(500).json({ message: 'Error fetching messages', error });
        }
    };

    return exports;
};