import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ripple/config/notification_preferences.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';

/// Notification preferences screen — toggles for each notification
/// category plus the master push switch.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  late NotificationPreferences _prefs;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _prefs = NotificationPreferencesStore.instance.prefs;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    NotificationPreferencesStore.instance.setPrefs(_prefs);
    // TODO: persist to Supabase/local storage when credentials exist.
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification preferences saved.'),
          backgroundColor: RippleColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RippleColors.background,
      appBar: AppBar(
        title: const Text(
          'Notification Preferences',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.done_outlined),
              tooltip: 'Save',
              onPressed: _save,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Master switch
          _SectionHeader(title: 'Push Notifications'),
          _PreferenceTile(
            iconAsset: 'assets/icons/notification.svg',
            title: 'Push notifications',
            subtitle:
                'Receive push notifications for likes, comments, follows, mentions, tags, and shares.',
            value: _prefs.pushEnabled,
            onChanged: (v) => setState(() => _prefs.pushEnabled = v),
          ),

          const SizedBox(height: 24),

          // Categories
          _SectionHeader(title: 'Categories'),
          _PreferenceTile(
            iconAsset: 'assets/icons/heart.svg',
            title: 'Likes',
            subtitle: 'When someone likes your post or reel',
            value: _prefs.postLikes && _prefs.reelLikes,
            onChanged: (v) {
              setState(() {
                _prefs.postLikes = v;
                _prefs.reelLikes = v;
              });
            },
          ),
          _PreferenceTile(
            iconAsset: 'assets/icons/comment.svg',
            title: 'Comments',
            subtitle: 'When someone comments on your post or reel',
            value: _prefs.postComments && _prefs.reelComments,
            onChanged: (v) {
              setState(() {
                _prefs.postComments = v;
                _prefs.reelComments = v;
              });
            },
          ),
          _PreferenceTile(
            iconAsset: 'assets/icons/person_add.svg',
            title: 'Follows',
            subtitle: 'When someone follows you',
            value: _prefs.follows,
            onChanged: (v) => setState(() => _prefs.follows = v),
          ),
          _PreferenceTile(
            iconAsset: 'assets/icons/tag.svg',
            title: 'Mentions & Tags',
            subtitle:
                'When someone mentions or tags you in a post, reel, comment, or caption',
            value: _prefs.mentions && _prefs.tags,
            onChanged: (v) {
              setState(() {
                _prefs.mentions = v;
                _prefs.tags = v;
              });
            },
          ),
          _PreferenceTile(
            iconAsset: 'assets/icons/send.svg',
            title: 'Shares',
            subtitle: 'When someone shares your post or reel',
            value: _prefs.shares,
            onChanged: (v) => setState(() => _prefs.shares = v),
          ),

          const SizedBox(height: 32),

          // Note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RippleColors.surfaceVariant,
              borderRadius: BorderRadius.circular(RippleConstants.borderRadiusMedium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Heads up',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: RippleColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Push notifications require device permission. '
                  'Toggle them on here, then grant permission when prompted.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: RippleColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: RippleColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  final String iconAsset;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceTile({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
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
                  value ? RippleColors.primary : RippleColors.textSecondary,
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
                        fontWeight: FontWeight.w600,
                        color: RippleColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: RippleColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
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
