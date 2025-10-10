import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../user/session.dart';
import '../api_config.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final String transactionId;
  final String otherUserId;

  const ChatPage({
    Key? key,
    required this.transactionId,
    required this.otherUserId,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<dynamic> _messages = [];
  bool _isLoading = true;
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  String? _currentUserId;
  bool _showEmojiPicker = false;
  dynamic _replyingTo;
  dynamic _editingMessage;
  late IO.Socket socket;
  Map<String, dynamic>? _otherUser;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<SessionProvider>(context, listen: false).user;
    _currentUserId = user?['_id'];
    _fetchMessages();
    _initSocket();
    _fetchOtherUserDetails();
  }

  Future<void> _fetchOtherUserDetails() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/users/${widget.otherUserId}'),
        headers: {
          'Authorization': 'Bearer ${Provider.of<SessionProvider>(context, listen: false).token}',
        },
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _otherUser = jsonDecode(response.body);
          });
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  void _initSocket() {
    socket = IO.io(ApiConfig.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();
    socket.onConnect((_) {
      socket.emit('join', _currentUserId);
    });

    socket.on('newMessage', (data) {
      if (data['transactionId'] == widget.transactionId) {
        if (!_messages.any((m) => m['_id'] == data['_id'])) {
          if (mounted) {
            setState(() {
              _messages.add(data);
            });
          }
        }
      }
    });

    socket.on('messageUpdated', (data) {
      if (data['transactionId'] == widget.transactionId) {
        final index = _messages.indexWhere((m) => m['_id'] == data['_id']);
        if (index != -1) {
          if (mounted) {
            setState(() {
              _messages[index] = data;
            });
          }
        }
      }
    });

    socket.on('messageDeleted', (data) {
      if (data['transactionId'] == widget.transactionId) {
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m['_id'] == data['messageId']);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    socket.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/chat/messages/${widget.transactionId}?userId=$_currentUserId'),
        headers: {
          'Authorization': 'Bearer ${Provider.of<SessionProvider>(context, listen: false).token}',
        },
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _messages = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    if (_editingMessage != null) {
      _editMessage();
      return;
    }

    socket.emit('createMessage', {
      'transactionId': widget.transactionId,
      'senderId': _currentUserId,
      'receiverId': widget.otherUserId,
      'message': _messageController.text.trim(),
      'parentMessageId': _replyingTo?['_id'],
    });

    _messageController.clear();
    setState(() {
      _replyingTo = null;
    });
  }

  void _editMessage() {
    if (_messageController.text.trim().isEmpty) return;
    final message = {
      'messageId': _editingMessage['_id'],
      'userId': _currentUserId,
      'message': _messageController.text.trim(),
    };

    socket.emit('editMessage', message);

    _messageController.clear();
    setState(() {
      _editingMessage = null;
    });
  }

  void _deleteMessage(String messageId, bool forEveryone) {
    final message = {
      'messageId': messageId,
      'userId': _currentUserId,
      'forEveryone': forEveryone,
    };

    socket.emit('deleteMessage', message);
  }

  void _addReaction(String messageId, String emoji) {
    final message = {
      'messageId': messageId,
      'userId': _currentUserId,
      'emoji': emoji,
    };

    socket.emit('addReaction', message);
  }

  void _onEmojiIconPressed() {
    if (_showEmojiPicker) {
      _messageFocusNode.requestFocus();
    } else {
      _messageFocusNode.unfocus();
    }
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  void _showContextMenu(BuildContext context, dynamic message, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15.0),
            ),
            child: Wrap(
              children: <Widget>[
                if (isMe)
                  ListTile(
                    leading: Icon(Icons.edit, color: Colors.blueAccent),
                    title: Text('Edit'),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _editingMessage = message;
                        _messageController.text = message['message'];
                        _messageFocusNode.requestFocus();
                      });
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.reply, color: Colors.greenAccent),
                  title: Text('Reply'),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _replyingTo = message;
                      _messageFocusNode.requestFocus();
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.emoji_emotions_outlined, color: Colors.orangeAccent),
                  title: Text('React'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showReactionPicker(message['_id']);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: Text('Delete for me'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteMessage(message['_id'], false);
                  },
                ),
                if (isMe)
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined, color: Colors.red),
                    title: Text('Delete for everyone'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _deleteMessage(message['_id'], true);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReactionPicker(String messageId) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Container(
            height: 300,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Expanded(
                  child: EmojiPicker(
                    onEmojiSelected: (category, emoji) {
                      Navigator.of(context).pop();
                      _addReaction(messageId, emoji.emoji);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_showEmojiPicker) {
          setState(() {
            _showEmojiPicker = false;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: ClipPath(
            clipper: WaveClipper(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
            ),
          ),
          title: _otherUser == null
              ? Text('Chat')
              : Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: ClipOval(
                        child: (_otherUser!['profileImage'] != null)
                          ? Image.network(
                              '${ApiConfig.baseUrl}/api/users/${_otherUser!['_id']}/profile-image',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                final gender = _otherUser?['gender'] ?? 'Other';
                                if (gender == 'Male') {
                                  return Image.asset('assets/Male.png');
                                } else if (gender == 'Female') {
                                  return Image.asset('assets/Female.png');
                                } else {
                                  return Image.asset('assets/Other.png');
                                }
                              },
                            )
                          : Image.asset(
                              'assets/${_otherUser?['gender'] == 'Male' ? 'Male' : _otherUser?['gender'] == 'Female' ? 'Female' : 'Other'}.png',
                            ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_otherUser!['name'] ?? 'User'),
                        Text(
                          _otherUser!['email'] ?? '',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages.reversed.toList()[index];
                        final sender = message['senderId'];
                        final isMe = sender is Map && sender['_id'] == _currentUserId;
                        return _buildMessageBubble(message, isMe);
                      },
                    ),
            ),
            if (_replyingTo != null) _buildReplyingToBanner(),
            if (_editingMessage != null) _buildEditingBanner(),
            _buildMessageInput(),
            if (_showEmojiPicker) _buildEmojiPicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(dynamic message, bool isMe) {
    if (message['createdAt'] == null) {
      return const SizedBox.shrink();
    }
    final createdAt = DateTime.parse(message['createdAt']).toLocal();
    final formattedTime = DateFormat.jm().format(createdAt);
    final hasReactions = message['reactions'] != null && message['reactions'].isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (message['parentMessageId'] != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Replying to ${message['parentMessageId']['senderId']['name']}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                  Text(message['parentMessageId']['message'], style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe)
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey),
                  onPressed: () => _showContextMenu(context, message, isMe),
                ),
              Flexible(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        gradient: const LinearGradient(
                          colors: [Colors.orange, Colors.white, Colors.green],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Container(
                        padding: EdgeInsets.fromLTRB(12, 10, 12, hasReactions ? 25 : 10),
                        decoration: BoxDecoration(
                          color: isMe ? Color(0xFFE8F5E9) : Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['message'],
                              style: TextStyle(color: Colors.black, fontSize: 16),
                            ),
                            SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(formattedTime, style: TextStyle(fontSize: 10, color: Colors.black54)),
                                if (message['isEdited'] == true)
                                  Text(' (edited)', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black54)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (hasReactions)
                      Positioned(
                        bottom: -12,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: Offset(0, 1))],
                          ),
                          child: Wrap(
                            spacing: 5,
                            children: message['reactions'].map<Widget>((reaction) {
                              return Text(reaction['emoji'], style: TextStyle(fontSize: 14));
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (isMe)
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey),
                  onPressed: () => _showContextMenu(context, message, isMe),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.white, Colors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      margin: EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(_showEmojiPicker ? Icons.close : Icons.emoji_emotions_outlined, color: Colors.grey),
              onPressed: _onEmojiIconPressed,
            ),
            Expanded(
              child: TextField(
                focusNode: _messageFocusNode,
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message',
                  border: InputBorder.none,
                ),
                onTap: () {
                  if (_showEmojiPicker) {
                    setState(() {
                      _showEmojiPicker = false;
                    });
                  }
                },
              ),
            ),
            IconButton(
              icon: Icon(Icons.send, color: Colors.blue),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return EmojiPicker(
      onEmojiSelected: (category, emoji) {
        _messageController.text += emoji.emoji;
      },
      onBackspacePressed: () {
        _messageController.text =
            _messageController.text.characters.skipLast(1).toString();
      },
    );
  }

  Widget _buildReplyingToBanner() {
    return Container(
      padding: EdgeInsets.all(8),
      color: Colors.grey[200],
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Replying to ${(_replyingTo['senderId'] is Map ? _replyingTo['senderId']['name'] : '')}', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_replyingTo['message'], maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              setState(() {
                _replyingTo = null;
              });
            },
          )
        ],
      ),
    );
  }

  Widget _buildEditingBanner() {
    return Container(
      padding: EdgeInsets.all(8),
      color: Colors.grey[200],
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Editing message', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_editingMessage['message'], maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              setState(() {
                _editingMessage = null;
                _messageController.clear();
              });
            },
          )
        ],
      ),
    );
  }
}

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 50);
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2.2, size.height - 30.0);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);

    var secondControlPoint =
        Offset(size.width - (size.width / 3.25), size.height - 65);
    var secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);

    path.lineTo(size.width, size.height - 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}