import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';

/// Bottom sheet showing the post link with a "Copy link" action.
/// Honest implementation: uses the clipboard via [Clipboard.setData].
class ShareSheet extends StatelessWidget {
  final String link;
  final String? caption;
  final String shareText;

  const ShareSheet({
    super.key,
    required this.link,
    this.caption,
    required this.shareText,
  });

  static Future<void> show(
    BuildContext context, {
    required String link,
    String? caption,
    required String shareText,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareSheet(link: link, caption: caption, shareText: shareText),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RippleColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RippleConstants.borderRadiusXLarge),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: RippleColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Share',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (caption != null && caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                caption!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: RippleColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: RippleColors.surfaceVariant,
              borderRadius: BorderRadius.circular(RippleConstants.borderRadiusMedium),
            ),
            child: Text(
              link,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: RippleColors.textTertiary,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: '$shareText $link'));
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              }
            },
            icon: const Icon(Icons.link_outlined, size: 18),
            label: const Text('Copy link'),
          ),
        ],
      ),
    );
  }
}
