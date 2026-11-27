import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';
import 'package:ripple/core/utils/guest_mode.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isPrivate = false;
  bool _isLoadingPrivate = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPrivateStatus();
  }

  Future<void> _loadProfile() async {
    try {
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null) return;

      final profile = await SupabaseService().getProfile(currentUserId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadPrivateStatus() async {
    try {
      final isPrivate = await SupabaseService().isPrivateAccount();
      if (mounted) {
        setState(() {
          _isPrivate = isPrivate;
          _isLoadingPrivate = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPrivate = false);
    }
  }

  Future<void> _togglePrivateAccount() async {
    setState(() => _isLoadingPrivate = true);
    try {
      final newValue = await SupabaseService().togglePrivateAccount(_isPrivate);
      if (mounted) {
        setState(() {
          _isPrivate = newValue;
          _isLoadingPrivate = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPrivate = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update privacy setting'),
            backgroundColor: RippleColors.error,
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
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: RippleColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Account & profile
                _buildSectionHeader('Account'),
                _SettingsTile(
                  iconAsset: 'assets/icons/person_outline.svg',
                  title: 'Edit Profile',
                  subtitle: _profile?['display_name'] != null
                      ? '@${_profile?['username']}'
                      : 'Change name, username, bio, photo',
                  onTap: () => context.go(RippleConstants.routeEditProfile),
                ),
                _SettingsSwitchTile(
                  iconAsset: 'assets/icons/lock.svg',
                  title: 'Private Account',
                  subtitle: 'Only approved followers can see your posts and reels',
                  value: _isPrivate,
                  loading: _isLoadingPrivate,
                  onChanged: (_) => _togglePrivateAccount(),
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/article.svg',
                  title: 'Download Your Data',
                  subtitle: 'Request a copy of your posts, reels, and messages',
                  onTap: () => _showComingSoon('Download Your Data'),
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/delete.svg',
                  title: 'Deactivate Account',
                  subtitle: 'Temporarily disable your account',
                  onTap: () => _showComingSoon('Deactivate Account'),
                  destructive: true,
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/delete.svg',
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account and data',
                  onTap: () => _showComingSoon('Delete Account'),
                  destructive: true,
                ),

                const SizedBox(height: 24),
                // Privacy & Safety
                _buildSectionHeader('Privacy & Safety'),
                _SettingsTile(
                  iconAsset: 'assets/icons/block.svg',
                  title: 'Blocked Accounts',
                  subtitle: 'Accounts you have blocked',
                  onTap: () => context.go(RippleConstants.routeBlockedAccounts),
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/person_remove.svg',
                  title: 'Restricted Accounts',
                  subtitle: 'Accounts you have restricted',
                  onTap: () => context.go(RippleConstants.routeRestrictedAccounts),
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/privacy.svg',
                  title: 'Hidden Words',
                  subtitle: 'Filter comments and messages containing certain words',
                  onTap: () => _showComingSoon('Hidden Words'),
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/mute.svg',
                  title: 'Comment Filters',
                  subtitle: 'Control who can comment on your posts and reels',
                  onTap: () => _showComingSoon('Comment Filters'),
                ),

                const SizedBox(height: 24),
                // Notifications
                _buildSectionHeader('Notifications'),
                _SettingsTile(
                  iconAsset: 'assets/icons/notification.svg',
                  title: 'Push Notifications',
                  subtitle: 'Receive push notifications for likes, comments, and follows',
                  onTap: () => _showComingSoon('Push Notifications'),
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/notification.svg',
                  title: 'Notification Preferences',
                  subtitle: 'Choose which notifications you receive',
                  onTap: () => _showComingSoon('Notification Preferences'),
                ),

                const SizedBox(height: 24),
                // App
                _buildSectionHeader('App'),
                _SettingsTile(
                  iconAsset: 'assets/icons/info.svg',
                  title: 'About',
                  subtitle: 'Version ${RippleConstants.appVersion}',
                  onTap: () => _showAboutDialog(),
                ),

                const SizedBox(height: 32),
                // Switch to Real Account (Guest mode only)
                if (GuestMode.isGuestMode)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        GuestMode.exitGuestMode(context);
                      },
                      icon: SvgPicture.asset('assets/icons/person_add.svg', width: 20, height: 20),
                      label: const Text(
                        'Switch to Real Account',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: RippleColors.primary,
                        side: BorderSide(color: RippleColors.primary, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RippleConstants.borderRadiusLarge),
                        ),
                      ),
                    ),
                  ),
                // Log out button
                if (!GuestMode.isGuestMode)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _showLogoutConfirmation,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: RippleColors.error,
                        side: BorderSide(color: RippleColors.error, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RippleConstants.borderRadiusLarge),
                        ),
                      ),
                      child: const Text(
                        'Log Out',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: RippleColors.textSecondary,
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon.'),
        backgroundColor: RippleColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RippleColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RippleConstants.borderRadiusXLarge),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: RippleColors.brandGradient,
          ).createShader(bounds),
          child: Text(
            RippleConstants.appName,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Version ${RippleConstants.appVersion}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: RippleColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Visual Social World',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RippleColors.surfaceVariant,
                borderRadius: BorderRadius.circular(RippleConstants.borderRadiusLarge),
              ),
              child: Column(
                children: [
                  Text(
                    'Built with Flutter & Supabase',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: RippleColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '© 2024 Ripple. All rights reserved.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: RippleColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RippleColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RippleConstants.borderRadiusXLarge),
        ),
        title: const Text('Log Out?'),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await SupabaseService().signOut();
              if (mounted) {
                context.go(RippleConstants.routeLogin);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: RippleColors.error,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

/// Settings row with an icon, title, subtitle, and chevron.
class _SettingsTile extends StatelessWidget {
  final String iconAsset;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _SettingsTile({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
              SvgPicture.asset(
                iconAsset,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  destructive ? RippleColors.error : RippleColors.textSecondary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: destructive ? RippleColors.error : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: RippleColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              SvgPicture.asset(
                'assets/icons/chevron_right.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings row with a switch (e.g. Private Account toggle).
class _SettingsSwitchTile extends StatelessWidget {
  final String iconAsset;
  final String title;
  final String subtitle;
  final bool value;
  final bool loading;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : () => onChanged(!value),
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
              SvgPicture.asset(
                iconAsset,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(RippleColors.textSecondary, BlendMode.srcIn),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: RippleColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(RippleColors.textSecondary),
                  ),
                )
              else
                Switch(
                  value: value,
                  onChanged: loading ? null : onChanged,
                  activeColor: RippleColors.primary,
                  activeTrackColor: RippleColors.primary.withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
