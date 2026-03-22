const CHAT_MESSAGE_PREFIX = 'ldchat:';

function encodeChatMessage(value = '') {
    const text = String(value ?? '');
    return `${CHAT_MESSAGE_PREFIX}${Buffer.from(text, 'utf8').toString('base64')}`;
}

function decodeChatMessage(value = '') {
    if (typeof value !== 'string' || !value.startsWith(CHAT_MESSAGE_PREFIX)) {
        return value;
    }

    try {
        return Buffer.from(value.slice(CHAT_MESSAGE_PREFIX.length), 'base64').toString('utf8');
    } catch (error) {
        return value;
    }
}

function isEncodedChatMessage(value = '') {
    return typeof value === 'string' && value.startsWith(CHAT_MESSAGE_PREFIX);
}

function normalizeStoredChatMessage(value = '') {
    const text = String(value ?? '');
    return isEncodedChatMessage(text) ? text : encodeChatMessage(text);
}

function toChatResponse(chatDoc) {
    if (!chatDoc) {
        return chatDoc;
    }

    const chat = typeof chatDoc.toObject === 'function'
        ? chatDoc.toObject()
        : { ...chatDoc };

    if (typeof chat.message === 'string') {
        chat.message = decodeChatMessage(chat.message);
    }

    if (chat.parentMessageId && typeof chat.parentMessageId === 'object') {
        chat.parentMessageId = toChatResponse(chat.parentMessageId);
    }

    return chat;
}

module.exports = {
    decodeChatMessage,
    encodeChatMessage,
    normalizeStoredChatMessage,
    toChatResponse,
};
