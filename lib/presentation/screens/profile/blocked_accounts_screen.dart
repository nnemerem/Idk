import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';
import 'package:ripple/core/utils/guest_mode.dart';

/// Screen listing accounts the current user has blocked, with an unblock
/// action for each. Guest-mode guarded.
class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({super.key});

  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  List<Map<String, dynamic>> _blocked = [];
  bool _isLoading = true;
  final Set<String> _unblocking = {};

  @override
  void initState() {
    super.initState();
    _loadBlocked();
  }

  Future<void> _loadBlocked() async {
    if (GuestMode.isGuestMode) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final blocked = await SupabaseService().getBlockedAccounts();
      if (mounted) {
        setState(() {
          _blocked = blocked;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unblock(String targetUserId, String username) async {
    setState(() => _unblocking.add(targetUserId));
    try {
      await SupabaseService().unblockUser(targetUserId);
      if (mounted) {
        setState(() {
          _blocked.removeWhere((b) => b['blocked_id'] == targetUserId);
          _unblocking.remove(targetUserId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unblocked @$username'),
            backgroundColor: RippleColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _unblocking.remove(targetUserId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to unblock'),
            backgroundColor: RippleColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RippleColors.background,
      appBar: AppBar(
        title: const Text('Blocked Accounts', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: RippleColors.primary))
          : _blocked.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _blocked.length,
                  itemBuilder: (context, index) {
                    final entry = _blocked[index];
                    final profile = entry['blocked'] as Map<String, dynamic>?;
                    final username = profile?['username'] as String? ?? 'unknown';
                    final displayName = profile?['display_name'] as String? ?? username;
                    final avatarUrl = profile?['avatar_url'] as String?;
                    final blockedId = entry['blocked_id'] as String? ?? '';
                    final isUnblocking = _unblocking.contains(blockedId);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.go('/user/$username'),
                        borderRadius: BorderRadius.circular(RippleConstants.borderRadiusMedium),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: RippleColors.divider, width: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: RippleColors.surfaceVariant,
                                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(avatarUrl)
                                    : null,
                                child: (avatarUrl == null || avatarUrl.isEmpty)
                                    ? Text(
                                        username[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: RippleColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        color: RippleColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '@$username',
                                      style: const TextStyle(
                                        color: RippleColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isUnblocking)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(RippleColors.textSecondary),
                                  ),
                                )
                              else
                                TextButton(
                                  onPressed: () => _unblock(blockedId, username),
                                  style: TextButton.styleFrom(
                                    foregroundColor: RippleColors.error,
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Unblock',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
            child: const Icon(
              Icons.block,
              color: RippleColors.textSecondary,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No blocked accounts',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: RippleColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Blocked accounts will appear here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RippleColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
