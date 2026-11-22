import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';

/// Bottom sheet listing followers or following for a profile.
class FollowersListSheet extends StatefulWidget {
  final String profileId;
  final bool isFollowers;

  const FollowersListSheet({
    super.key,
    required this.profileId,
    required this.isFollowers,
  });

  static Future<void> show(
    BuildContext context, {
    required String profileId,
    required bool isFollowers,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FollowersListSheet(profileId: profileId, isFollowers: isFollowers),
    );
  }

  @override
  State<FollowersListSheet> createState() => _FollowersListSheetState();
}

class _FollowersListSheetState extends State<FollowersListSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = SupabaseService().client;
      final response = await client
          .from(RippleConstants.tableFollows)
          .select('''
            follower_id,
            following_id,
            follower:profiles!follows_follower_id_fkey (id, username, display_name, avatar_url),
            following:profiles!follows_following_id_fkey (id, username, display_name, avatar_url)
          ''')
          .eq(widget.isFollowers ? 'following_id' : 'follower_id', widget.profileId);

      final users = <Map<String, dynamic>>[];
      for (final row in (response as List)) {
        final user = widget.isFollowers
            ? row['follower']
            : row['following'];
        if (user is Map<String, dynamic>) {
          users.add(user);
        }
      }

      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
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
            child: Text(
              widget.isFollowers ? 'Followers' : 'Following',
              style: const TextStyle(
                color: RippleColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const Divider(color: RippleColors.divider, height: 1),
          Flexible(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: RippleColors.primary),
                    ),
                  )
                : _users.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            widget.isFollowers ? 'No followers yet' : 'Not following anyone yet',
                            style: const TextStyle(color: RippleColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shrinkWrap: true,
                        itemCount: _users.length,
                        itemBuilder: (context, index) =>
                            _buildUserRow(_users[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> user) {
    final username = user['username'] as String? ?? 'unknown';
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
                username[0].toUpperCase(),
                style: const TextStyle(color: RippleColors.textPrimary, fontWeight: FontWeight.w600),
              )
            : null,
      ),
      title: Text(displayName, style: const TextStyle(color: RippleColors.textPrimary)),
      subtitle: Text('@$username', style: const TextStyle(color: RippleColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right, color: RippleColors.textTertiary),
      onTap: () {
        Navigator.of(context).pop();
        context.go('/user/$username');
      },
    );
  }
}
