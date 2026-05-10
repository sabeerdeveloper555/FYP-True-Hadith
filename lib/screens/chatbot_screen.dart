import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

/// Detect language from typed text using Unicode ranges.
/// Returns 'ar', 'ur', or 'en'.
String _detectInputLanguage(String text) {
  if (text.isEmpty) return 'en';
  int arabicCount = 0;
  int latinCount = 0;
  for (final c in text.runes) {
    if ((c >= 0x0600 && c <= 0x06FF) || (c >= 0x0750 && c <= 0x077F)) {
      arabicCount++;
    } else if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)) {
      latinCount++;
    }
  }
  if (arabicCount <= latinCount) return 'en';
  // Urdu-specific chars: ں (06BA) ہ (06C1) ھ (06BE) ے (06D2) ٹ ڈ ڑ ژ ۓ
  const urduChars = {0x06BA, 0x06C1, 0x06BE, 0x06D2, 0x0679, 0x0688, 0x0691, 0x0698, 0x06D3};
  final hasUrdu = text.runes.any((c) => urduChars.contains(c));
  return hasUrdu ? 'ur' : 'ar';
}

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
  bool _isLoadingMessages = false;
  bool _isLoadingConversations = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    final lang = _detectInputLanguage(text);

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
        language: lang,
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
        language: lang,
      );

      _conversationId = response['conversation_id'] as int;
      final botReply = response['reply'] as String? ?? '';
      final expTitle = response['explanation_title'] as String? ?? '';
      final expBody  = response['explanation_body']  as String? ?? botReply;
      final rawHadiths = response['hadiths'] as List<dynamic>? ?? [];
      final hadiths = rawHadiths
          .map((h) => HadithEvidence.fromJson(h as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _messages.removeAt(loadingMessageIndex);
          _messages.add(ChatMessage(
            text: botReply,
            isUser: false,
            timestamp: DateTime.now(),
            explanationTitle: expTitle.isNotEmpty ? expTitle : null,
            explanationBody: expBody.isNotEmpty ? expBody : null,
            hadiths: hadiths.isNotEmpty ? hadiths : null,
            originalQuestion: text,
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
            Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
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
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
          color: isActive ? colorScheme.primary.withValues(alpha: 0.12) : Colors.transparent,
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
                          ? colorScheme.primary.withValues(alpha: 0.8)
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
              color: colorScheme.primary.withValues(alpha: 0.1),
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
    if (message.isUser) return _buildUserBubble(message);
    if (message.isLoading) return _buildLoadingBubble();
    if (message.hasStructuredData) return _buildBotCard(message, index);
    return _buildSimpleBotBubble(message);
  }

  Widget _buildUserBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 48),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8E0D0),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                message.text,
                textDirection: message.isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                textAlign: message.isRtl ? TextAlign.right : TextAlign.left,
                style: const TextStyle(fontSize: 15, color: Color(0xFF2D2D2D), height: 1.5),
              ),
              const SizedBox(height: 4),
              Text(DateFormat('h:mm a').format(message.timestamp),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _botAvatar(colorScheme),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E2D23)
                  : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary)),
                ),
                const SizedBox(width: 8),
                Text('Thinking…',
                    style: TextStyle(fontSize: 13, color: colorScheme.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleBotBubble(ChatMessage message) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _botAvatar(colorScheme),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2D23) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.text,
                      style: TextStyle(
                          fontSize: 15,
                          color: message.isError ? colorScheme.error : colorScheme.onSurface,
                          height: 1.5)),
                  const SizedBox(height: 4),
                  Text(DateFormat('h:mm a').format(message.timestamp),
                      style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotCard(ChatMessage message, int messageIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A2420) : Colors.white;
    final labelColor = isDark ? const Color(0xFF8BAF8B) : const Color(0xFF5A8A5A);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2D4030) : const Color(0xFFE8EDE8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('TRUE HADITH BOT',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  Text(DateFormat('h:mm a').format(message.timestamp),
                      style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                ],
              ),
            ),

            // ── Explanation section ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EXPLANATION',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: labelColor)),
                  const SizedBox(height: 8),
                  if (message.explanationTitle != null &&
                      message.explanationTitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(message.explanationTitle!,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                              height: 1.3)),
                    ),
                  Text(message.explanationBody ?? message.text,
                      style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.85),
                          height: 1.6)),
                ],
              ),
            ),

            // ── Evidence section ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Row(
                children: [
                  Expanded(child: Divider(color: colorScheme.outline.withValues(alpha: 0.3))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'EVIDENCE · ${message.hadiths!.length} HADITH${message.hadiths!.length > 1 ? 'S' : ''}',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: labelColor),
              ),
            ),
            const SizedBox(height: 8),
            ...message.hadiths!.map((h) => _HadithEvidenceCard(hadith: h)),

            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _botAvatar(ColorScheme colorScheme) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Icon(Icons.auto_awesome_rounded, color: colorScheme.onPrimary, size: 14),
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
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Builder(builder: (context) {
                      final inputLang = _detectInputLanguage(_messageController.text);
                      final isRtlInput = inputLang == 'ar' || inputLang == 'ur';
                      return TextField(
                        controller: _messageController,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        enabled: !_isLoading,
                        textDirection: isRtlInput ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                        textAlign: isRtlInput ? TextAlign.right : TextAlign.left,
                        decoration: InputDecoration(
                          hintText: 'Ask your question...',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 15),
                        onSubmitted: (_) => _sendMessage(),
                        onChanged: (val) => setState(() {}),
                      );
                    }),
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
                      color: colorScheme.primary.withValues(alpha: 0.3),
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
                        color: _messageController.text.trim().isEmpty ? colorScheme.onSurfaceVariant.withValues(alpha: 0.3) : Colors.white,
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

class HadithEvidence {
  final int rank;
  final String bookName;
  final String hadithNumber;
  final String narrator;
  final String grade;
  final String arabicText;
  final String englishText;
  final String urduText;
  final String chapter;
  final double matchScore;

  const HadithEvidence({
    required this.rank,
    required this.bookName,
    required this.hadithNumber,
    required this.narrator,
    required this.grade,
    required this.arabicText,
    required this.englishText,
    required this.urduText,
    required this.chapter,
    required this.matchScore,
  });

  factory HadithEvidence.fromJson(Map<String, dynamic> j) => HadithEvidence(
        rank: (j['rank'] as num?)?.toInt() ?? 1,
        bookName: j['book_name'] as String? ?? 'N/A',
        hadithNumber: j['hadith_number'] as String? ?? 'N/A',
        narrator: j['narrator'] as String? ?? 'Unknown',
        grade: j['grade'] as String? ?? 'N/A',
        arabicText: j['arabic_text'] as String? ?? '',
        englishText: j['english_text'] as String? ?? '',
        urduText: j['urdu_text'] as String? ?? '',
        chapter: j['chapter'] as String? ?? '',
        matchScore: (j['match_score'] as num?)?.toDouble() ?? 0.0,
      );
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;
  final bool isError;
  final String? explanationTitle;
  final String? explanationBody;
  final List<HadithEvidence>? hadiths;
  final String? originalQuestion;
  final String language; // 'en', 'ar', 'ur'

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
    this.isError = false,
    this.explanationTitle,
    this.explanationBody,
    this.hadiths,
    this.originalQuestion,
    this.language = 'en',
  });

  bool get isRtl => language == 'ar' || language == 'ur';

  bool get hasStructuredData =>
      !isUser && !isLoading && !isError && hadiths != null && hadiths!.isNotEmpty;
}

// ── Expandable hadith evidence card ─────────────────────────────────────────

class _HadithEvidenceCard extends StatefulWidget {
  final HadithEvidence hadith;
  const _HadithEvidenceCard({required this.hadith});

  @override
  State<_HadithEvidenceCard> createState() => _HadithEvidenceCardState();
}

class _HadithEvidenceCardState extends State<_HadithEvidenceCard> {
  bool _expanded = false;

  bool _hasKnownGrade(String grade) {
    final g = grade.toLowerCase().trim();
    if (g.isEmpty || g == 'n/a') return false;
    if (g.contains('no grade') || g == 'no grade mention') return false;
    return true;
  }

  Color _gradeColor(String grade) {
    final g = grade.toLowerCase();
    if (g.contains('sahih')) return const Color(0xFF2E7D32);
    if (g.contains('hasan')) return const Color(0xFFE65100);
    // Da'if / Daif / Daeef / Dhaif / Weak / Mawdu / Munkar
    if (g.contains('da') || g.contains('dh') || g.contains('zaif') ||
        g.contains('weak') || g.contains('mawdu') || g.contains('munkar') ||
        g.contains('fabricat') || g.contains('rejected')) {
      return const Color(0xFFC62828);
    }
    return const Color(0xFF546E7A);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hadith;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradeColor = _gradeColor(h.grade);

    // Short book label (e.g. "Bukhari", "Muslim", "Tirmidhi")
    String shortBook = h.bookName;
    if (shortBook.toLowerCase().contains('bukhari')) {
      shortBook = 'Bukhari';
    } else if (shortBook.toLowerCase().contains('muslim')) shortBook = 'Muslim';
    else if (shortBook.toLowerCase().contains('tirmidhi') || shortBook.toLowerCase().contains('tirmizi')) {
      shortBook = 'Tirmidhi';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1C13) : const Color(0xFFF5F8F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF2A3C2E) : const Color(0xFFDDE8DD),
            ),
          ),
          child: Column(
            children: [
              // ── Collapsed row ────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Rank badge
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${h.rank}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Book · Hadith number
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface,
                          ),
                          children: [
                            TextSpan(
                              text: '$shortBook ${h.hadithNumber}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: ' · ${h.narrator}',
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Grade badge — only when grade is known
                    if (_hasKnownGrade(h.grade))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: gradeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          h.grade.split(' ').first,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: gradeColor,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),

              // ── Expanded detail ──────────────────────────
              if (_expanded)
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF2A3C2E) : const Color(0xFFDDE8DD),
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Arabic text
                      if (h.arabicText.isNotEmpty && h.arabicText != 'N/A')
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            h.arabicText,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.8,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      if (h.arabicText.isNotEmpty && h.arabicText != 'N/A')
                        const SizedBox(height: 10),
                      // English text
                      if (h.englishText.isNotEmpty && h.englishText != 'N/A')
                        Text(
                          h.englishText,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: colorScheme.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                      // Urdu text
                      if (h.urduText.isNotEmpty && h.urduText != 'N/A') ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            h.urduText,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.8,
                              color: colorScheme.onSurface.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // Meta chips row: narrator · grade · match score
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _chip(h.narrator, colorScheme.onSurfaceVariant, colorScheme),
                          if (_hasKnownGrade(h.grade))
                            _chip(h.grade.split(' ').first, gradeColor,
                                colorScheme, bgColor: gradeColor.withValues(alpha: 0.12)),
                          _chip('match ${h.matchScore.toStringAsFixed(2)}',
                              colorScheme.onSurfaceVariant, colorScheme),
                        ],
                      ),
                      if (h.chapter.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            h.chapter,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color textColor, ColorScheme colorScheme,
      {Color? bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor ?? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500),
      ),
    );
  }
}

