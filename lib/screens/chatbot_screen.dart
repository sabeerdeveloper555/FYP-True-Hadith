import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class _ConversationItem {
  final int conversationId;
  final String description;
  final String lastMessage;
  final DateTime updatedAt;

  _ConversationItem({
    required this.conversationId,
    required this.description,
    required this.lastMessage,
    required this.updatedAt,
  });
}

class ChatbotScreen extends StatefulWidget {
  final int userId;

  const ChatbotScreen({
    super.key,
    required this.userId,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<ChatMessage> _messages = [];
  final List<_ConversationItem> _conversations = [];
  int? _conversationId;
  bool _isLoading = false;
  bool _isLoadingMessages = true;
  bool _isLoadingConversations = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadPreviousMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startNewChat() async {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    setState(() {
      _messages.clear();
      _conversationId = null;
      _isLoading = false;
    });
    _messageController.clear();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoadingConversations = true);
    try {
      final list = await ApiService.getConversations(userId: widget.userId);
      if (mounted) {
        setState(() {
          _conversations.clear();
          for (final c in list) {
            _conversations.add(_ConversationItem(
              conversationId: c['conversation_id'] as int,
              description: c['description'] as String? ?? '',
              lastMessage: c['last_message'] as String? ?? '',
              updatedAt: DateTime.parse(c['updated_at'] as String),
            ));
          }
          _isLoadingConversations = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingConversations = false);
    }
  }

  Future<void> _loadConversation(int conversationId) async {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    setState(() {
      _isLoadingMessages = true;
      _messages.clear();
      _conversationId = conversationId;
    });
    try {
      final response = await ApiService.getConversationMessages(conversationId: conversationId);
      final messages = response['messages'] as List;
      if (mounted) {
        setState(() {
          for (var msg in messages) {
            final m = _parseMessage(msg as Map<String, dynamic>);
            if (m != null) _messages.add(m);
          }
          _isLoadingMessages = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMessages = false);
    }
  }

  ChatMessage? _parseMessage(Map<String, dynamic> msg) {
    final text = msg['message_text'] as String? ?? '';
    if (text.isEmpty) return null;
    bool isUser = false;
    final isUserField = msg['is_user'];
    if (isUserField != null) {
      isUser = isUserField is bool ? isUserField : (isUserField as int) == 1;
    } else {
      final fkId = msg['FK_user_type_id'] ?? msg['fk_user_type_id'];
      if (fkId is int) {
        isUser = fkId == 1;
      } else if (fkId is String) isUser = fkId == '1';
      else if (fkId is double) isUser = fkId.toInt() == 1;
    }
    DateTime timestamp;
    try {
      timestamp = DateTime.parse(msg['created_at'] as String? ?? '');
    } catch (_) {
      timestamp = DateTime.now();
    }
    return ChatMessage(text: text, isUser: isUser, timestamp: timestamp);
  }

  Future<void> _loadPreviousMessages() async {
    try {
      setState(() {
        _isLoadingMessages = true;
      });

      final response = await ApiService.getAllUserMessages(
        userId: widget.userId,
      );

      final conversationId = response['conversation_id'] as int?;
      final messages = response['messages'] as List;

      if (mounted) {
        setState(() {
          _conversationId = conversationId;
          _messages.clear();

          for (var msg in messages) {
            final messageText = msg['message_text'] as String? ?? '';
            bool isUser = false;

            final fkUserTypeId = msg['FK_user_type_id'];
            if (fkUserTypeId != null) {
              if (fkUserTypeId is int) {
                isUser = fkUserTypeId == 1;
              } else if (fkUserTypeId is String) {
                isUser = fkUserTypeId == '1';
              } else if (fkUserTypeId is double) {
                isUser = fkUserTypeId.toInt() == 1;
              }
            } else if (msg['is_user'] != null) {
              final isUserValue = msg['is_user'];
              if (isUserValue is bool) {
                isUser = isUserValue;
              } else if (isUserValue is int) {
                isUser = isUserValue == 1;
              }
            }

            final createdAtStr = msg['created_at'] as String?;
            DateTime timestamp;
            if (createdAtStr != null && createdAtStr.isNotEmpty) {
              try {
                timestamp = DateTime.parse(createdAtStr);
              } catch (e) {
                timestamp = DateTime.now();
              }
            } else {
              timestamp = DateTime.now();
            }

            if (messageText.isNotEmpty) {
              _messages.add(ChatMessage(
                text: messageText,
                isUser: isUser,
                timestamp: timestamp,
              ));
            }
          }

          _isLoadingMessages = false;
        });

        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    final loadingMessageIndex = _messages.length;
    setState(() {
      _messages.add(ChatMessage(
        text: 'Thinking...',
        isUser: false,
        timestamp: DateTime.now(),
        isLoading: true,
      ));
    });
    _scrollToBottom();

    try {
      final response = await ApiService.sendChatMessage(
        userId: widget.userId,
        conversationId: _conversationId,
        question: text,
      );

      final isNewConv = _conversationId == null;
      _conversationId = response['conversation_id'] as int;
      final botReply = response['reply'] as String;

      if (mounted) {
        setState(() {
          _messages.removeAt(loadingMessageIndex);
          _messages.add(ChatMessage(
            text: botReply,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
        _scrollToBottom();
        _loadConversations();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeAt(loadingMessageIndex);
          _messages.add(ChatMessage(
            text: 'Error: ${e.toString()}',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF0F1511) : const Color(0xFFF8FAF8),
      drawer: _buildDrawer(colorScheme, textTheme, isDark),
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.view_sidebar_outlined, color: colorScheme.onSurface, size: 22),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Column(
          children: [
            Text(
              'Hadith AI',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                letterSpacing: 0.5,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Online',
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: const [],
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingMessages
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    )
                  : _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(_messages[index], index);
                          },
                        ),
            ),
            _buildMessageInput(),
          ],
        ),
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (now.difference(date).inDays < 7) return DateFormat('EEEE').format(date);
    if (date.year == now.year) return DateFormat('MMMM d').format(date);
    return DateFormat('MMM d, yyyy').format(date);
  }

  Widget _buildDrawer(ColorScheme colorScheme, TextTheme textTheme, bool isDark) {
    final grouped = <String, List<_ConversationItem>>{};
    for (final conv in _conversations) {
      grouped.putIfAbsent(_dateLabel(conv.updatedAt), () => []).add(conv);
    }
    final items = <Object>[];
    for (final label in grouped.keys) {
      items.add(label);
      items.addAll(grouped[label]!);
    }

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0D1B12) : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hadith AI',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _startNewChat,
                    icon: Icon(Icons.add_rounded, color: colorScheme.primary),
                    tooltip: 'New Chat',
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.4)),
            const SizedBox(height: 4),
            Expanded(
              child: _isLoadingConversations
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    )
                  : items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 40,
                                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No conversations yet',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            if (item is String) {
                              return _buildDateHeader(item, colorScheme, textTheme);
                            }
                            return _buildConversationTile(
                              item as _ConversationItem,
                              colorScheme,
                              textTheme,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(String label, ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildConversationTile(
    _ConversationItem conv,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final isActive = _conversationId == conv.conversationId;
    final description = conv.description.trim().isNotEmpty
        ? conv.description.trim()
        : conv.lastMessage.trim();
    return InkWell(
      onTap: () => _loadConversation(conv.conversationId),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 15,
                color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM d, h:mm a').format(conv.updatedAt),
                    style: textTheme.labelSmall?.copyWith(
                      color: isActive
                          ? colorScheme.primary.withOpacity(0.8)
                          : colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description.isEmpty ? 'New conversation' : description,
                    style: textTheme.bodySmall?.copyWith(
                      color: isActive ? colorScheme.primary : colorScheme.onSurface,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 56,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Assalamu Alaikum!',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'I am your AI assistant specialized in authentic Hadith collections. How can I help you today?',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bool isBot = !message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isBot) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.auto_awesome_rounded, color: colorScheme.onPrimary, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isBot 
                    ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E2D23) : Colors.white)
                    : colorScheme.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isBot ? 4 : 20),
                  bottomRight: Radius.circular(isBot ? 20 : 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isLoading)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                         Text('Thinking...', style: TextStyle(fontSize: 12, color: colorScheme.primary)),
                      ],
                    )
                  else
                    Text(
                      message.text,
                      style: textTheme.bodyMedium?.copyWith(
                        color: isBot 
                            ? (message.isError ? colorScheme.error : colorScheme.onSurface)
                            : Colors.white,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a').format(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isBot 
                          ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                          : Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isBot) const SizedBox(width: 38), // Space for bot avatar alignment
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F1511) : const Color(0xFFF8FAF8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Ask your question...',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 15),
                      onSubmitted: (_) => _sendMessage(),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: _messageController.text.trim().isEmpty ? colorScheme.surface : colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  if (_messageController.text.trim().isNotEmpty)
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: _messageController.text.trim().isEmpty ? colorScheme.onSurfaceVariant.withOpacity(0.3) : Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
    this.isError = false,
  });
}

