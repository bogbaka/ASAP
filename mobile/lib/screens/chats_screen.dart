import 'package:drift/drift.dart' show InsertMode, OrderingTerm, Value;
import 'package:flutter/material.dart';

import '../database/database_connection.dart';
import '../database/app_database.dart';
import 'conversation_screen.dart';
import 'account_settings_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key, required this.displayName});

  final String displayName;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  static const Color _primaryColor = Color(0xFF075E54);
  static const Color _accentColor = Color(0xFF25D366);

  int _selectedTab = 0;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  String? _myStatusText;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final Set<String> _favoriteNames = {};
  final Set<String> _archivedNames = {};

  // Saved conversation activity, used to put recently active chats first.
  // Chats that have never been saved keep their original sample order.
  final Map<String, DateTime> _conversationActivityTimes = {};

  // Each custom list stores the names of its selected conversations.
  final Map<String, Set<String>> _customLists = {};

  late final List<ChatConversation> _conversations = [
    ChatConversation(
      name: 'Amaka',
      initials: 'A',
      avatarColor: Colors.pink.shade300,
      message: 'Hey! How are you doing?',
      time: '9:18 AM',
      unreadCount: 2,
      isOnline: true,
    ),
    ChatConversation(
      name: 'Daniel',
      initials: 'D',
      avatarColor: Colors.blue.shade400,
      message: 'See you tomorrow!',
      time: '8:45 AM',
      unreadCount: 1,
      isOnline: false,
    ),
    ChatConversation(
      name: 'ASAP Developers',
      initials: 'AD',
      avatarColor: Colors.deepPurple.shade300,
      message: 'You: The mobile screens are ready.',
      time: 'Yesterday',
      unreadCount: 3,
      isOnline: false,
      isGroup: true,
    ),
    ChatConversation(
      name: 'Mum',
      initials: 'M',
      avatarColor: Colors.orange.shade400,
      message: 'Have you eaten?',
      time: 'Yesterday',
      unreadCount: 0,
      isOnline: false,
    ),
    ChatConversation(
      name: 'Samuel',
      initials: 'S',
      avatarColor: Colors.teal.shade300,
      message: 'Thank you so much!',
      time: 'Monday',
      unreadCount: 0,
      isOnline: false,
    ),
    ChatConversation(
      name: 'Study Group',
      initials: 'SG',
      avatarColor: Colors.indigo.shade300,
      message: 'Chinwe: Check the assignment.',
      time: 'Monday',
      unreadCount: 0,
      isOnline: false,
      isGroup: true,
    ),
    ChatConversation(
      name: 'Chinwe',
      initials: 'C',
      avatarColor: Colors.green.shade400,
      message: 'I will send it shortly.',
      time: 'Sunday',
      unreadCount: 0,
      isOnline: false,
    ),
  ];

  late final List<StatusUpdate> _statusUpdates = [
    StatusUpdate(
      name: 'Amaka',
      initials: 'A',
      avatarColor: Colors.pink.shade300,
      time: 'Today, 9:10 AM',
      text: 'Enjoying the beautiful day! 🌸',
    ),
    StatusUpdate(
      name: 'Daniel',
      initials: 'D',
      avatarColor: Colors.blue.shade400,
      time: 'Today, 8:30 AM',
      text: 'Keep working hard. Your dreams are worth it! 💪',
    ),
    StatusUpdate(
      name: 'Chinwe',
      initials: 'C',
      avatarColor: Colors.green.shade400,
      time: 'Yesterday, 6:20 PM',
      text: 'Good things take time. Stay patient. ❤️',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _refreshConversationPreviews();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Refresh chat-list previews from the local Drift database.
  // Sample previews remain visible for conversations that have never been saved.
  Future<void> _refreshConversationPreviews() async {
    try {
      final savedConversations =
          await appDatabase.select(appDatabase.conversations).get();
      _conversationActivityTimes
        ..clear()
        ..addEntries(
          savedConversations.map(
            (item) => MapEntry(item.id, item.updatedAt),
          ),
        );
      final savedIds = savedConversations.map((item) => item.id).toSet();

      for (final conversation in _conversations) {
        final conversationId = conversation.name.trim().toLowerCase();

        if (!savedIds.contains(conversationId)) {
          continue;
        }

        final allConversationMessages = await (
            appDatabase.select(appDatabase.messages)
              ..where((message) =>
                  message.conversationId.equals(conversationId)))
          .get();
        final unreadMessages = allConversationMessages
            .where((message) => !message.isOutgoing && !message.isRead)
            .toList();
        conversation.unreadCount = unreadMessages.length;

        final latestMessages = await (appDatabase.select(appDatabase.messages)
              ..where((message) =>
                  message.conversationId.equals(conversationId))
              ..orderBy([
                (message) => OrderingTerm.desc(message.sentAt),
                (message) => OrderingTerm.desc(message.id),
              ])
              ..limit(1))
            .get();

        if (latestMessages.isEmpty) {
          // The conversation exists, but its messages were cleared.
          conversation.message = '';
          conversation.time = '';
          continue;
        }

        final latest = latestMessages.first;
        conversation.message = latest.isOutgoing
            ? 'You: ${latest.content}'
            : latest.content;
        conversation.time = _formatConversationTime(latest.sentAt);
      }

      if (mounted) setState(() {});
    } catch (error) {
      // Keep the screen usable if local storage is temporarily unavailable.
      debugPrint('Unable to refresh chat previews: $error');
    }
  }

  String _formatConversationTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = today.difference(messageDay).inDays;

    if (difference == 0) {
      return TimeOfDay.fromDateTime(dateTime).format(context);
    }
    if (difference == 1) return 'Yesterday';
    if (difference >= 2 && difference < 7) {
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return weekdays[dateTime.weekday - 1];
    }

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  // Compare saved chats by their persisted last-activity timestamp.
  // Saved chats come before demo chats that have never been persisted.
  int _compareConversationActivity(
    ChatConversation first,
    ChatConversation second,
  ) {
    final firstId = first.name.trim().toLowerCase();
    final secondId = second.name.trim().toLowerCase();
    final firstActivity = _conversationActivityTimes[firstId];
    final secondActivity = _conversationActivityTimes[secondId];

    if (firstActivity == null && secondActivity == null) return 0;
    if (firstActivity == null) return 1;
    if (secondActivity == null) return -1;
    return secondActivity.compareTo(firstActivity);
  }

  // Apply search and the selected chat filter, newest activity first.
  List<ChatConversation> get _filteredConversations {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = _conversations.where((conversation) {
      if (_archivedNames.contains(conversation.name)) {
        return false;
      }

      if (query.isNotEmpty &&
          !conversation.name.toLowerCase().contains(query)) {
        return false;
      }

      switch (_selectedFilter) {
        case 'Unread':
          if (conversation.unreadCount == 0) return false;
          break;

        case 'Favorites':
          if (!_favoriteNames.contains(conversation.name)) {
            return false;
          }
          break;

        case 'Groups':
          if (!conversation.isGroup) return false;
          break;

        default:
          if (_customLists.containsKey(_selectedFilter)) {
            if (!_customLists[_selectedFilter]!.contains(conversation.name)) {
              return false;
            }
          }
      }

      return true;
    }).toList();

    // Use the initial list position as a tie-breaker so demo chats with no
    // database record remain in their existing order.
    final originalPositions = <String, int>{
      for (var index = 0; index < _conversations.length; index++)
        _conversations[index].name: index,
    };
    filtered.sort((first, second) {
      final activityComparison =
          _compareConversationActivity(first, second);
      if (activityComparison != 0) return activityComparison;
      return originalPositions[first.name]!.compareTo(
        originalPositions[second.name]!,
      );
    });
    return filtered;
  }

  List<ChatConversation> get _archivedConversations {
    final archived = _conversations
        .where((conversation) => _archivedNames.contains(conversation.name))
        .toList();
    final originalPositions = <String, int>{
      for (var index = 0; index < _conversations.length; index++)
        _conversations[index].name: index,
    };
    archived.sort((first, second) {
      final activityComparison =
          _compareConversationActivity(first, second);
      if (activityComparison != 0) return activityComparison;
      return originalPositions[first.name]!.compareTo(
        originalPositions[second.name]!,
      );
    });
    return archived;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildAvatar(ChatConversation conversation, {double radius = 26}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: conversation.avatarColor,
      child: Text(
        conversation.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Opening a chat marks incoming messages as read and persists that state.
  Future<void> _openConversation(ChatConversation conversation) async {
    final conversationId = conversation.name.trim().toLowerCase();

    // Clear the visible badge immediately, before opening the conversation.
    if (mounted) {
      setState(() => conversation.unreadCount = 0);
    }

    try {
      // Create a local conversation record if this is still a sample chat.
      // insertOrIgnore preserves the existing preview and activity timestamp.
      await appDatabase.into(appDatabase.conversations).insert(
            ConversationsCompanion(
              id: Value(conversationId),
              contactName: Value(conversation.name),
            ),
            mode: InsertMode.insertOrIgnore,
          );

      await (appDatabase.update(appDatabase.messages)
            ..where((message) =>
                message.conversationId.equals(conversationId)))
          .write(const MessagesCompanion(isRead: Value(true)));
    } catch (error) {
      debugPrint('Unable to mark conversation as read: $error');
    }

    if (!mounted) return;

    if (!mounted) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationScreen(
          contactName: conversation.name,
          initials: conversation.initials,
          avatarColor: conversation.avatarColor,
          isOnline: conversation.isOnline,
        ),
      ),
    );

    if (mounted) await _refreshConversationPreviews();
  }

  // Favorite or unfavorite a conversation.
  void _toggleFavorite(ChatConversation conversation) {
    setState(() {
      if (_favoriteNames.contains(conversation.name)) {
        _favoriteNames.remove(conversation.name);
      } else {
        _favoriteNames.add(conversation.name);
      }
    });

    _showMessage(
      _favoriteNames.contains(conversation.name)
          ? '${conversation.name} added to Favorites.'
          : '${conversation.name} removed from Favorites.',
    );
  }

  // Archive a conversation without deleting it.
  void _archiveConversation(ChatConversation conversation) {
    setState(() {
      _archivedNames.add(conversation.name);
    });

    _showMessage('${conversation.name} moved to Archived Chats.');
  }

  // Restore an archived conversation.
  void _unarchiveConversation(ChatConversation conversation) {
    setState(() {
      _archivedNames.remove(conversation.name);
    });

    _showMessage('${conversation.name} restored to Chats.');
  }

  // Options for an individual conversation.
  void _showConversationMenu(ChatConversation conversation) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(
                  _favoriteNames.contains(conversation.name)
                      ? Icons.star
                      : Icons.star_border,
                  color: Colors.amber.shade700,
                ),
                title: Text(
                  _favoriteNames.contains(conversation.name)
                      ? 'Remove from Favorites'
                      : 'Add to Favorites',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _toggleFavorite(conversation);
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Archive chat'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _archiveConversation(conversation);
                },
              ),
              ListTile(
                leading: const Icon(Icons.mark_chat_read_outlined),
                title: Text(
                  conversation.unreadCount > 0
                      ? 'Mark as read'
                      : 'Mark as unread',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);

                  setState(() {
                    conversation.unreadCount = conversation.unreadCount > 0
                        ? 0
                        : 1;
                  });

                  _showMessage(
                    conversation.unreadCount == 0
                        ? 'Chat marked as read.'
                        : 'Chat marked as unread.',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Create a custom chat list.
  Future<void> _createCustomList() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create custom list'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: 'List name',
              hintText: 'e.g. Close Friends',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isEmpty) return;

                if (['All', 'Unread', 'Favorites', 'Groups'].contains(value) ||
                    _customLists.containsKey(value)) {
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              child: const Text('Next'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || name == null || name.isEmpty) return;

    final selectedNames = <String>{};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add chats to $name'),
              content: SizedBox(
                width: double.maxFinite,
                height: 320,
                child: ListView(
                  children: _conversations
                      .where((chat) => !_archivedNames.contains(chat.name))
                      .map((chat) {
                        return CheckboxListTile(
                          value: selectedNames.contains(chat.name),
                          title: Text(chat.name),
                          secondary: _buildAvatar(chat, radius: 18),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (selected) {
                            setDialogState(() {
                              if (selected == true) {
                                selectedNames.add(chat.name);
                              } else {
                                selectedNames.remove(chat.name);
                              }
                            });
                          },
                        );
                      })
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Create list'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _customLists[name] = Set<String>.from(selectedNames);
      _selectedFilter = name;
    });

    _showMessage('Custom list "$name" created.');
  }

  // Update the selected filter.
  void _selectFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  Widget _buildFilterChip(String label) {
    final selected = _selectedFilter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: _primaryColor,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? _primaryColor : Colors.grey.shade300,
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        onSelected: (_) => _selectFilter(label),
      ),
    );
  }

  // Show Archived Chats.
  void _showArchivedChats() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final archived = _archivedConversations;

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Archived Chats',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${archived.length}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: archived.isEmpty
                          ? _buildEmptyState(
                              icon: Icons.archive_outlined,
                              title: 'No archived chats',
                              subtitle: 'Chats you archive will appear here.',
                            )
                          : ListView.separated(
                              itemCount: archived.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1, indent: 84),
                              itemBuilder: (context, index) {
                                final conversation = archived[index];

                                return ListTile(
                                  leading: _buildAvatar(conversation),
                                  title: Text(conversation.name),
                                  subtitle: Text(
                                    conversation.message,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Restore chat',
                                    icon: const Icon(Icons.unarchive_outlined),
                                    onPressed: () {
                                      _unarchiveConversation(conversation);
                                      setSheetState(() {});
                                    },
                                  ),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _openConversation(conversation);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // Search and filter the chat list.
  Widget _buildChatsTab() {
    final conversations = _filteredConversations;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search chats',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();

                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.close),
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // All, Unread, Favorites, Groups and custom lists.
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip('All'),
              _buildFilterChip('Unread'),
              _buildFilterChip('Favorites'),
              _buildFilterChip('Groups'),
              ..._customLists.keys.map(_buildFilterChip),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text(''),
                  tooltip: 'Create custom chat list',
                  onPressed: _createCustomList,
                ),
              ),
            ],
          ),
        ),

        // Archived Chats shortcut.
        if (_archivedNames.isNotEmpty)
          ListTile(
            dense: true,
            leading: const Icon(Icons.archive_outlined, color: _primaryColor),
            title: const Text(
              'Archived',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_archivedNames.length}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: _showArchivedChats,
          ),

        Expanded(
          child: conversations.isEmpty
              ? _buildEmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'No conversations found',
                  subtitle: _selectedFilter == 'Favorites'
                      ? 'Add chats to Favorites using their chat menu.'
                      : _selectedFilter == 'Unread'
                      ? 'You have no unread conversations.'
                      : _selectedFilter == 'Groups'
                      ? 'No group conversations found.'
                      : 'Try a different search or filter.',
                )
              : ListView.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (context, index) {
                    return const Divider(height: 1, indent: 84, endIndent: 16);
                  },
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildAvatar(conversation),
                          if (conversation.isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: _accentColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              conversation.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (conversation.isGroup) ...[
                            const SizedBox(width: 5),
                            Icon(
                              Icons.groups,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          ],
                          if (_favoriteNames.contains(conversation.name)) ...[
                            const SizedBox(width: 5),
                            Icon(
                              Icons.star,
                              size: 15,
                              color: Colors.amber.shade700,
                            ),
                          ],
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          conversation.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: conversation.unreadCount > 0
                                ? Colors.black87
                                : Colors.grey.shade600,
                            fontWeight: conversation.unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      trailing: SizedBox(
                        width: 78,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              conversation.time,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: conversation.unreadCount > 0
                                    ? _primaryColor
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (conversation.unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: _accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${conversation.unreadCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: IconButton(
                                    tooltip: 'Chat options',
                                    padding: EdgeInsets.zero,
                                    iconSize: 19,
                                    onPressed: () =>
                                        _showConversationMenu(conversation),
                                    icon: const Icon(Icons.more_horiz),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      onTap: () => _openConversation(conversation),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Start a new chat.
  void _startNewChat() {
    final availableChats = _conversations
        .where((chat) => !_archivedNames.contains(chat.name))
        .toList();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Start a new chat',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: availableChats.length,
                    itemBuilder: (context, index) {
                      final conversation = availableChats[index];

                      return ListTile(
                        leading: _buildAvatar(conversation),
                        title: Text(conversation.name),
                        subtitle: Text(
                          conversation.isGroup
                              ? 'Group conversation'
                              : 'Start a conversation',
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _openConversation(conversation);
                        },
                      );
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

  // Create a group from selected contacts.
  Future<void> _createGroup() async {
    final selectedNames = <String>{};
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New group'),
              content: SizedBox(
                width: double.maxFinite,
                height: 390,
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Group name',
                        hintText: 'Enter a group name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Add participants'),
                    ),
                    Expanded(
                      child: ListView(
                        children: _conversations
                            .where(
                              (chat) =>
                                  !chat.isGroup &&
                                  !_archivedNames.contains(chat.name),
                            )
                            .map((chat) {
                              return CheckboxListTile(
                                value: selectedNames.contains(chat.name),
                                title: Text(chat.name),
                                onChanged: (selected) {
                                  setDialogState(() {
                                    if (selected == true) {
                                      selectedNames.add(chat.name);
                                    } else {
                                      selectedNames.remove(chat.name);
                                    }
                                  });
                                },
                              );
                            })
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();

                    if (name.isEmpty || selectedNames.isEmpty) {
                      return;
                    }

                    Navigator.pop(dialogContext, name);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();

    if (!mounted || result == null || result.isEmpty) return;

    if (_conversations.any(
      (chat) => chat.name.toLowerCase() == result.toLowerCase(),
    )) {
      _showMessage('A chat with that name already exists.');
      return;
    }

    setState(() {
      _conversations.insert(
        0,
        ChatConversation(
          name: result,
          initials: _getInitials(result),
          avatarColor: Colors.deepPurple.shade300,
          message: 'Group created with ${selectedNames.length} members.',
          time: 'Just now',
          unreadCount: 0,
          isOnline: false,
          isGroup: true,
        ),
      );

      _selectedTab = 0;
      _selectedFilter = 'All';
    });

    _showMessage('Group "$result" created locally.');
  }

  // Create a local broadcast-list demonstration.
  Future<void> _createBroadcast() async {
    final selectedNames = <String>{};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final contacts = _conversations.where(
              (chat) => !chat.isGroup && !_archivedNames.contains(chat.name),
            );

            return AlertDialog(
              title: const Text('New broadcast'),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: Column(
                  children: [
                    const Text('Choose contacts for your broadcast list.'),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: contacts.map((chat) {
                          return CheckboxListTile(
                            value: selectedNames.contains(chat.name),
                            title: Text(chat.name),
                            onChanged: (selected) {
                              setDialogState(() {
                                if (selected == true) {
                                  selectedNames.add(chat.name);
                                } else {
                                  selectedNames.remove(chat.name);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedNames.isEmpty
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: const Text('Create list'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || confirmed != true) return;

    _showMessage(
      'Broadcast list created for ${selectedNames.length} contacts (demo).',
    );
  }

  // Linked devices information.
  void _showLinkedDevices() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.devices_other, size: 42, color: _primaryColor),
          title: const Text('Linked devices'),
          content: const Text(
            'No devices are linked to this account yet.\n\n'
            'Device linking and secure session management will '
            'be connected to the backend later.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showMessage('Secure device linking is coming soon.');
              },
              child: const Text('Link a device'),
            ),
          ],
        );
      },
    );
  }

  void _showStarredMessages() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.star_outline, size: 42, color: _primaryColor),
          title: const Text('Starred messages'),
          content: const Text(
            'Your starred messages will appear here once '
            'message starring is implemented.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Main three-dot menu.
  void _handleMenuSelection(String value) {
    switch (value) {
      case 'new_group':
        _createGroup();
        break;
      case 'new_broadcast':
        _createBroadcast();
        break;
      case 'archived':
        _showArchivedChats();
        break;
      case 'linked_devices':
        _showLinkedDevices();
        break;
      case 'starred':
        _showStarredMessages();
        break;
      case 'settings':
        Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        break;
    }
  }

  // Profile bottom sheet.
  void _showProfile() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: _primaryColor,
                child: Text(
                  _getInitials(widget.displayName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text('ASAP member', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Edit profile'),
                subtitle: const Text('Profile editing is coming soon'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showMessage('Profile editing is coming soon.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Create a text status.
  Future<void> _createStatus() async {
    final controller = TextEditingController(text: _myStatusText ?? '');

    final statusText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create text status'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 300,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'What is on your mind?',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();

                if (text.isEmpty) return;

                Navigator.pop(dialogContext, text);
              },
              child: const Text('Share'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || statusText == null || statusText.isEmpty) {
      return;
    }

    setState(() {
      _myStatusText = statusText;

      final existingIndex = _statusUpdates.indexWhere(
        (status) => status.isMine,
      );

      final myStatus = StatusUpdate(
        name: 'My status',
        initials: _getInitials(widget.displayName),
        avatarColor: _primaryColor,
        time: 'Just now',
        text: statusText,
        isMine: true,
      );

      if (existingIndex >= 0) {
        _statusUpdates[existingIndex] = myStatus;
      } else {
        _statusUpdates.insert(0, myStatus);
      }
    });

    _showMessage('Your status has been shared.');
  }

  void _openStatus(StatusUpdate status) {
    final index = _statusUpdates.indexOf(status);

    if (index < 0) return;

    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => StatusViewerScreen(
          statuses: List<StatusUpdate>.from(_statusUpdates),
          initialIndex: index,
        ),
      ),
    );
  }

  Widget _buildStatusAvatar(StatusUpdate status, {double radius = 26}) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: status.isMine && _myStatusText == null
              ? Colors.grey.shade300
              : _accentColor,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: status.avatarColor,
        child: Text(
          status.initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Updates / Status tab.
  Widget _buildUpdatesTab() {
    final myStatus = _statusUpdates.where((status) => status.isMine);

    final contactStatuses = _statusUpdates.where((status) => !status.isMine);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Status',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              if (myStatus.isNotEmpty)
                _buildStatusAvatar(myStatus.first)
              else
                CircleAvatar(
                  radius: 29,
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(
                    Icons.person,
                    color: Colors.grey.shade600,
                    size: 30,
                  ),
                ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 23,
                  height: 23,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 17),
                ),
              ),
            ],
          ),
          title: const Text(
            'My status',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _myStatusText ?? 'Tap to add a status update',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: _myStatusText == null
              ? _createStatus
              : () => _openStatus(
                  _statusUpdates.firstWhere((status) => status.isMine),
                ),
        ),
        const SizedBox(height: 20),
        Text(
          'Recent updates',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (contactStatuses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No recent updates.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ...contactStatuses.map((status) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _buildStatusAvatar(status),
            title: Text(
              status.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(status.time),
            onTap: () => _openStatus(status),
          );
        }),
      ],
    );
  }

  // Calls tab.
  Widget _buildCallsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Recent calls',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._conversations.take(4).map((conversation) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 5),
            leading: _buildAvatar(conversation),
            title: Text(
              conversation.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Row(
              children: [
                Icon(Icons.call_made, size: 15, color: _accentColor),
                SizedBox(width: 5),
                Text('Today'),
              ],
            ),
            trailing: IconButton(
              tooltip: 'Voice call',
              icon: const Icon(Icons.call_outlined, color: _primaryColor),
              onPressed: () {
                _showMessage('Voice calls are coming soon.');
              },
            ),
            onTap: () => _openConversation(conversation),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'ASAP',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Search chats',
            onPressed: () {
              setState(() {
                _selectedTab = 0;
                _selectedFilter = 'All';
              });

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _searchFocusNode.requestFocus();
                }
              });
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Your profile',
            onPressed: _showProfile,
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: Colors.white,
              child: Text(
                _getInitials(widget.displayName),
                style: const TextStyle(
                  color: _primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new_group',
                child: ListTile(
                  leading: Icon(Icons.group_add_outlined),
                  title: Text('New group'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'new_broadcast',
                child: ListTile(
                  leading: Icon(Icons.campaign_outlined),
                  title: Text('New broadcast'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'archived',
                child: ListTile(
                  leading: Icon(Icons.archive_outlined),
                  title: Text('Archived Chats'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'linked_devices',
                child: ListTile(
                  leading: Icon(Icons.devices_outlined),
                  title: Text('Linked devices'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'starred',
                child: ListTile(
                  leading: Icon(Icons.star_outline),
                  title: Text('Starred messages'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [_buildChatsTab(), _buildUpdatesTab(), _buildCallsTab()],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        tooltip: _selectedTab == 0
            ? 'New chat'
            : _selectedTab == 1
            ? 'New status'
            : 'New call',
        onPressed: () {
          if (_selectedTab == 0) {
            _startNewChat();
          } else if (_selectedTab == 1) {
            _createStatus();
          } else {
            _showMessage('Voice calls are coming soon.');
          }
        },
        child: Icon(
          _selectedTab == 0
              ? Icons.chat
              : _selectedTab == 1
              ? Icons.camera_alt
              : Icons.add_call,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            _selectedTab = index;
          });
        },
        indicatorColor: _accentColor.withValues(alpha: 0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.circle_outlined),
            selectedIcon: Icon(Icons.circle),
            label: 'Updates',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call),
            label: 'Calls',
          ),
        ],
      ),
    );
  }
}

// Settings screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const Color _primaryColor = Color(0xFF075E54);

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature settings are coming soon.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: _primaryColor,
              child: Icon(Icons.person, color: Colors.white, size: 30),
            ),
            title: Text(
              'ASAP account',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Manage your account details'),
          ),
          const Divider(height: 1),
          _SettingsItem(
            icon: Icons.person_outline,
            title: 'Account',
            subtitle: 'Security and account information',
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AccountSettingsScreen(),
                ),
              );
            },
          ),
          _SettingsItem(
            icon: Icons.lock_outline,
            title: 'Privacy',
            subtitle: 'Control who can see your information',
            onTap: () => _showComingSoon(context, 'Privacy'),
          ),
          _SettingsItem(
            icon: Icons.chat_bubble_outline,
            title: 'Chats',
            subtitle: 'Chat display and conversation options',
            onTap: () => _showComingSoon(context, 'Chats'),
          ),
          _SettingsItem(
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'Message and call notifications',
            onTap: () => _showComingSoon(context, 'Notifications'),
          ),
          _SettingsItem(
            icon: Icons.storage_outlined,
            title: 'Storage and data',
            subtitle: 'Manage storage and data usage',
            onTap: () => _showComingSoon(context, 'Storage and data'),
          ),
          _SettingsItem(
            icon: Icons.devices_outlined,
            title: 'Linked devices',
            subtitle: 'Manage connected devices',
            onTap: () => _showComingSoon(context, 'Linked devices'),
          ),
          _SettingsItem(
            icon: Icons.help_outline,
            title: 'Help',
            subtitle: 'Help centre and app information',
            onTap: () => _showComingSoon(context, 'Help'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'ASAP · Messaging made simple',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF075E54)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// Model representing a chat conversation.
class ChatConversation {
  ChatConversation({
    required this.name,
    required this.initials,
    required this.avatarColor,
    required this.message,
    required this.time,
    required this.unreadCount,
    required this.isOnline,
    this.isGroup = false,
  });

  final String name;
  final String initials;
  final Color avatarColor;
  String message;
  String time;
  int unreadCount;
  final bool isOnline;
  final bool isGroup;
}

// Model representing a text status.
class StatusUpdate {
  const StatusUpdate({
    required this.name,
    required this.initials,
    required this.avatarColor,
    required this.time,
    required this.text,
    this.isMine = false,
  });

  final String name;
  final String initials;
  final Color avatarColor;
  final String time;
  final String text;
  final bool isMine;
}

// Full-screen status viewer with a local status-reply draft.
class StatusViewerScreen extends StatefulWidget {
  const StatusViewerScreen({
    super.key,
    required this.statuses,
    required this.initialIndex,
  });

  final List<StatusUpdate> statuses;
  final int initialIndex;

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late final AnimationController _progressController;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocus = FocusNode();
  static const Duration _statusDuration = Duration(seconds: 5);

  StatusUpdate get _currentStatus => widget.statuses[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.statuses.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.statuses.length - 1);
    _progressController = AnimationController(
      vsync: this,
      duration: _statusDuration,
    )..addStatusListener(_handleProgressStatus);
    _replyFocus.addListener(() {
      if (_replyFocus.hasFocus) {
        _progressController.stop();
      } else if (mounted && widget.statuses.isNotEmpty) {
        _progressController.forward();
      }
    });
    if (widget.statuses.isNotEmpty) _startProgress();
  }

  void _startProgress() {
    _replyController.clear();
    _replyFocus.unfocus();
    _progressController
      ..stop()
      ..reset()
      ..forward();
  }

  void _handleProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) _showNextStatus();
  }

  void _showNextStatus() {
    if (_currentIndex < widget.statuses.length - 1) {
      setState(() => _currentIndex++);
      _startProgress();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _showPreviousStatus() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
    _startProgress();
  }

  void _openReplyConversation() {
    final reply = _replyController.text.trim();
    if (reply.isEmpty || _currentStatus.isMine) return;
    final status = _currentStatus;
    _progressController.stop();
    _replyFocus.unfocus();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          contactName: status.name,
          initials: status.initials,
          avatarColor: status.avatarColor,
          initialReply: reply,
          repliedStatusText: status.text,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _replyFocus.dispose();
    _replyController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.statuses.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF101010),
        appBar: AppBar(title: const Text('Status')),
        body: const Center(child: Text('No status updates available.',
            style: TextStyle(color: Colors.white))),
      );
    }
    final status = _currentStatus;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF101010),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [status.avatarColor.withValues(alpha: 0.95),
                      const Color(0xFF101010)],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 90, 32, 100),
                    child: Text(status.text, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 28,
                        fontWeight: FontWeight.w600, height: 1.4)),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(children: [
                Expanded(child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _showPreviousStatus,
                  child: const SizedBox.expand(),
                )),
                Expanded(child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _showNextStatus,
                  child: const SizedBox.expand(),
                )),
              ]),
            ),
            Positioned(
              top: 8, left: 12, right: 12,
              child: Column(children: [
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) => LinearProgressIndicator(
                    value: _progressController.value,
                    backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  CircleAvatar(backgroundColor: status.avatarColor,
                    child: Text(status.initials,
                      style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(status.name, style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(status.time, style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
                    ],
                  )),
                  IconButton(tooltip: 'Close status',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white)),
                ]),
              ]),
            ),
            if (!status.isMine)
              Positioned(
                left: 12, right: 12, bottom: 12,
                child: Row(children: [
                  Expanded(child: TextField(
                    controller: _replyController,
                    focusNode: _replyFocus,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3, minLines: 1,
                    onSubmitted: (_) => _openReplyConversation(),
                    decoration: InputDecoration(
                      hintText: 'Reply to ${status.name}...',
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0x99000000),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: const BorderSide(color: Colors.white70)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: const BorderSide(color: Colors.white70)),
                    ),
                  )),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Continue reply in chat',
                    onPressed: _openReplyConversation,
                    icon: const Icon(Icons.send),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}