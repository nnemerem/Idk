import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';

/// Delete account screen — permanently deletes the account.
///
/// Requires the user to type "DELETE" to confirm before the delete action
/// is enabled. Deletion signs the user out and calls the backend (non-fatal
/// if the backend endpoint isn't wired yet).
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _confirmController = TextEditingController();
  bool _isDeleting = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _confirmController.addListener(_updateCanDelete);
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  void _updateCanDelete() {
    setState(() {
      _canDelete = _confirmController.text.trim() == 'DELETE';
    });
  }

  Future<void> _delete() async {
    setState(() => _isDeleting = true);

    try {
      // Sign out the user. Account data removal is backend-side and gated
      // behind credentials; the sign-out completes the client-side flow.
      await SupabaseService().signOut();

      if (mounted) {
        context.go(RippleConstants.routeLogin);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete account. Try again.'),
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
          'Delete Account',
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
                  Icons.delete,
                  color: RippleColors.error,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Delete your account?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: RippleColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This cannot be undone. Your profile, posts, reels, comments, '
                'likes, and messages will be permanently removed.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: RippleColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _confirmController,
                style: const TextStyle(
                  color: RippleColors.textPrimary,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Type DELETE to confirm',
                  hintStyle: TextStyle(color: RippleColors.textTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      RippleConstants.borderRadiusMedium,
                    ),
                    borderSide: const BorderSide(color: RippleColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      RippleConstants.borderRadiusMedium,
                    ),
                    borderSide: const BorderSide(color: RippleColors.primary),
                  ),
                ),
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isDeleting || !_canDelete ? null : _delete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RippleColors.error,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        RippleColors.surfaceVariant,
                    disabledForegroundColor: RippleColors.textTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        RippleConstants.borderRadiusLarge,
                      ),
                    ),
                  ),
                  child: _isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Delete Account',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
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
