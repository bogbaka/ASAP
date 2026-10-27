import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../database/database_connection.dart';

class ConversationScreen extends StatefulWidget {
  final String contactName;
  final String initials;
  final Color avatarColor;
  final bool isOnline;
  final String? initialReply;
  final String? repliedStatusText;
  final String? phoneNumber;
  final String? about;

  const ConversationScreen({
    super.key,
    required this.contactName,
    required this.initials,
    required this.avatarColor,
    this.isOnline = false,
    this.initialReply,
    this.repliedStatusText,
    this.phoneNumber,
    this.about,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _backgroundColor = Color(0xFFEFEAE2);
  static const Color _headingColor = Color(0xFF202C33);
  static const Color _secondaryColor = Color(0xFF667781);
  static const Color _incomingBubble = Colors.white;
  static const Color _outgoingBubble = Color(0xFFD9FDD3);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  late final String _conversationId;

  bool _isLoadingMessages = true;
  bool _isMuted = false;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.contactName.trim().toLowerCase();
    _messageController.text = widget.initialReply ?? '';
    _loadConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    try {
      final existingConversation = await (appDatabase.select(
        appDatabase.conversations,
      )..where((table) => table.id.equals(_conversationId))).getSingleOrNull();

      if (existingConversation == null) {
        await appDatabase
            .into(appDatabase.conversations)
            .insert(
              ConversationsCompanion.insert(
                id: _conversationId,
                contactName: widget.contactName,
              ),
            );
      }

      final savedMessages =
          await (appDatabase.select(appDatabase.messages)
                ..where((table) => table.conversationId.equals(_conversationId))
                ..orderBy([
                  (table) => OrderingTerm.asc(table.sentAt),
                  (table) => OrderingTerm.asc(table.id),
                ]))
              .get();

      if (!mounted) return;

      setState(() {
        _messages
          ..clear()
          ..addAll(
            savedMessages.map(
              (message) => ChatMessage(
                text: message.content,
                time: TimeOfDay.fromDateTime(message.sentAt).format(context),
                isOutgoing: message.isOutgoing,
                isRead: message.isRead,
              ),
            ),
          );
        _isLoadingMessages = false;
      });

      _scrollToLatestMessage();
    } catch (error, stackTrace) {
      debugPrint('Failed to load conversation: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() => _isLoadingMessages = false);
      _showDemoMessage(
        'Unable to load messages. Please try reopening this conversation.',
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    if (_isLoadingMessages) {
      _showDemoMessage('Please wait for the conversation to load.');
      return;
    }

    if (_isBlocked) {
      _showDemoMessage('Unblock this contact before sending a message.');
      return;
    }

    final now = DateTime.now();
    final formattedTime = TimeOfDay.fromDateTime(now).format(context);

    try {
      // Save the message before displaying it as sent.
      await appDatabase
          .into(appDatabase.messages)
          .insert(
            MessagesCompanion.insert(
              conversationId: _conversationId,
              content: text,
              isOutgoing: true,
              sentAt: Value(now),
            ),
          );

      // Keep the conversation's last-message preview up to date.
      await (appDatabase.update(
        appDatabase.conversations,
      )..where((table) => table.id.equals(_conversationId))).write(
        ConversationsCompanion(lastMessage: Value(text), updatedAt: Value(now)),
      );

      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(text: text, time: formattedTime, isOutgoing: true),
        );
      });

      _messageController.clear();
      _scrollToLatestMessage();
    } catch (error, stackTrace) {
      debugPrint('Failed to save message: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showDemoMessage('Message could not be saved. Please try again.');
    }
  }

  void _scrollToLatestMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showDemoMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _openContactDetails() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ContactInfoScreen(
          contactName: widget.contactName,
          initials: widget.initials,
          avatarColor: widget.avatarColor,
          isOnline: widget.isOnline,
          phoneNumber: widget.phoneNumber,
          about: widget.about,
          isMuted: _isMuted,
          isBlocked: _isBlocked,
          onMuteChanged: (value) {
            setState(() => _isMuted = value);
            _showDemoMessage(
              value
                  ? 'Notifications muted for this conversation.'
                  : 'Notifications enabled for this conversation.',
            );
          },
          onBlockTap: () {
            Navigator.of(context).pop();
            _confirmBlockContact();
          },
        ),
      ),
    );
  }

  void _handleMoreOptionsSelected(String action) {
    switch (action) {
      case 'contact_info':
        _openContactDetails();
        break;
      case 'search':
        _searchConversation();
        break;
      case 'mute':
        setState(() => _isMuted = !_isMuted);
        _showDemoMessage(
          _isMuted
              ? 'Notifications muted for this conversation.'
              : 'Notifications enabled for this conversation.',
        );
        break;
      case 'clear':
        _confirmClearConversation();
        break;
      case 'report':
        _confirmReportContact();
        break;
      case 'block':
        _confirmBlockContact();
        break;
    }
  }

  void _searchConversation() {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter a word or phrase',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) {
            Navigator.pop(dialogContext);
            _findMessage(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text;
              Navigator.pop(dialogContext);
              _findMessage(value);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _findMessage(String query) {
    final term = query.trim().toLowerCase();

    if (term.isEmpty) {
      _showDemoMessage('Enter a word or phrase to search.');
      return;
    }

    final count = _messages
        .where((message) => message.text.toLowerCase().contains(term))
        .length;

    _showDemoMessage(
      count == 0
          ? 'No matching messages found.'
          : 'Found $count matching message(s).',
    );
  }

  void _confirmClearConversation() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text(
          'This clears the messages in this conversation. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _clearConversation();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearConversation() async {
    try {
      await (appDatabase.delete(
        appDatabase.messages,
      )..where((table) => table.conversationId.equals(_conversationId))).go();

      await (appDatabase.update(
        appDatabase.conversations,
      )..where((table) => table.id.equals(_conversationId))).write(
        ConversationsCompanion(
          lastMessage: const Value(''),
          updatedAt: Value(DateTime.now()),
        ),
      );

      if (!mounted) return;

      setState(_messages.clear);
      _showDemoMessage('Conversation cleared.');
    } catch (error, stackTrace) {
      debugPrint('Failed to clear conversation: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showDemoMessage('Unable to clear this conversation. Please try again.');
    }
  }

  void _confirmReportContact() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report contact?'),
        content: Text(
          'Reporting ${widget.contactName} is not connected to the backend. '
          'No report will be submitted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmBlockContact() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_isBlocked ? 'Unblock contact?' : 'Block contact?'),
        content: Text(
          _isBlocked
              ? 'Allow ${widget.contactName} to message you in this demo?'
              : 'Block ${widget.contactName} in this demo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() => _isBlocked = !_isBlocked);
              _showDemoMessage(
                _isBlocked
                    ? '${widget.contactName} blocked in this demo.'
                    : '${widget.contactName} unblocked.',
              );
            },
            child: Text(_isBlocked ? 'Unblock' : 'Block'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leadingWidth: 44,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          color: _headingColor,
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: _openContactDetails,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: widget.avatarColor,
                child: Text(
                  widget.initials,
                  style: const TextStyle(
                    color: _headingColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.contactName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _headingColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.isOnline ? 'online' : 'ASAP contact',
                      style: const TextStyle(
                        color: _secondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Voice call',
            onPressed: () {
              _showDemoMessage(
                'Voice calling will be available in a future update.',
              );
            },
            icon: const Icon(Icons.call_outlined, color: _primaryColor),
          ),
          IconButton(
            tooltip: 'Video call',
            onPressed: () {
              _showDemoMessage(
                'Video calling will be available in a future update.',
              );
            },
            icon: const Icon(Icons.videocam_outlined, color: _primaryColor),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: const Icon(Icons.more_vert, color: _primaryColor),
            onSelected: _handleMoreOptionsSelected,
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'contact_info',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_outline),
                  title: Text('Contact info'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'search',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.search),
                  title: Text('Search'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'mute',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _isMuted
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                  ),
                  title: Text(
                    _isMuted ? 'Unmute notifications' : 'Mute notifications',
                  ),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'clear',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Clear conversation'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'report',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flag_outlined),
                  title: Text('Report contact'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'block',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _isBlocked ? Icons.lock_open : Icons.block,
                    color: _isBlocked ? Colors.green : Colors.red,
                  ),
                  title: Text(_isBlocked ? 'Unblock contact' : 'Block contact'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoadingMessages
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 18,
                      ),
                      itemCount: _messages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildDateLabel();
                        return _buildMessageBubble(_messages[index - 1]);
                      },
                    ),
            ),
            if (widget.repliedStatusText != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Replying to status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    Text(
                      widget.repliedStatusText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            _buildMessageComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateLabel() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8C6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'TODAY',
          style: TextStyle(
            color: _secondaryColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isOutgoing = message.isOutgoing;

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 9, 10, 7),
        decoration: BoxDecoration(
          color: isOutgoing ? _outgoingBubble : _incomingBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isOutgoing ? 12 : 3),
            bottomRight: Radius.circular(isOutgoing ? 3 : 12),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                color: _headingColor,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.time,
                  style: const TextStyle(color: _secondaryColor, fontSize: 10),
                ),
                if (isOutgoing) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 15,
                    color: message.isRead
                        ? const Color(0xFF16A34A)
                        : _secondaryColor,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      color: _backgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Attach file',
            onPressed: () {
              _showDemoMessage(
                'Attachments will be available in a future update.',
              );
            },
            icon: const Icon(
              Icons.add_circle_outline,
              color: _secondaryColor,
              size: 27,
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: TextField(
                controller: _messageController,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  hintStyle: TextStyle(color: _secondaryColor, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _primaryColor,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Send message',
              onPressed: _sendMessage,
              icon: const Icon(Icons.send, color: Colors.white, size: 21),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactInfoScreen extends StatefulWidget {
  final String contactName;
  final String initials;
  final Color avatarColor;
  final bool isOnline;
  final String? phoneNumber;
  final String? about;
  final bool isMuted;
  final bool isBlocked;
  final ValueChanged<bool> onMuteChanged;
  final VoidCallback onBlockTap;

  const _ContactInfoScreen({
    required this.contactName,
    required this.initials,
    required this.avatarColor,
    required this.isOnline,
    required this.phoneNumber,
    required this.about,
    required this.isMuted,
    required this.isBlocked,
    required this.onMuteChanged,
    required this.onBlockTap,
  });

  @override
  State<_ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends State<_ContactInfoScreen> {
  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _headingColor = Color(0xFF202C33);
  static const Color _secondaryColor = Color(0xFF667781);

  late bool _isMuted;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted;
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.phoneNumber?.trim();
    final about = widget.about?.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F9),
      appBar: AppBar(
        title: const Text('Contact info'),
        backgroundColor: Colors.white,
        foregroundColor: _headingColor,
        elevation: 1,
      ),
      body: ListView(
        children: [
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: widget.avatarColor,
                  child: Text(
                    widget.initials,
                    style: const TextStyle(
                      color: _headingColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.contactName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _headingColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isOnline ? 'Online' : 'ASAP contact',
                  style: const TextStyle(color: _secondaryColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _sectionCard(
            title: 'Contact details',
            children: [
              ListTile(
                leading: const Icon(Icons.phone_outlined, color: _primaryColor),
                title: const Text('Phone number'),
                subtitle: Text(
                  phone == null || phone.isEmpty ? 'Not provided' : phone,
                ),
              ),
              const Divider(height: 1, indent: 72),
              ListTile(
                leading: const Icon(Icons.info_outline, color: _primaryColor),
                title: const Text('About'),
                subtitle: Text(
                  about == null || about.isEmpty
                      ? 'No about information added'
                      : about,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _sectionCard(
            title: 'Media, links and documents',
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: _primaryColor,
                ),
                title: const Text('Media'),
                trailing: const Text('0'),
                onTap: () => _showEmptyContent(context, 'Media'),
              ),
              const Divider(height: 1, indent: 72),
              ListTile(
                leading: const Icon(Icons.link_outlined, color: _primaryColor),
                title: const Text('Links'),
                trailing: const Text('0'),
                onTap: () => _showEmptyContent(context, 'Links'),
              ),
              const Divider(height: 1, indent: 72),
              ListTile(
                leading: const Icon(
                  Icons.insert_drive_file_outlined,
                  color: _primaryColor,
                ),
                title: const Text('Documents'),
                trailing: const Text('0'),
                onTap: () => _showEmptyContent(context, 'Documents'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _sectionCard(
            title: 'Settings',
            children: [
              SwitchListTile(
                secondary: const Icon(
                  Icons.notifications_off_outlined,
                  color: _primaryColor,
                ),
                title: const Text('Mute notifications'),
                value: _isMuted,
                activeThumbColor: _primaryColor,
                onChanged: (value) {
                  setState(() => _isMuted = value);
                  widget.onMuteChanged(value);
                },
              ),
              const Divider(height: 1, indent: 72),
              ListTile(
                leading: Icon(
                  widget.isBlocked ? Icons.person_add_alt_1 : Icons.block,
                  color: Colors.red.shade700,
                ),
                title: Text(
                  widget.isBlocked ? 'Unblock contact' : 'Block contact',
                  style: TextStyle(color: Colors.red.shade700),
                ),
                onTap: widget.onBlockTap,
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  void _showEmptyContent(BuildContext context, String contentType) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No shared $contentType in this conversation yet.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final String time;
  final bool isOutgoing;
  final bool isRead;

  const ChatMessage({
    required this.text,
    required this.time,
    required this.isOutgoing,
    this.isRead = false,
  });
}
