import 'package:flutter/material.dart';

class ConversationScreen extends StatefulWidget {
  final String contactName;
  final String initials;
  final Color avatarColor;
  final bool isOnline;

  const ConversationScreen({
    super.key,
    required this.contactName,
    required this.initials,
    required this.avatarColor,
    this.isOnline = false,
  });

  @override
  State<ConversationScreen> createState() =>
      _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  static const Color _primaryColor = Color(0xFF075E54);
  static const Color _backgroundColor = Color(0xFFEFEAE2);
  static const Color _headingColor = Color(0xFF202C33);
  static const Color _secondaryColor = Color(0xFF667781);
  static const Color _incomingBubble = Colors.white;
  static const Color _outgoingBubble = Color(0xFFD9FDD3);

  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController = ScrollController();

  late final List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messages = _createSampleMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<ChatMessage> _createSampleMessages() {
    return [
      ChatMessage(
        text: 'Hey! How are you doing?',
        time: '09:15',
        isOutgoing: false,
      ),
      ChatMessage(
        text: "I'm fine, thank you! 😊",
        time: '09:16',
        isOutgoing: true,
        isRead: true,
      ),
      ChatMessage(
        text: 'That is great!',
        time: '09:16',
        isOutgoing: false,
      ),
      ChatMessage(
        text: 'How is your ASAP project going?',
        time: '09:17',
        isOutgoing: false,
      ),
      ChatMessage(
        text: 'It is coming along nicely. 🚀',
        time: '09:18',
        isOutgoing: true,
        isRead: true,
      ),
    ];
  }

  void _sendMessage() {
    final String text = _messageController.text.trim();

    if (text.isEmpty) return;

    final now = TimeOfDay.now();
    final String formattedTime = now.format(context);

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          time: formattedTime,
          isOutgoing: true,
          isRead: false,
        ),
      );
    });

    _messageController.clear();
    _scrollToLatestMessage();
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
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _openContactDetails() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: widget.avatarColor,
                  child: Text(
                    widget.initials,
                    style: const TextStyle(
                      color: _headingColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.contactName,
                  style: const TextStyle(
                    color: _headingColor,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isOnline ? 'Online' : 'ASAP contact',
                  style: const TextStyle(
                    color: _secondaryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                const ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: _primaryColor,
                  ),
                  title: Text('Contact information'),
                  subtitle: Text(
                    'Contact details will be available later.',
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
            icon: const Icon(
              Icons.call_outlined,
              color: _primaryColor,
            ),
          ),
          IconButton(
            tooltip: 'Video call',
            onPressed: () {
              _showDemoMessage(
                'Video calling will be available in a future update.',
              );
            },
            icon: const Icon(
              Icons.videocam_outlined,
              color: _primaryColor,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 18,
                ),
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildDateLabel();
                  }

                  final message = _messages[index - 1];

                  return _buildMessageBubble(message);
                },
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
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 7,
        ),
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
    final bool isOutgoing = message.isOutgoing;

    return Align(
      alignment: isOutgoing
          ? Alignment.centerRight
          : Alignment.centerLeft,
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
                  style: const TextStyle(
                    color: _secondaryColor,
                    fontSize: 10,
                  ),
                ),
                if (isOutgoing) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 15,
                    color: message.isRead
                        ? const Color(0xFF34B7F1)
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
                border: Border.all(
                  color: const Color(0xFFE0E0E0),
                ),
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
                  hintStyle: TextStyle(
                    color: _secondaryColor,
                    fontSize: 14,
                  ),
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
              icon: const Icon(
                Icons.send,
                color: Colors.white,
                size: 21,
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