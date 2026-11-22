import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/router.dart';
import '../../services/supabase_service.dart';
import '../chat/chat_screen.dart';

class DmsListScreen extends StatefulWidget {
  const DmsListScreen({super.key});

  @override
  State<DmsListScreen> createState() => _DmsListScreenState();
}

class _DmsListScreenState extends State<DmsListScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final currentUserId = SupabaseService().currentUser?.id;
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

      if (mounted) {
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
            onPressed: () {
              // TODO: New message screen
            },
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

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final participants = conversation['participants'] as List<dynamic>?;
    final currentUserId = SupabaseService().currentUser?.id;
    final otherParticipant = participants?.firstWhere(
      (p) => p['user_id'] != currentUserId,
      orElse: () => null,
    );
    final profile = otherParticipant?['profiles'] as Map<String, dynamic>?;
    final lastMessage = conversation['last_message'] as Map<String, dynamic>?;
    final unreadCount = conversation['unread_count'] as int? ?? 0;

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
          // Online indicator (placeholder)
          if (false) // TODO: Add online status
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: RippleColors.onlineGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: RippleColors.background, width: 2),
                ),
              ),
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
              onPressed: () {
                // TODO: New message
              },
              icon: SvgPicture.asset('assets/icons/edit.svg', width: 20, height: 20),
              label: const Text('Send Message'),
            ),
          ],
        ),
      ),
    );
  }
}