// lib/screens/conversations_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/conversation.dart';
import '../models/shop.dart';
import '../services/customer_service_api.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  final Shop shop;

  const ConversationsScreen({Key? key, required this.shop}) : super(key: key);

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Conversation> conversations = [];
  bool isLoading = true;
  String? error;
  String? nextPageToken;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final result = await CustomerServiceApiService.getConversations(
      widget.shop.id,
    );

    if (mounted) {
      setState(() {
        isLoading = false;
        if (result['success']) {
          conversations = result['conversations'] ?? [];
          nextPageToken = result['nextPageToken'];
        } else {
          error = result['error'];
        }
      });
    }
  }

  Future<void> _refreshConversations() async {
    await _loadConversations();
  }

  String _parseMessageContent(String content, String type) {
    try {
      if (type == 'TEXT') {
        final data = Map<String, dynamic>.from(
          const JsonDecoder().convert(content),
        );
        return data['content'] ?? 'Text message';
      }
      return type == 'IMAGE'
          ? ' Image'
          : type == 'PRODUCT_CARD'
              ? '️ Product'
              : type == 'ORDER_CARD'
                  ? ' Order'
                  : 'Message';
    } catch (e) {
      return 'Message';
    }
  }

  String _formatTime(String createTime) {
    try {
      final dateTime = DateTime.parse(createTime);
      final now = DateTime.now();
      final diff = now.difference(dateTime);

      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inDays < 1) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';

      return '${dateTime.day}/${dateTime.month}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Chat',
              style: TextStyle(fontSize: 18),
            ),
            Text(
              widget.shop.name,
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Color(0xFF00AA5B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshConversations,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshConversations,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading conversations...'),
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
              onPressed: _refreshConversations,
              child: Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Conversations will appear here when customers message your shop',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return _buildConversationItem(conversation);
      },
    );
  }

  Widget _buildConversationItem(Conversation conversation) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: conversation.buyer?.avatar.isNotEmpty == true
              ? NetworkImage(conversation.buyer!.avatar)
              : null,
          child: conversation.buyer?.avatar.isEmpty != false
              ? Icon(Icons.person)
              : null,
          backgroundColor: Colors.blue[100],
        ),
        title: Text(
          conversation.buyer?.nickname ?? 'Unknown Customer',
          style: TextStyle(
            fontWeight: conversation.unreadCount > 0
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (conversation.latestMessage != null)
              Text(
                _parseMessageContent(
                  conversation.latestMessage!.content,
                  conversation.latestMessage!.type,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: conversation.unreadCount > 0
                      ? Colors.black87
                      : Colors.grey[600],
                ),
              ),
            SizedBox(height: 2),
            Text(
              _formatTime(conversation.createTime),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (conversation.unreadCount > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  conversation.unreadCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (!conversation.canSendMessage)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.block,
                  size: 16,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                shop: widget.shop,
                conversation: conversation,
              ),
            ),
          ).then((_) {
            // Refresh conversations when returning from chat
            _refreshConversations();
          });
        },
      ),
    );
  }
}
