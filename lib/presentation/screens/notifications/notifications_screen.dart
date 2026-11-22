import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';

/// Notifications screen — lists the signed-in user's activity
/// (likes, follows, mentions, comments) from the notifications table.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _isMarkingRead = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool markRead = false}) async {
    try {
      final userId = SupabaseService().currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final response = await SupabaseService().client
          .from(RippleConstants.tableNotifications)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }

      if (markRead) {
        await _markAllRead();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_isMarkingRead) return;
    final userId = SupabaseService().currentUser?.id;
    if (userId == null) return;

    _isMarkingRead = true;
    try {
      await SupabaseService().client
          .from(RippleConstants.tableNotifications)
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
      if (mounted) {
        setState(() {
          for (final n in _notifications) {
            n['is_read'] = true;
          }
        });
      }
    } catch (e) {
      // Best effort — the list is still shown
    } finally {
      _isMarkingRead = false;
    }
  }

  int get _unreadCount =>
      _notifications.where((n) => n['is_read'] != true).length;

  Future<void> _onRefresh() async {
    await _loadNotifications(markRead: true);
  }

  @override
  void dispose() {
    // Mark unread notifications as read once the screen closes so the
    // app stays honest (no fake badges after viewing).
    _markAllRead();
    super.dispose();
  }

  String _iconFor(String? type) {
    switch (type) {
      case 'like':
      case 'post_like':
      case 'reel_like':
        return 'assets/icons/heart_filled.svg';
      case 'follow':
        return 'assets/icons/person_add.svg';
      case 'comment':
      case 'post_comment':
      case 'reel_comment':
        return 'assets/icons/comment.svg';
      case 'mention':
      case 'tag':
        return 'assets/icons/tag.svg';
      case 'share':
        return 'assets/icons/send.svg';
      default:
        return 'assets/icons/notification.svg';
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'like':
      case 'post_like':
      case 'reel_like':
        return RippleColors.rose;
      case 'follow':
        return RippleColors.primary;
      case 'comment':
      case 'post_comment':
      case 'reel_comment':
        return RippleColors.tertiary;
      case 'mention':
      case 'tag':
        return RippleColors.quaternary;
      default:
        return RippleColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RippleColors.background,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: RippleColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(RippleConstants.borderRadiusFull),
                  ),
                  child: Text(
                    '$_unreadCount unread',
                    style: TextStyle(
                      color: RippleColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.done_all_outlined),
            tooltip: 'Mark all as read',
            onPressed: _isLoading ? null : _markAllRead,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: RippleColors.primary,
        backgroundColor: RippleColors.surface,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: RippleColors.primary),
              )
            : _notifications.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) =>
                        _buildNotificationTile(_notifications[index]),
                  ),
      ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> notification) {
    final type = notification['type'] as String?;
    final title = notification['title'] as String?;
    final body = notification['body'] as String?;
    final isRead = notification['is_read'] == true;
    final createdAt = notification['created_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isRead ? RippleColors.surface : RippleColors.surfaceVariant,
        borderRadius: BorderRadius.circular(RippleConstants.borderRadiusMedium),
        border: Border.all(
          color: RippleColors.divider,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _colorFor(type).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              _iconFor(type),
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(_colorFor(type), BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title.isNotEmpty)
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isRead ? RippleColors.textSecondary : RippleColors.textPrimary,
                        ),
                  ),
                if (body != null && body.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: title != null && title.isNotEmpty ? 2 : 0),
                    child: Text(
                      body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: RippleColors.textSecondary,
                          ),
                    ),
                  ),
                if (createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      timeago.format(DateTime.tryParse(createdAt) ?? DateTime.now()),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: RippleColors.textTertiary,
                            fontSize: 11,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          if (!isRead)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: RippleColors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
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
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: RippleColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/icons/notification.svg',
                width: 42,
                height: 42,
                colorFilter: ColorFilter.mode(
                  RippleColors.textTertiary,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No notifications yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: RippleColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'When people like, follow, or mention you,\nthey\'ll show up here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: RippleColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.go(RippleConstants.routeFeed),
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Back to feed'),
            ),
          ],
        ),
      ),
    );
  }
}
