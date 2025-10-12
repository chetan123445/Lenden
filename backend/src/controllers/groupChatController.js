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

                const userMessageCount = groupTransaction.messageCounts.find(mc => mc.user.toString() === senderId);
                if (sender.subscription === 'free' && userMessageCount && userMessageCount.count >= 10) {
                    socket.emit('createGroupMessageError', { ...data, error: 'You have reached the maximum number of messages for a free account. Please subscribe for unlimited messages.' });
                    return;
                }

                // Check if user is still an active member of the group
                const isActiveMember = groupTransaction.members.some(member => 
                    member.user.toString() === senderId && !member.leftAt
                );

                if (!isActiveMember) {
                    socket.emit('createGroupMessageError', { 
                        ...data, 
                        error: 'You are no longer an active member of this group. Chat is disabled.' 
                    });
                    return;
                }

                let chat = new GroupChat({
                    groupTransactionId,
                    senderId,
                    message,
                    parentMessageId,
                });

                await chat.save();

                // Increment message count for the user
                if (userMessageCount) {
                    await GroupTransaction.updateOne(
                        { _id: groupTransactionId, 'messageCounts.user': senderId },
                        { $inc: { 'messageCounts.$.count': 1 } }
                    );
                } else {
                    await GroupTransaction.updateOne(
                        { _id: groupTransactionId },
                        { $push: { messageCounts: { user: senderId, count: 1 } } }
                    );
                }

                chat = await GroupChat.findById(chat._id)
                    .populate('senderId', 'name')
                    .populate({
                        path: 'parentMessageId',
                        populate: {
                            path: 'senderId',
                            select: 'name'
                        }
                    });

                const updatedGroupTransaction = await GroupTransaction.findById(groupTransactionId).populate('messageCounts.user', 'name');

                io.to(groupTransactionId).emit('newGroupMessage', {chat, messageCounts: updatedGroupTransaction.messageCounts});
            } catch (error) {
                console.error('Error in createGroupMessage socket handler:', error);
                socket.emit('createGroupMessageError', { ...data, error: 'An error occurred while sending the message.' });
            }
        });

        // Edit group message
        socket.on('editGroupMessage', async (data) => {
            try {
                const { messageId, userId, message } = data;

                const chat = await GroupChat.findOne({
                    _id: messageId,
                    senderId: userId
                });

                if (!chat) {
                    socket.emit('editGroupMessageError', { ...data, error: 'Message not found or not authorized to edit' });
                    return;
                }

                // Check if user is still an active member of the group
                const groupTransaction = await GroupTransaction.findById(chat.groupTransactionId);
                if (groupTransaction) {
                    const isActiveMember = groupTransaction.members.some(member => 
                        member.user.toString() === userId && !member.leftAt
                    );

                    if (!isActiveMember) {
                        socket.emit('editGroupMessageError', { 
                            ...data, 
                            error: 'You are no longer an active member of this group. Chat is disabled.' 
                        });
                        return;
                    }
                }

                // Check if message is within 2 minutes of creation
                const now = new Date();
                const messageTime = new Date(chat.createdAt);
                const timeDiff = (now - messageTime) / (1000 * 60); // in minutes

                if (timeDiff > 2) {
                    socket.emit('editGroupMessageError', { ...data, error: 'Cannot edit message after 2 minutes' });
                    return;
                }

                chat.message = message;
                chat.isEdited = true;
                await chat.save();

                const updatedChat = await GroupChat.findById(chat._id)
                    .populate('senderId', 'name')
                    .populate({
                        path: 'parentMessageId',
                        populate: {
                            path: 'senderId',
                            select: 'name'
                        }
                    });

                io.to(chat.groupTransactionId.toString()).emit('groupMessageUpdated', updatedChat);
            } catch (error) {
                console.error('Error in editGroupMessage socket handler:', error);
                socket.emit('editGroupMessageError', { ...data, error: 'An error occurred while editing the message.' });
            }
        });

        // Delete group message
        socket.on('deleteGroupMessage', async (data) => {
            try {
                const { messageId, userId, forEveryone } = data;

                const chat = await GroupChat.findById(messageId);

                if (!chat) {
                    socket.emit('deleteGroupMessageError', { ...data, error: 'Message not found' });
                    return;
                }

                // Check if user is still an active member of the group
                const groupTransaction = await GroupTransaction.findById(chat.groupTransactionId);
                if (groupTransaction) {
                    const isActiveMember = groupTransaction.members.some(member => 
                        member.user.toString() === userId && !member.leftAt
                    );

                    if (!isActiveMember) {
                        socket.emit('deleteGroupMessageError', { 
                            ...data, 
                            error: 'You are no longer an active member of this group. Chat is disabled.' 
                        });
                        return;
                    }
                }

                if (forEveryone && chat.senderId.toString() !== userId) {
                    socket.emit('deleteGroupMessageError', { ...data, error: 'Not authorized to delete for everyone' });
                    return;
                }

                if (forEveryone) {
                    await GroupChat.findByIdAndDelete(messageId);
                } else {
                    if (!chat.deletedFor.includes(userId)) {
                        chat.deletedFor.push(userId);
                        await chat.save();
                    }
                }

                io.to(chat.groupTransactionId.toString()).emit('groupMessageDeleted', {
                    messageId,
                    groupTransactionId: chat.groupTransactionId,
                    forEveryone
                });
            } catch (error) {
                console.error('Error in deleteGroupMessage socket handler:', error);
                socket.emit('deleteGroupMessageError', { ...data, error: 'An error occurred while deleting the message.' });
            }
        });

        // Add group reaction
        socket.on('addGroupReaction', async (data) => {
            try {
                const { messageId, userId, emoji } = data;

                const chat = await GroupChat.findById(messageId);

                if (!chat) {
                    socket.emit('addGroupReactionError', { ...data, error: 'Message not found' });
                    return;
                }

                // Check if user is still an active member of the group
                const groupTransaction = await GroupTransaction.findById(chat.groupTransactionId);
                if (groupTransaction) {
                    const isActiveMember = groupTransaction.members.some(member => 
                        member.user.toString() === userId && !member.leftAt
                    );

                    if (!isActiveMember) {
                        socket.emit('addGroupReactionError', { 
                            ...data, 
                            error: 'You are no longer an active member of this group. Chat is disabled.' 
                        });
                        return;
                    }
                }

                // Remove existing reaction from this user for this message
                chat.reactions = chat.reactions.filter(reaction => reaction.userId.toString() !== userId);

                // Add new reaction
                chat.reactions.push({ emoji, userId });
                await chat.save();

                const updatedChat = await GroupChat.findById(chat._id)
                    .populate('senderId', 'name')
                    .populate({
                        path: 'parentMessageId',
                        populate: {
                            path: 'senderId',
                            select: 'name'
                        }
                    });

                io.to(chat.groupTransactionId.toString()).emit('groupMessageUpdated', updatedChat);
            } catch (error) {
                console.error('Error in addGroupReaction socket handler:', error);
                socket.emit('addGroupReactionError', { ...data, error: 'An error occurred while adding the reaction.' });
            }
        });
    });

    const exports = {};

    exports.getGroupMessages = async (req, res) => {
        try {
            const { groupTransactionId } = req.params;
            const { userId } = req.query;

            // First check if the user is still an active member
            const groupTransaction = await GroupTransaction.findById(groupTransactionId).populate('messageCounts.user', 'name');
            if (!groupTransaction) {
                return res.status(404).json({ message: 'Group transaction not found' });
            }

            const isActiveMember = groupTransaction.members.some(member => 
                member.user.toString() === userId && !member.leftAt
            );

            if (!isActiveMember) {
                return res.status(403).json({ 
                    message: 'You are no longer an active member of this group. Chat access denied.' 
                });
            }

            // Get all active member IDs to filter messages
            const activeMemberIds = groupTransaction.members
                .filter(member => !member.leftAt)
                .map(member => member.user);

            const messages = await GroupChat.find({
                groupTransactionId,
                deletedFor: { $ne: userId },
                senderId: { $in: activeMemberIds } // Only show messages from active members
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

            res.status(200).json({messages, messageCounts: groupTransaction.messageCounts});
        } catch (error) {
            res.status(500).json({ message: 'Error fetching group messages', error });
        }
    };

    return exports;
};