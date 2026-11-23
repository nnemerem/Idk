import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';
import 'package:ripple/services/conversation_service.dart';

class DmsListScreen extends StatefulWidget {
  const DmsListScreen({super.key});

  @override
  State<DmsListScreen> createState() => _DmsListScreenState();
}

class _DmsListScreenState extends State<DmsListScreen> {
  List<Map<String, dynamic>> _conversations = [];
  final Map<String, int> _unreadCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
        if (currentUserId == null) return;

      // Get conversations with last message and other participant
      final response = await SupabaseService().client
          .from(RippleConstants.tableConversations)
          .select('''
            *,
            participants:conversation_participants!inner (
              user_id,
              profiles:user_id (id, username, display_name, avatar_url)
            ),
            last_message:messages!conversation_id (
              id,
              content,
              created_at,
              sender_id,
              is_read
            )
          ''')
          .eq('conversation_participants.user_id', currentUserId)
          .order('updated_at', ascending: false);

      final unread = await _loadUnreadCounts(currentUserId);

      if (mounted) {
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(response);
          _unreadCounts
            ..clear()
            ..addAll(unread);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, int>> _loadUnreadCounts(String currentUserId) async {
    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tableMessages)
          .select('conversation_id, sender_id')
          .eq('is_read', false);

      final counts = <String, int>{};
      for (final row in (response as List)) {
        if (row['sender_id'] == currentUserId) continue;
        final cid = row['conversation_id'] as String?;
        if (cid == null) continue;
        counts[cid] = (counts[cid] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RippleColors.background,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/edit.svg',
              width: 26,
              height: 26,
            ),
            onPressed: () => _showNewMessageSheet(),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _conversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  color: RippleColors.primary,
                  backgroundColor: RippleColors.surface,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = _conversations[index];
                      return _buildConversationTile(conversation);
                    },
                  ),
                ),
    );
  }

  void _showNewMessageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _NewMessageSheet(
        onSelectUser: (userId) async {
          Navigator.of(context).pop();
          final conversationId = await ConversationService.startConversation(userId);
          if (conversationId == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not start the conversation')),
              );
            }
            return;
          }
          if (mounted) {
            context.go('${RippleConstants.routeDms}/chat/$conversationId');
          }
        },
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final participants = conversation['participants'] as List<dynamic>?;
    final currentUserId = SupabaseService().currentUser?.id;
    final otherParticipant = participants?.firstWhere(
      (p) => p['user_id'] != currentUserId,
      orElse: () => null,
    );
    final profile = otherParticipant?['profiles'] as Map<String, dynamic>?;
    final lastMessage = conversation['last_message'] as Map<String, dynamic>?;
    final unreadCount = _unreadCounts[conversation['id'] as String?] ?? 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: RippleColors.surfaceVariant,
            backgroundImage: profile?['avatar_url'] != null
                ? CachedNetworkImageProvider(profile!['avatar_url'])
                : null,
            child: profile?['avatar_url'] == null
                ? Text(
                    profile?['username']?[0]?.toUpperCase() ?? '?',
                    style: const TextStyle(
                      color: RippleColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
        ],
      ),
      title: Text(
        profile?['display_name'] ?? profile?['username'] ?? 'Unknown',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: lastMessage != null
          ? Row(
              children: [
                if (lastMessage['sender_id'] == currentUserId)
                  SvgPicture.asset(
                    'assets/icons/done_all.svg',
                    width: 14,
                    height: 14,
                    colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
                  ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    lastMessage['content'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: RippleColors.textSecondary,
                    ),
                  ),
                ),
              ],
            )
          : Text(
              'No messages yet',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: RippleColors.textTertiary,
              ),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastMessage != null)
            Text(
              _formatTimestamp(lastMessage['created_at'] as String),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: RippleColors.textTertiary,
              ),
            ),
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: RippleColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        context.go('${RippleConstants.routeDms}/chat/${conversation['id']}');
      },
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return timeago.format(dateTime, locale: 'en_short');
    } catch (e) {
      return '';
    }
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: RippleColors.surfaceVariant,
        ),
        title: Container(
          width: 100,
          height: 16,
          decoration: BoxDecoration(
            color: RippleColors.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Container(
          width: 150,
          height: 14,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: RippleColors.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: RippleColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/icons/chat.svg',
                width: 40,
                height: 40,
                colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No messages yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: RippleColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you message people, your conversations will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: RippleColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showNewMessageSheet(),
              icon: SvgPicture.asset('assets/icons/edit.svg', width: 20, height: 20),
              label: const Text('Send Message'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewMessageSheet extends StatefulWidget {
  final Future<void> Function(String userId) onSelectUser;

  const _NewMessageSheet({required this.onSelectUser});

  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    if (query == _query) return;
    _query = query;
    _search(query);
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _users = []);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final currentUserId = SupabaseService().currentUser?.id;
      final response = await SupabaseService().client
          .from(RippleConstants.tableProfiles)
          .select('id, username, display_name, avatar_url')
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .neq('id', currentUserId ?? '')
          .limit(20);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseService().currentUser?.id;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: RippleColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RippleConstants.borderRadiusXLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: RippleColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/search.svg',
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(RippleColors.textSecondary, BlendMode.srcIn),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(color: RippleColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Search people',
                      hintStyle: TextStyle(color: RippleColors.textTertiary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      fillColor: Colors.transparent,
                    ),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                if (_query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _query = '';
                        _users = [];
                      });
                    },
                  ),
              ],
            ),
          ),
          const Divider(color: RippleColors.divider, height: 1),
          Flexible(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(color: RippleColors.primary),
                    ),
                  )
                : _query.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Type to search people',
                            style: TextStyle(color: RippleColors.textSecondary),
                          ),
                        ),
                      )
                    : _users.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No people found',
                                style: TextStyle(color: RippleColors.textSecondary),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shrinkWrap: true,
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              final username = user['username'] as String? ?? 'user';
                              final displayName = user['display_name'] as String? ?? username;
                              final avatarUrl = user['avatar_url'] as String?;
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: RippleColors.surfaceVariant,
                                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(avatarUrl)
                                      : null,
                                  child: avatarUrl == null || avatarUrl.isEmpty
                                      ? Text(
                                          username.isNotEmpty
                                              ? username[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: RippleColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  displayName,
                                  style: const TextStyle(color: RippleColors.textPrimary),
                                ),
                                subtitle: Text(
                                  '@$username',
                                  style: const TextStyle(color: RippleColors.textSecondary),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: RippleColors.textTertiary,
                                ),
                                onTap: () => widget.onSelectUser(user['id'] as String),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
