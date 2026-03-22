const mongoose = require('mongoose');

const chatSchema = new mongoose.Schema({
    transactionId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Transaction',
        required: true,
    },
    senderId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
    },
    receiverId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
    },
    message: {
        type: String,
        default: null,
    },
    senderPublicKey: {
        type: String,
        default: null,
    },
    encryptionVersion: {
        type: Number,
        default: 1,
    },
    encryptedPayloads: [{
        recipientUserId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
            required: true,
        },
        nonce: {
            type: String,
            required: true,
        },
        cipherText: {
            type: String,
            required: true,
        },
        mac: {
            type: String,
            required: true,
        }
    }],
    parentMessageId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Chat',
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

const Chat = mongoose.model('Chat', chatSchema);

module.exports = Chat;
