// lib/screens/chat_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/conversation.dart';
import '../models/shop.dart';
import '../services/customer_service_api.dart';

class ChatScreen extends StatefulWidget {
  final Shop shop;
  final Conversation conversation;

  const ChatScreen({
    Key? key,
    required this.shop,
    required this.conversation,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  List<Message> messages = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool isSending = false;
  String? error;
  String? nextPageToken;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final result = await CustomerServiceApiService.getMessages(
      widget.shop.id,
      widget.conversation.id,
    );

    if (mounted) {
      setState(() {
        isLoading = false;
        if (result['success']) {
          messages = result['messages'] ?? [];
          nextPageToken = result['nextPageToken'];
          // Reverse messages untuk tampilan chat (terbaru di bawah)
          messages = messages.reversed.toList();
        } else {
          error = result['error'];
        }
      });

      // Scroll ke bawah setelah load messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  Future<void> _loadMoreMessages() async {
    if (isLoadingMore || nextPageToken == null || nextPageToken!.isEmpty)
      return;

    setState(() {
      isLoadingMore = true;
    });

    final result = await CustomerServiceApiService.getMessages(
      widget.shop.id,
      widget.conversation.id,
      pageToken: nextPageToken!,
    );

    if (mounted) {
      setState(() {
        isLoadingMore = false;
        if (result['success']) {
          final newMessages = result['messages'] ?? <Message>[];
          final reversedNewMessages = newMessages.reversed.toList();
          // Insert pesan lama di atas
          messages.insertAll(0, reversedNewMessages);
          nextPageToken = result['nextPageToken'];
        }
      });
    }
  }

  Future<void> _markAsRead() async {
    if (widget.conversation.unreadCount > 0) {
      await CustomerServiceApiService.readMessages(
        widget.shop.id,
        widget.conversation.id,
      );
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || isSending) return;

    setState(() {
      isSending = true;
    });

    _messageController.clear();

    final result = await CustomerServiceApiService.sendTextMessage(
      widget.shop.id,
      widget.conversation.id,
      text,
    );

    setState(() {
      isSending = false;
    });

    if (result['success']) {
      // Refresh messages untuk melihat pesan yang baru dikirim
      await _refreshMessages();
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim pesan: ${result['error']}'),
          backgroundColor: Colors.red,
        ),
      );
      // Kembalikan text ke controller jika gagal
      _messageController.text = text;
    }
  }

  Future<void> _sendImageMessage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        isSending = true;
      });

      // Upload image terlebih dahulu
      final uploadResult = await CustomerServiceApiService.uploadImage(
        widget.shop.id,
        File(image.path),
      );

      if (!uploadResult['success']) {
        throw Exception(uploadResult['error']);
      }

      // Kirim pesan dengan URL gambar
      final imageContent = jsonEncode({
        'url': uploadResult['url'],
        'width': uploadResult['width'],
        'height': uploadResult['height'],
      });

      final result = await CustomerServiceApiService.sendMessage(
        widget.shop.id,
        widget.conversation.id,
        'IMAGE',
        imageContent,
      );

      setState(() {
        isSending = false;
      });

      if (result['success']) {
        // Refresh messages untuk melihat pesan yang baru dikirim
        await _refreshMessages();
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      setState(() {
        isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim gambar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshMessages() async {
    final result = await CustomerServiceApiService.getMessages(
      widget.shop.id,
      widget.conversation.id,
    );

    if (result['success'] && mounted) {
      setState(() {
        messages = (result['messages'] ?? []).reversed.toList();
        nextPageToken = result['nextPageToken'];
      });

      // Scroll ke bawah untuk melihat pesan terbaru
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _parseMessageContent(Message message) {
    try {
      if (message.type == 'TEXT') {
        final data = Map<String, dynamic>.from(
          const JsonDecoder().convert(message.content),
        );
        return data['content'] ?? 'Text message';
      } else if (message.type == 'IMAGE') {
        return ' Image';
      } else if (message.type == 'PRODUCT_CARD') {
        return '️ Product';
      } else if (message.type == 'ORDER_CARD') {
        return ' Order';
      }
      return message.type;
    } catch (e) {
      return message.content.isNotEmpty ? message.content : message.type;
    }
  }

  String? _getImageUrl(Message message) {
    if (message.type != 'IMAGE') return null;

    try {
      final data = Map<String, dynamic>.from(
        const JsonDecoder().convert(message.content),
      );
      return data['url'] as String?;
    } catch (e) {
      return null;
    }
  }

  bool _isMyMessage(Message message) {
    return message.sender?.role == 'CUSTOMER_SERVICE';
  }

  String _formatTime(String createTime) {
    try {
      final dateTime = DateTime.parse(createTime);
      final now = DateTime.now();
      final diff = now.difference(dateTime);

      if (diff.inDays == 0) {
        // Hari ini - tampilkan jam
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        return 'Kemarin';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} hari lalu';
      } else {
        return '${dateTime.day}/${dateTime.month}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.conversation.buyer?.nickname ?? 'Customer',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              'Online',
              style: TextStyle(fontSize: 12, color: Colors.blue[100]),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading messages...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Error: $error'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMessages,
              child: Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Start the conversation!',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        // Load more messages saat scroll ke atas
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.minScrollExtent) {
          _loadMoreMessages();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: messages.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (isLoadingMore && index == 0) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final messageIndex = isLoadingMore ? index - 1 : index;
          final message = messages[messageIndex];
          return _buildMessageBubble(message);
        },
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isMe = _isMyMessage(message);
    final content = _parseMessageContent(message);
    final imageUrl = _getImageUrl(message);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage:
                  widget.conversation.buyer?.avatar.isNotEmpty == true
                      ? NetworkImage(widget.conversation.buyer!.avatar)
                      : null,
              child: widget.conversation.buyer?.avatar.isEmpty != false
                  ? Icon(Icons.person, size: 18)
                  : null,
              backgroundColor: Colors.grey[300],
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue[500] : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 100,
                            color: Colors.grey[300],
                            child: Icon(Icons.broken_image,
                                color: Colors.grey[600]),
                          );
                        },
                      ),
                    ),
                    if (content != ' Image')
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          content,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ] else ...[
                    Text(
                      content,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  SizedBox(height: 4),
                  Text(
                    _formatTime(message.createTime),
                    style: TextStyle(
                      color: isMe ? Colors.blue[100] : Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) SizedBox(width: 50),
          if (!isMe) SizedBox(width: 50),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.image, color: Colors.blue),
            onPressed: isSending ? null : _sendImageMessage,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !isSending,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendTextMessage(),
            ),
          ),
          SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: isSending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.send, color: Colors.white),
              onPressed: isSending ? null : _sendTextMessage,
            ),
          ),
        ],
      ),
    );
  }
}
