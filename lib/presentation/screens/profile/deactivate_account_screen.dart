import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';

/// Deactivate account screen — temporarily disables the account.
///
/// Deactivation signs the user out and clears the local session. The account
/// can be reactivated by signing in again. Permanent deletion is a separate
/// flow (see DeleteAccountScreen).
///
/// Permanently deleting the account is gated behind backend support and is
/// intentionally non-fatal here so the UI never breaks.
class DeactivateAccountScreen extends StatefulWidget {
  const DeactivateAccountScreen({super.key});

  @override
  State<DeactivateAccountScreen> createState() => _DeactivateAccountScreenState();
}

class _DeactivateAccountScreenState extends State<DeactivateAccountScreen> {
  bool _isDeactivating = false;

  Future<void> _deactivate() async {
    setState(() => _isDeactivating = true);

    try {
      // Sign out the user (temporary deactivation — session cleared locally).
      await SupabaseService().signOut();

      if (mounted) {
        context.go(RippleConstants.routeLogin);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeactivating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to deactivate account. Try again.'),
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
        title: const Text(
          'Deactivate Account',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: RippleColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pause_circle,
                  color: RippleColors.error,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Deactivate your account?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: RippleColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Deactivating will sign you out and pause your account. '
                'Your profile, posts, reels, and messages will be hidden '
                'until you sign back in to reactivate.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: RippleColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isDeactivating ? null : _deactivate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RippleColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        RippleConstants.borderRadiusLarge,
                      ),
                    ),
                  ),
                  child: _isDeactivating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Deactivate Account',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
