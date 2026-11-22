import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/supabase_service.dart';
import '../../core/utils/guest_mode.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
                // Account section
                _buildSectionHeader('Account'),
                _SettingsTile(
                  iconAsset: 'assets/icons/person_outline.svg',
                  title: 'Edit Profile',
                  subtitle: 'Change name, username, bio, photo',
                  onTap: () => context.go(RippleConstants.routeEditProfile),
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/lock.svg',
                  title: 'Password & Security',
                  subtitle: 'Change password, two-factor authentication',
                  onTap: () {
                    // TODO: Navigate to security settings
                  },
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/email.svg',
                  title: 'Email',
                  subtitle: _profile?['email'] ?? 'Not set',
                  onTap: () {
                    // TODO: Change email
                  },
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/phone.svg',
                  title: 'Phone Number',
                  subtitle: _profile?['phone_number'] ?? 'Not set',
                  onTap: () {
                    // TODO: Change phone
                  },
                ),

                const SizedBox(height: 24),
                // Preferences section
                _buildSectionHeader('Preferences'),
                _SettingsTile(
                  iconAsset: 'assets/icons/notification.svg',
                  title: 'Notifications',
                  subtitle: 'Manage push and email notifications',
                  onTap: () {
                    // TODO: Notification settings
                  },
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/dark_mode.svg',
                  title: 'Theme',
                  subtitle: 'Dark (system default)',
                  onTap: () {
                    // TODO: Theme settings
                  },
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/language.svg',
                  title: 'Language',
                  subtitle: 'English (Default)',
                  onTap: () {
                    // TODO: Language settings
                  },
                ),

                const SizedBox(height: 24),
                // Privacy section
                _buildSectionHeader('Privacy & Safety'),
                _SettingsTile(
                  iconAsset: 'assets/icons/visibility.svg',
                  title: 'Account Privacy',
                  subtitle: 'Public / Private account',
                  onTap: () {
                    // TODO: Privacy settings
                  },
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/block.svg',
                  title: 'Blocked Accounts',
                  subtitle: 'Manage blocked accounts',
                  onTap: () {
                    // TODO: Blocked accounts
                  },
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/mute.svg',
                  title: 'Muted Accounts',
                  subtitle: 'Manage muted accounts',
                  onTap: () {
                    // TODO: Muted accounts
                  },
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/history.svg',
                  title: 'Activity Log',
                  subtitle: 'View your activity',
                  onTap: () {
                    // TODO: Activity log
                  },
                ),

                const SizedBox(height: 24),
                // More section
                _buildSectionHeader('More'),
                _SettingsTile(
                  iconAsset: 'assets/icons/help.svg',
                  title: 'Help Center',
                  subtitle: 'Get help and support',
                  onTap: () {
                    // TODO: Help center
                  },
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/article.svg',
                  title: 'Terms of Service',
                  subtitle: 'Read our terms',
                  onTap: () {
                    // TODO: Terms
                  },
                ),
                _SettingsTile(
                  iconAsset: 'assets/icons/privacy.svg',
                  title: 'Privacy Policy',
                  subtitle: 'Read our privacy policy',
                  onTap: () {
                    // TODO: Privacy policy
                  },
                ),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: RippleColors.textSecondary,
        ),
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
              fontFamily: 'Billabong',
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

class _SettingsTile extends StatelessWidget {
  final String iconAsset;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.onTap,
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