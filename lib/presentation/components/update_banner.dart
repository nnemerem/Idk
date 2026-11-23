import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/update_service.dart';

/// Informational banner shown when a newer release of Ripple is published.
/// Non-blocking and dismissible — it just tells the user about the update.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  bool _checking = true;
  ReleaseUpdate? _update;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final update = await UpdateService().checkForUpdate();
    if (!mounted) return;
    setState(() {
      _update = update;
      _checking = false;
    });
  }

  Future<void> _applyUpdate() async {
    final url = _update?.url;
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Fall back to the releases page on any launch failure.
      try {
        await launchUrl(
          Uri.parse('https://github.com/nnemerem/Ripple/releases/latest'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _checking || _update == null || !_update!.isNewer) {
      return const SizedBox.shrink();
    }

    final tag = _update!.tag;
    return Container(
      margin: const EdgeInsets.only(top: 8, right: 16, left: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            RippleColors.primary.withValues(alpha: 0.14),
            RippleColors.rose.withValues(alpha: 0.14),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(RippleConstants.borderRadiusMedium),
        border: Border.all(
          color: RippleColors.primary.withValues(alpha: 0.35),
          width: 0.75,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFE94D6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.system_update_alt_outlined, size: 19, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update available',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: RippleColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$tag is out now — get it without uninstalling.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: RippleColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _applyUpdate,
            style: TextButton.styleFrom(
              foregroundColor: RippleColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: const Text('Update'),
          ),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close_rounded, size: 18),
            color: RippleColors.textTertiary,
            onPressed: () => setState(() => _dismissed = true),
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
        ],
      ),
    );
  }
}
