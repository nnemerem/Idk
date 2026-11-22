import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'guest_mode.dart';

class AuthGuard {
  static bool get isAuthenticated => Supabase.instance.client.auth.currentSession != null;

  static Future<void> run(
    BuildContext context, {
    required VoidCallback onAuthenticated,
    String? message,
    String? actionName,
  }) async {
    if (isAuthenticated) {
      onAuthenticated();
      return;
    }

    // Check if guest mode
    if (GuestMode.isGuestMode) {
      if (actionName != null && GuestMode.requiresAuth(actionName)) {
        GuestMode.showAuthRequired(context, actionName.replaceAll('_', ' '));
        return;
      }
      onAuthenticated();
      return;
    }

    // Show snackbar and navigate to login
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? 'Please sign in to continue.'),
          action: SnackBarAction(
            label: 'Sign In',
            textColor: Theme.of(context).colorScheme.primary,
            onPressed: () => context.go('/login'),
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static void requireAuth(BuildContext context, {String? redirectTo}) {
    if (!isAuthenticated && !GuestMode.isGuestMode) {
      context.go(redirectTo ?? '/login');
    }
  }

  static Future<T?> guardAsync<T>(
    BuildContext context,
    Future<T> Function() action, {
    String? message,
    String? actionName,
  }) async {
    if (!isAuthenticated) {
      if (GuestMode.isGuestMode) {
        if (actionName != null && GuestMode.requiresAuth(actionName)) {
          if (context.mounted) {
            GuestMode.showAuthRequired(context, actionName.replaceAll('_', ' '));
          }
          return null;
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message ?? 'Please sign in to continue.'),
              action: SnackBarAction(
                label: 'Sign In',
                textColor: Theme.of(context).colorScheme.primary,
                onPressed: () => context.go('/login'),
              ),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return null;
      }
    }
    return await action();
  }
}