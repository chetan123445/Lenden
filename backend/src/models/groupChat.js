const mongoose = require('mongoose');

const groupChatSchema = new mongoose.Schema({
    groupTransactionId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'GroupTransaction',
        required: true,
    },
    senderId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
    },
    message: {
        type: String,
        required: true,
    },
    parentMessageId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'GroupChat',
        default: null,
    },
    reactions: [{
        emoji: String,
        userId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User'
        }
    }],
    isEdited: {
        type: Boolean,
        default: false,
    },
    deletedFor: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    }]
}, { timestamps: true });

const GroupChat = mongoose.model('GroupChat', groupChatSchema);

module.exports = GroupChat;