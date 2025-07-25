import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import '../user/session.dart';
import 'dart:collection';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

// Emoji categories
const Map<String, List<String>> kEmojiCategories = {
  'Smileys': [
    '😀','😃','😄','😁','😆','😅','😂','🤣','🥲','😊','😇','🙂','🙃','😉','😌','😍','🥰','😘','😗','😙','😚','😋','😛','😝','😜','🤪','🤨','🧐','🤓','😎','🥸','🤩','🥳','😏','😒','😞','😔','😟','😕','🙁','☹️','😣','😖','😫','😩','🥺','😢','😭','😤','😠','😡','🤬','🤯','😳','🥵','🥶','😱','😨','😰','😥','😓','🤗','🤔','🤭','🤫','🤥','😶','😐','😑','😬','🙄','😯','😦','😧','😮','😲','🥱','😴','🤤','😪','😵','🤐','🥴','🤢','🤮','🤧','😷','🤒','🤕','🤑','🤠','😈','👿','👹','👺','🤡','💩','👻','💀','☠️','👽','👾','🤖','😺','😸','😹','😻','😼','😽','🙀','😿','😾'
  ],
  'Gestures': [
    '👍','👎','👊','✊','🤛','🤜','👏','🙌','👐','🤲','🤝','🙏','✍️','💅','🤳','💪','🦾','🦵','🦿','🦶','👂','🦻','👃','🧠','🦷','🦴','👀','👁️','👅','👄','💋','🩸'
  ],
  'Animals': [
    '🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐨','🐯','🦁','🐮','🐷','🐸','🐵','🙊','🙉','🙈','🐔','🐧','🐦','🐤','🐣','🐥','🦆','🦅','🦉','🦇','🐺','🐗','🐴','🦄','🐝','🐛','🦋','🐌','🐞','🐜','🦟','🦗','🕷️','🦂','🐢','🐍','🦎','🦖','🦕','🐙','🦑','🦐','🦞','🦀','🐡','🐠','🐟','🐬','🐳','🐋','🦈','🐊','🐅','🐆','🦓','🦍','🦧','🐘','🦛','🦏','🐪','🐫','🦒','🦘','🦥','🦦','🦨','🦡','🐁','🐀','🐇','🐿️','🦔','🐾','🐉','🐲'
  ],
  'Food': [
    '🍏','🍎','🍐','🍊','🍋','🍌','🍉','🍇','🍓','🫐','🍈','🍒','🍑','🥭','🍍','🥥','🥝','🍅','🍆','🥑','🥦','🥬','🥒','🌶️','🫑','🌽','🥕','🫒','🧄','🧅','🥔','🍠','🥐','🥯','🍞','🥖','🥨','🥞','🧇','🥓','🥩','🍗','🍖','🦴','🌭','🍔','🍟','🍕','🥪','🥙','🧆','🌮','🌯','🫔','🥗','🥘','🫕','🥫','🍝','🍜','🍲','🍛','🍣','🍱','🥟','🦪','🍤','🍙','🍚','🍘','🍥','🥠','🥮','🍢','🍡','🍧','🍨','🍦','🥧','🧁','🍰','🎂','🍮','🍭','🍬','🍫','🍿','🍩','🍪','🌰','🥜','🍯','🥛','🍼','🫖','☕','🍵','🧃','🥤','🧋','🍶','🍺','🍻','🥂','🍷','🥃','🍸','🍹','🧉','🍾','🥄','🍴','🍽️','🥣','🥡','🥢'
  ],
  'Activities': [
    '⚽','🏀','🏈','⚾','🥎','🎾','🏐','🏉','🥏','🎱','🪀','🏓','🏸','🥅','🏒','🏑','🏏','🥍','🏹','🎣','🤿','🥊','🥋','🎽','🛹','🛷','⛸️','🥌','🛼','🛶','⛵','🚣','🧗','🏇','🏂','⛷️','🏌️','🏄','🏊','🤽','🚴','🚵','🤸','🤾','⛹️','🤺','🤼','🤹','🧘','🛀','🛌','🧗','🏋️','🏋️‍♀️','🏋️‍♂️','🚣‍♀️','🚣‍♂️','🏄‍♀️','🏄‍♂️','🏊‍♀️','🏊‍♂️','🤽‍♀️','🤽‍♂️','🚴‍♀️','🚴‍♂️','🚵‍♀️','🚵‍♂️','🤸‍♀️','🤸‍♂️','🤾‍♀️','🤾‍♂️','⛹️‍♀️','⛹️‍♂️','🤺','🤼‍♀️','🤼‍♂️','🤹‍♀️','🤹‍♂️','🧘‍♀️','🧘‍♂️'
  ],
  'Objects': [
    '⌚','📱','📲','💻','⌨️','🖥️','🖨️','🖱️','🖲️','🕹️','🗜️','💽','💾','💿','📀','📼','📷','📸','📹','🎥','📽️','🎞️','📞','☎️','📟','📠','📺','📻','🎙️','🎚️','🎛️','⏱️','⏲️','⏰','🕰️','⌛','⏳','📡','🔋','🔌','💡','🔦','🕯️','🪔','🧯','🛢️','💸','💵','💴','💶','💷','💰','💳','🧾','💎','⚖️','🔧','🔨','⚒️','🛠️','⛏️','🔩','⚙️','🗜️','⚗️','🧪','🧫','🧬','🔬','🔭','📡','💉','🩸','💊','🩹','🩺','🚪','🛏️','🛋️','🪑','🚽','🚿','🛁','🪒','🧴','🧷','🧹','🧺','🧻','🪣','🧼','🪥','🧽','🧯','🛒','🚬','⚰️','🪦','⚱️','🗿'
  ],
};

// For frequently used emojis
List<String> _frequentEmojis = [];

// Remove all image-related state
// Remove _pendingImageBytes, _pendingImageName, _pendingImageType, sendingImage
// Remove pickImage and sendPendingImage functions
// Remove image handling in sendMessage
// Remove image preview and send/cancel UI
// Remove image display in message rendering
// In the chat input area, only show the text field and send button
// In message rendering, only show text content

class ChatPage extends StatefulWidget {
  final String transactionId;
  final String counterpartyEmail;
  const ChatPage({required this.transactionId, required this.counterpartyEmail, Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<Map<String, dynamic>> messages = [];
  bool loading = true;
  String newMessage = '';
  String? replyToId;
  String? error;
  IO.Socket? socket;
  String? userId;
  Map<String, dynamic>? counterpartyProfile;
  late TextEditingController _textController;
  final ScrollController _scrollController = ScrollController();
  bool sending = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => setup());
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    socket?.dispose();
    super.dispose();
  }

  void scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> setup() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    userId = session.user?['_id'];
    await fetchCounterpartyProfile();
    await fetchMessages();
    connectSocket();
    scrollToBottom();
  }

  Future<void> fetchCounterpartyProfile() async {
    try {
      final url = '${ApiConfig.baseUrl}/api/users/profile-by-email?email=${Uri.encodeComponent(widget.counterpartyEmail)}';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        setState(() {
          counterpartyProfile = json.decode(res.body);
        });
      }
    } catch (e) {
      // Ignore errors, allow chat to work
    }
  }

  void connectSocket() {
    socket = IO.io(ApiConfig.baseUrl, IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build());
    socket!.connect();
    socket!.onConnect((_) {
      socket!.emit('join', {'transactionId': widget.transactionId});
    });
    socket!.on('chatMessage', (data) {
      setState(() {
        messages.add(Map<String, dynamic>.from(data));
      });
      scrollToBottom();
    });
    // Optionally listen for reaction/read updates in real time
  }

  Future<void> fetchMessages() async {
    setState(() => loading = true);
    final url = '${ApiConfig.baseUrl}/api/transactions/${widget.transactionId}/chat';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      setState(() {
        final fetched = List<Map<String, dynamic>>.from(json.decode(res.body)['messages']);
        if (fetched.isNotEmpty && DateTime.tryParse(fetched.first['timestamp'] ?? '')?.isAfter(DateTime.tryParse(fetched.last['timestamp'] ?? '') ?? DateTime.now()) == true) {
          messages = fetched.reversed.toList();
        } else {
          messages = fetched;
        }
        loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
    } else {
      setState(() { loading = false; error = 'Failed to load messages'; });
    }
  }

  Future<void> sendMessage({String? image, String? imageType, String? imageName}) async {
    if ((_textController.text.trim().isEmpty) || userId == null) return;
    setState(() { error = null; sending = true; });
    final msg = {
      'transactionId': widget.transactionId,
      'senderId': userId,
      'content': _textController.text,
      'parentId': replyToId,
      'image': image,
      'imageType': imageType,
      'imageName': imageName
    };
    socket?.emit('chatMessage', msg);
    setState(() {
      newMessage = '';
      replyToId = null;
      _textController.clear();
      sending = false;
    });
    scrollToBottom();
  }

  // Remove all image-related state
  // Remove _pendingImageBytes, _pendingImageName, _pendingImageType, sendingImage
  // Remove pickImage and sendPendingImage functions
  // Remove image handling in sendMessage
  // Remove image preview and send/cancel UI
  // Remove image display in message rendering
  // In the chat input area, only show the text field and send button
  // In message rendering, only show text content

  Future<void> reactToMessage(String messageId, String emoji) async {
    if (userId == null) return;
    final url = '${ApiConfig.baseUrl}/api/transactions/${widget.transactionId}/chat/$messageId/react';
    final res = await http.patch(Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': userId, 'emoji': emoji})
    );
    if (res.statusCode == 200) {
      final updated = json.decode(res.body)['message'];
      setState(() {
        final idx = messages.indexWhere((m) => m['_id'] == messageId);
        if (idx != -1) messages[idx] = updated;
      });
    }
  }

  Future<void> markAsRead(String messageId) async {
    if (userId == null) return;
    final url = '${ApiConfig.baseUrl}/api/transactions/${widget.transactionId}/chat/$messageId/read';
    await http.patch(Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': userId})
    );
    // Optionally update UI for read status
  }

  Future<void> deleteMessage(String messageId) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final userId = session.user?['_id'];
    final url = '${ApiConfig.baseUrl}/api/transactions/${widget.transactionId}/chat/$messageId';
    final res = await http.delete(Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': userId})
    );
    if (res.statusCode == 200) {
      final updated = json.decode(res.body)['message'];
      setState(() {
        final idx = messages.indexWhere((m) => m['_id'] == messageId);
        if (idx != -1) messages[idx] = updated;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete message')));
    }
  }

  Widget buildReactions(Map<String, dynamic> msg) {
    final reactions = (msg['reactions'] ?? []) as List<dynamic>;
    if (reactions.isEmpty) return SizedBox.shrink();
    Map<String, List<String>> emojiToUsers = {};
    for (var r in reactions) {
      final emoji = r['emoji'];
      final uid = r['userId'];
      emojiToUsers.putIfAbsent(emoji, () => []).add(uid);
    }
    return Row(
      children: emojiToUsers.entries.map((e) {
        final isMine = e.value.contains(userId);
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 2),
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isMine ? Colors.blue[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(e.key, style: TextStyle(fontSize: 16)),
              SizedBox(width: 2),
              Text('${e.value.length}', style: TextStyle(fontSize: 13)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget buildReadStatus(Map<String, dynamic> msg) {
    final readBy = (msg['readBy'] ?? []) as List<dynamic>;
    if (readBy.contains(userId)) {
      return Icon(Icons.done_all, color: Colors.blue, size: 18); // Seen
    } else if (readBy.isNotEmpty) {
      return Icon(Icons.done_all, color: Colors.grey, size: 18); // Delivered
    } else {
      return Icon(Icons.check, color: Colors.grey, size: 18); // Sent
    }
  }

  void onMessageAction(BuildContext context, Map<String, dynamic> msg, bool isMine) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.reply),
              title: Text('Reply'),
              onTap: () {
                setState(() => replyToId = msg['_id']);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.emoji_emotions),
              title: Text('React'),
              onTap: () async {
                Navigator.pop(context);
                final emoji = await showReactionPicker();
                if (emoji != null) reactToMessage(msg['_id'], emoji);
              },
            ),
            if (isMine)
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete'),
                onTap: () {
                  // TODO: Implement delete logic
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete not implemented.')));
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget buildParentMessage(String? parentId) {
    if (parentId == null) return SizedBox.shrink();
    final parent = messages.firstWhere(
      (m) => m['_id'] != null && m['_id'].toString() == parentId.toString(),
      orElse: () => {},
    );
    if (parent.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Text('Message not found', style: TextStyle(fontSize: 13, color: Colors.grey[400], fontStyle: FontStyle.italic)),
      );
    }
    final parentContent = parent['deleted'] == true
      ? 'This message was deleted'
      : (parent['content'] ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        parentContent,
        style: TextStyle(fontSize: 13, color: Colors.grey[700], fontStyle: FontStyle.italic),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget buildMessageBubble(Map<String, dynamic> msg, bool isMine) {
    final content = msg['content'] ?? '';
    final isReply = msg['parentId'] != null;
    final parentWidget = isReply ? buildParentMessage(msg['parentId']) : null;
    final bubbleColor = isMine ? Color(0xFF2196F3) : Color(0xFFF1F0F0);
    final textColor = isMine ? Colors.white : Colors.black87;
    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(18),
      bottomLeft: isMine ? Radius.circular(18) : Radius.circular(4),
      bottomRight: isMine ? Radius.circular(4) : Radius.circular(18),
    );
    return Align(
      alignment: align,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (parentWidget != null) parentWidget,
            Row(
              children: [
                Expanded(child: Text(content, style: TextStyle(fontSize: 16, color: textColor)) ),
              ],
            ),
            buildReactions(msg),
          ],
        ),
      ),
    );
  }

  Widget buildReplyPreview() {
    if (replyToId == null) return SizedBox.shrink();
    final parent = messages.firstWhere(
      (m) => m['_id'] != null && m['_id'].toString() == replyToId.toString(),
      orElse: () => {},
    );
    final parentContent = parent.isEmpty
      ? 'Message not found'
      : (parent['deleted'] == true ? 'This message was deleted' : (parent['content'] ?? ''));
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(child: Text(parentContent, style: TextStyle(color: Colors.blue))),
          IconButton(icon: Icon(Icons.close), onPressed: () => setState(() => replyToId = null)),
        ],
      ),
    );
  }

  void showMessageActions(BuildContext context, Map<String, dynamic> msg, bool isMine) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: Icon(Icons.reply), title: Text('Reply'), onTap: () { setState(() => replyToId = msg['_id']); Navigator.pop(context); }),
          ListTile(leading: Icon(Icons.emoji_emotions), title: Text('React'), onTap: () async { final emoji = await showReactionPicker(); if (emoji != null) reactToMessage(msg['_id'], emoji); Navigator.pop(context); }),
          if (isMine)
            ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete for everyone', style: TextStyle(color: Colors.red)), onTap: () async { await deleteMessage(msg['_id']); Navigator.pop(context); }),
          ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete for me'), onTap: () { setState(() { messages.removeWhere((m) => m['_id'] != null && m['_id'].toString() == msg['_id'].toString()); }); Navigator.pop(context); }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = counterpartyProfile?['name'] ?? counterpartyProfile?['email'] ?? widget.counterpartyEmail;
    return Scaffold(
      backgroundColor: Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Color(0xFF2196F3),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: counterpartyProfile?['profileImage'] != null
                ? NetworkImage(counterpartyProfile!['profileImage'])
                : null,
              child: counterpartyProfile?['profileImage'] == null ? Icon(Icons.person, color: Color(0xFF2196F3)) : null,
              radius: 20,
            ),
            SizedBox(width: 12),
            Text(displayName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          // Optionally add more icons here (e.g., info, but NOT voice/camera)
        ],
      ),
      body: loading
        ? Center(child: CircularProgressIndicator())
        : Column(
            children: [
              if (counterpartyProfile != null)
                SizedBox(height: 8),
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final msg = messages[i];
                        markAsRead(msg['_id']);
                        final isMine = msg['sender']?['_id'] == userId;
                        Widget bubble;
                        bubble = buildMessageBubble(msg, isMine);
                        return Row(
                          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                              child: bubble,
                            ),
                            SizedBox(width: 4),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, size: 20),
                              onSelected: (value) async {
                                if (value == 'reply') setState(() => replyToId = msg['_id']);
                                if (value == 'react') showReactionPicker().then((emoji) { if (emoji != null) reactToMessage(msg['_id'], emoji); });
                                if (value == 'delete_for_me') setState(() { messages.removeWhere((m) => m['_id'] != null && m['_id'].toString() == msg['_id'].toString()); });
                                if (value == 'delete_for_everyone' && isMine) await deleteMessage(msg['_id']);
                              },
                              itemBuilder: (context) {
                                final timestamp = msg['timestamp'] != null ? DateTime.tryParse(msg['timestamp']) : null;
                                final dateStr = timestamp != null ? DateFormat('dd MMM yyyy').format(timestamp) : 'Unknown date';
                                final timeStr = timestamp != null ? DateFormat('hh:mm a').format(timestamp) : 'Unknown time';
                                return [
                                  PopupMenuItem(
                                    enabled: false,
                                    child: Text('Date: $dateStr', style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic)),
                                  ),
                                  PopupMenuItem(
                                    enabled: false,
                                    child: Text('Time: $timeStr', style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic)),
                                  ),
                                  PopupMenuItem(value: 'reply', child: Text('Reply')),
                                  PopupMenuItem(value: 'react', child: Text('React')),
                                  PopupMenuItem(value: 'delete_for_me', child: Text('Delete for me')),
                                  if (isMine) PopupMenuItem(value: 'delete_for_everyone', child: Text('Delete for everyone', style: TextStyle(color: Colors.red))),
                                ];
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    if (sending)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.05),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                  ],
                ),
              ),
              buildReplyPreview(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(error!, style: TextStyle(color: Colors.red)),
                ),
              Container(
                margin: EdgeInsets.all(8),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              border: InputBorder.none,
                            ),
                            onChanged: (v) => setState(() => newMessage = v),
                          ),
                        ),
                        if (_textController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.send, color: Colors.blue),
                            onPressed: () => sendMessage(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Future<String?> showReactionPicker() async {
    String search = '';
    String selectedCategory = kEmojiCategories.keys.first;
    List<String> filtered = kEmojiCategories[selectedCategory]!;
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Filter emojis by search
            List<String> emojis = search.isEmpty
              ? kEmojiCategories[selectedCategory]!
              : kEmojiCategories[selectedCategory]!.where((e) => _emojiName(e).contains(search.toLowerCase())).toList();
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search emoji...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (v) => setModalState(() => search = v),
                    ),
                  ),
                  // Category tabs
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: kEmojiCategories.keys.map((cat) => GestureDetector(
                        onTap: () => setModalState(() => selectedCategory = cat),
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 6),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selectedCategory == cat ? Colors.blue[100] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(child: Text(cat)),
                        ),
                      )).toList(),
                    ),
                  ),
                  // Frequently used
                  if (_frequentEmojis.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Wrap(
                        children: _frequentEmojis.map((e) => GestureDetector(
                          onTap: () => Navigator.pop(context, e),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Text(e, style: TextStyle(fontSize: 28)),
                          ),
                        )).toList(),
                      ),
                    ),
                  // Emoji grid
                  Flexible(
                    child: GridView.count(
                      crossAxisCount: 8,
                      shrinkWrap: true,
                      children: emojis.map((e) => GestureDetector(
                        onTap: () {
                          // Add to frequent
                          if (!_frequentEmojis.contains(e)) {
                            if (_frequentEmojis.length >= 16) _frequentEmojis.removeLast();
                            _frequentEmojis.insert(0, e);
                          }
                          Navigator.pop(context, e);
                        },
                        child: Center(child: Text(e, style: TextStyle(fontSize: 28))),
                      )).toList(),
                    ),
                  ),
                  // Custom emoji upload
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.add_a_photo),
                      label: Text('Upload Custom Emoji'),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(type: FileType.image);
                        if (result != null && result.files.single.bytes != null) {
                          final file = result.files.single;
                          final base64 = base64Encode(file.bytes!);
                          // Use a special marker for custom emoji
                          Navigator.pop(context, 'custom:$base64');
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _emojiName(String emoji) {
    // Simple mapping for demo; in production, use a full emoji name map
    return emoji.codeUnits.map((c) => c.toRadixString(16)).join();
  }
} 