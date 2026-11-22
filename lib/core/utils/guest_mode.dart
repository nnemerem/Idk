import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ripple/config/constants.dart';

class GuestMode {
  /// Check if current session is in guest mode (anonymous auth)
  static bool get isGuestMode {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return false;
    return session.user.isAnonymous;
  }

  /// Create a temporary guest session for demo purposes
  static Future<void> enterGuestMode(BuildContext context) async {
    try {
      // Sign in anonymously or create a guest session
      // For demo purposes, we'll use Supabase anonymous auth to create a real session
      // that persists and works with the router redirect logic
      await Supabase.instance.client.auth.signInAnonymously();
      
      // Navigate to feed directly
      if (context.mounted) {
        context.go(RippleConstants.routeFeed);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to enter guest mode: ${e.toString()}'),
            backgroundColor: RippleColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Check if action requires authentication (guest can view but not create)
  static bool requiresAuth(String action) {
    final authRequiredActions = [
      'create_post',
      'create_reel',
      'create_story',
      'like',
      'comment',
      'save',
      'follow',
      'message',
      'edit_profile',
      'delete',
    ];
    return authRequiredActions.contains(action);
  }

  /// Show auth required dialog for guest users
  static void showAuthRequired(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RippleColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RippleConstants.borderRadiusXLarge),
        ),
        title: const Text('Sign In Required'),
        content: Text(
          'To $feature, you\'ll need to create an account. '
          'You can continue browsing as a guest!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue as Guest'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(RippleConstants.routeLogin);
            },
            style: ElevatedButton.styleFrom(backgroundColor: RippleColors.primary),
            child: const Text('Sign Up'),
          ),
        ],
      ),
    );
  }

  /// Guard for actions that require authentication
  static Future<bool> guardAction(BuildContext context, String action) async {
    if (isGuestMode && requiresAuth(action)) {
      showAuthRequired(context, action.replace('_', ' '));
      return false;
    }
    return true;
  }

  /// Clear guest mode and return to auth
  static Future<void> exitGuestMode(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      context.go(RippleConstants.routeLogin);
    }
  }

  /// Sign out from guest mode (alias for exitGuestMode)
  static Future<void> signOutGuest(BuildContext context) async {
    await exitGuestMode(context);
  }
}