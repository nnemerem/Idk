import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';
import 'package:ripple/core/utils/guest_mode.dart';

/// Screen listing accounts the current user has restricted, with an
/// unrestrict action for each. Guest-mode guarded.
class RestrictedAccountsScreen extends StatefulWidget {
  const RestrictedAccountsScreen({super.key});

  @override
  State<RestrictedAccountsScreen> createState() => _RestrictedAccountsScreenState();
}

class _RestrictedAccountsScreenState extends State<RestrictedAccountsScreen> {
  List<Map<String, dynamic>> _restricted = [];
  bool _isLoading = true;
  final Set<String> _unrestricting = {};

  @override
  void initState() {
    super.initState();
    _loadRestricted();
  }

  Future<void> _loadRestricted() async {
    if (GuestMode.isGuestMode) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final restricted = await SupabaseService().getRestrictedAccounts();
      if (mounted) {
        setState(() {
          _restricted = restricted;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unrestrict(String targetUserId, String username) async {
    setState(() => _unrestricting.add(targetUserId));
    try {
      await SupabaseService().unrestrictUser(targetUserId);
      if (mounted) {
        setState(() {
          _restricted.removeWhere((r) => r['restricted_id'] == targetUserId);
          _unrestricting.remove(targetUserId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unrestricted @$username'),
            backgroundColor: RippleColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _unrestricting.remove(targetUserId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to unrestrict'),
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
        title: const Text('Restricted Accounts', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: RippleColors.primary))
          : _restricted.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _restricted.length,
                  itemBuilder: (context, index) {
                    final entry = _restricted[index];
                    final profile = entry['restricted'] as Map<String, dynamic>?;
                    final username = profile?['username'] as String? ?? 'unknown';
                    final displayName = profile?['display_name'] as String? ?? username;
                    final avatarUrl = profile?['avatar_url'] as String?;
                    final restrictedId = entry['restricted_id'] as String? ?? '';
                    final isUnrestricting = _unrestricting.contains(restrictedId);

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
                              if (isUnrestricting)
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
                                  onPressed: () => _unrestrict(restrictedId, username),
                                  style: TextButton.styleFrom(
                                    foregroundColor: RippleColors.error,
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Unrestrict',
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
              Icons.person_remove,
              color: RippleColors.textSecondary,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No restricted accounts',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: RippleColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Restricted accounts will appear here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RippleColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
