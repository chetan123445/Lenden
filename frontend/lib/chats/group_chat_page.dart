import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../user/session.dart';
import '../api_config.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:intl/intl.dart';
import 'dart:math';
import '../widgets/subscription_prompt.dart';

class GroupChatPage extends StatefulWidget {
  final String groupTransactionId;
  final String groupTitle;
  final List<dynamic> members;

  const GroupChatPage({
    Key? key,
    required this.groupTransactionId,
    required this.groupTitle,
    required this.members,
  }) : super(key: key);

  @override
  _GroupChatPageState createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  List<dynamic> _messages = [];
  Map<String, int> _messageCounts = {};
  bool _isLoading = true;
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  String? _currentUserId;
  bool _showEmojiPicker = false;
  dynamic _replyingTo;
  dynamic _editingMessage;
  late IO.Socket socket;
  Map<String, Color> _userColors = {};
  final Random _random = Random();
  bool _isActiveMember = true;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<SessionProvider>(context, listen: false).user;
    _currentUserId = user?['_id'];

    for (var i = 0; i < widget.members.length; i++) {
      final member = widget.members[i];
      final memberId = member is Map ? member['_id'] : member;
      if (memberId != null && !_userColors.containsKey(memberId)) {
        _userColors[memberId] = _getNoteColor(i);
      }
    }

    _fetchMessages();
    _initSocket();
  }

  Color _getUserColor(String userId) {
    if (!_userColors.containsKey(userId)) {
      _userColors[userId] = _getNoteColor(_userColors.length);
    }
    return _userColors[userId]!;
  }

  Color _getNoteColor(int index) {
    final colors = [
      Color(0xFFFFF4E6), // Cream
      Color(0xFFE8F5E9), // Light green
      Color(0xFFFCE4EC), // Light pink
      Color(0xFFE3F2FD), // Light blue
      Color(0xFFFFF9C4), // Light yellow
      Color(0xFFF3E5F5), // Light purple
      Color(0xFFE0F2F1), // Light teal
      Color(0xFFFFF3E0), // Light orange
      Color(0xFFF1F8E9), // Light lime
      Color(0xFFE8EAF6), // Light indigo
    ];
    return colors[index % colors.length];
  }

  void _initSocket() {
    socket = IO.io(ApiConfig.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();
    socket.onConnect((_) {
      socket.emit('joinGroup', widget.groupTransactionId);
    });

    socket.on('newGroupMessage', (data) {
      final chat = data['chat'];
      final messageCounts = data['messageCounts'];
      if (chat['groupTransactionId'] == widget.groupTransactionId) {
        if (!_messages.any((m) => m['_id'] == chat['_id'])) {
          if (mounted) {
            setState(() {
              _messages.add(chat);
              if (messageCounts != null) {
                for (var item in messageCounts) {
                  _messageCounts[item['user']['_id']] = item['count'];
                }
              }
            });
          }
        }
      }
    });

    socket.on('groupMessageUpdated', (data) {
      if (data['groupTransactionId'] == widget.groupTransactionId) {
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

    socket.on('groupMessageDeleted', (data) {
      if (data['groupTransactionId'] == widget.groupTransactionId) {
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m['_id'] == data['messageId']);
          });
        }
      }
    });

    // Handle error events
    socket.on('createGroupMessageError', (data) {
      if (data['groupTransactionId'] == widget.groupTransactionId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Failed to send message'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });

    socket.on('editGroupMessageError', (data) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Failed to edit message'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    socket.on('deleteGroupMessageError', (data) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Failed to delete message'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    socket.on('addGroupReactionError', (data) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Failed to add reaction'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
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
        Uri.parse('${ApiConfig.baseUrl}/api/group-chat/messages/${widget.groupTransactionId}?userId=$_currentUserId'),
        headers: {
          'Authorization': 'Bearer ${Provider.of<SessionProvider>(context, listen: false).token}',
        },
      );
      if (response.statusCode == 200) {
        if (mounted) {
          final body = jsonDecode(response.body);
          setState(() {
            _messages = body['messages'];
            final messageCounts = body['messageCounts'];
            if (messageCounts != null) {
              for (var item in messageCounts) {
                _messageCounts[item['user']['_id']] = item['count'];
              }
            }
            _isLoading = false;
            _isActiveMember = true;
          });
        }
      } else if (response.statusCode == 403) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isActiveMember = false;
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
    final session = Provider.of<SessionProvider>(context, listen: false);
    if (!session.isSubscribed) {
      final messageCount = _messageCounts[_currentUserId] ?? 0;
      if (messageCount >= 10) {
        showSubscriptionPrompt(context);
        return;
      }
    }

    if (_messageController.text.trim().isEmpty) return;

    if (!_isActiveMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are no longer an active member of this group. Chat is disabled.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_editingMessage != null) {
      _editMessage();
      return;
    }

    socket.emit('createGroupMessage', {
      'groupTransactionId': widget.groupTransactionId,
      'senderId': _currentUserId,
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

    socket.emit('editGroupMessage', message);

    _messageController.clear();
    setState(() {
      _editingMessage = null;
    });
  }

  void _showMembersDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFFFAF9F6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAF9F6),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with tricolor border
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.orange, Colors.white, Colors.green],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.group, color: Colors.black87, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Group Members',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.close, color: Colors.black87, size: 20),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  
                  // Members list with tricolor borders
                  Container(
                    constraints: BoxConstraints(maxHeight: 400),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: widget.members.length,
                      itemBuilder: (context, index) {
                        final member = widget.members[index];
                        final memberId = member is Map ? member['_id'] : member;
                        final messageCount = _messageCounts[memberId] ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Colors.orange, Colors.white, Colors.green],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: _getNoteColor(index + 1), // Unique color for each member
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: _getUserColor(memberId ?? member['email']).withOpacity(0.8),
                                child: Text(
                                  (member['email'] ?? 'U')[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                member['email'] ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                'Messages: $messageCount',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              trailing: member['leftAt'] != null 
                                ? Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Left',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Active',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Footer
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '${widget.members.length} members',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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

  void _deleteMessage(String messageId, bool forEveryone) {
    final message = {
      'messageId': messageId,
      'userId': _currentUserId,
      'forEveryone': forEveryone,
    };

    socket.emit('deleteGroupMessage', message);
  }

  void _addReaction(String messageId, String emoji) {
    final message = {
      'messageId': messageId,
      'userId': _currentUserId,
      'emoji': emoji,
    };

    socket.emit('addGroupReaction', message);
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

  void _showMessageInfo(dynamic message) {
    final createdAt = DateTime.parse(message['createdAt']).toLocal();
    final formattedDate = DateFormat.yMMMMd().format(createdAt);
    final formattedTime = DateFormat.jm().format(createdAt);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [Colors.blue.shade200, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Icon(Icons.info_outline, color: Colors.white, size: 40),
                ),
                Text(
                  'Message Details',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.calendar_today, 'Date', formattedDate),
                      SizedBox(height: 8),
                      _buildInfoRow(Icons.access_time, 'Time', formattedTime),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('CLOSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        SizedBox(width: 16),
        Text(
          '$label:',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.end,
          ),
        ),
      ],
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
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFFFAF9F6),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(widget.groupTitle, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: Icon(Icons.more_vert, color: Colors.black),
              onPressed: _showMembersDialog,
            )
          ],
        ),
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipPath(
                clipper: TopWaveClipper(),
                child: Container(
                  height: 120,
                  color: const Color(0xFF00B4D8),
                ),
              ),
            ),
            Column(
              children: [
                SizedBox(height: 120),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _isActiveMember
                          ? ListView.builder(
                              reverse: true,
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages.reversed.toList()[index];
                                final sender = message['senderId'];
                                final isMe = sender is Map && sender['_id'] == _currentUserId;
                                return _buildMessageBubble(message, isMe, index);
                              },
                            )
                          : _buildInactiveMemberWidget(),
                ),
                if (_isActiveMember)
                  if (_replyingTo != null) _buildReplyingToBanner(),
                if (_isActiveMember)
                  if (_editingMessage != null) _buildEditingBanner(),
                if (_isActiveMember) _buildMessageInput(),
                if (_isActiveMember)
                  if (_showEmojiPicker) _buildEmojiPicker(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveMemberWidget() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_accounts, size: 60, color: Colors.red.withOpacity(0.8)),
            const SizedBox(height: 20),
            Text(
              'You are no longer a member of this group.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Chat is disabled.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(dynamic message, bool isMe, int index) {
    if (message['createdAt'] == null) {
      return const SizedBox.shrink();
    }
    final createdAt = DateTime.parse(message['createdAt']).toLocal();
    final now = DateTime.now();
    final isToday = createdAt.day == now.day && createdAt.month == now.month && createdAt.year == now.year;

    String formattedTimestamp;
    if (isToday) {
      formattedTimestamp = DateFormat.jm().format(createdAt);
    } else {
      formattedTimestamp = DateFormat('MMM d, yyyy, h:mm a').format(createdAt);
    }
    final hasReactions = message['reactions'] != null && message['reactions'].isNotEmpty;
    final senderName = message['senderId']?['name'] ?? 'Unknown';
    final senderId = message['senderId']?['_id'] ?? 'unknown';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 12.0, bottom: 4.0),
              child: Text(
                senderName,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
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
                  Text('Replying to ${message['parentMessageId']?['senderId']?['name'] ?? ''}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                  Text(message['parentMessageId']?['message'] ?? '', style: TextStyle(color: Colors.black54)),
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
                          color: isMe ? const Color(0xFFE8F5E9) : _getUserColor(senderId),
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
                                Text(formattedTimestamp, style: TextStyle(fontSize: 10, color: Colors.black54)),
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
              icon: Icon(_showEmojiPicker ? Icons.close : Icons.emoji_emotions_outlined, color: _isActiveMember ? Colors.grey : Colors.grey.withOpacity(0.3)),
              onPressed: _isActiveMember ? _onEmojiIconPressed : null,
            ),
            Expanded(
              child: TextField(
                focusNode: _messageFocusNode,
                controller: _messageController,
                enabled: _isActiveMember,
                decoration: InputDecoration(
                  hintText: _isActiveMember ? 'Type a message' : 'Chat disabled - You left the group',
                  border: InputBorder.none,
                ),
                onTap: () {
                  if (_showEmojiPicker) {
                    setState(() {
                      _showEmojiPicker = false;
                    });
                  }
                  if (!_isActiveMember) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('You are no longer an active member of this group. Chat is disabled.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
            ),
            IconButton(
              icon: Icon(Icons.send, color: _isActiveMember ? Colors.blue : Colors.grey.withOpacity(0.3)),
              onPressed: _isActiveMember ? _sendMessage : null,
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
                if (isMe && _isActiveMember && DateTime.now().difference(DateTime.parse(message['createdAt'])).inMinutes < 2)
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
                if (_isActiveMember)
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
                if (_isActiveMember)
                  ListTile(
                    leading: Icon(Icons.emoji_emotions_outlined, color: Colors.orangeAccent),
                    title: Text('React'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _showReactionPicker(message['_id']);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.grey),
                  title: Text('Info'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showMessageInfo(message);
                  },
                ),
                if (_isActiveMember)
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.redAccent),
                    title: Text('Delete for me'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _deleteMessage(message['_id'], false);
                    },
                  ),
                if (isMe && _isActiveMember)
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
}

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(
        size.width * 0.25, size.height, size.width * 0.5, size.height * 0.7);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.4, size.width, size.height * 0.7);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}