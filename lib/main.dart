import 'package:flutter/material.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/router.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase. If the app was built without a valid
  // SUPABASE_URL / SUPABASE_ANON_KEY, show a clear error screen instead of
  // crashing or surfacing raw network errors later.
  Object? initError;
  try {
    await SupabaseService().initialize();
  } on ConfigurationException catch (e) {
    initError = e;
  } catch (_) {
    initError = ConfigurationException('Ripple failed to start.');
  }

  if (initError != null) {
    runApp(RippleConfigErrorApp(message: initError.toString()));
    return;
  }

  runApp(const RippleApp());
}

class RippleApp extends StatelessWidget {
  const RippleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: RippleConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: RippleTheme.darkTheme,
      darkTheme: RippleTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
    );
  }
}

/// Shown when the app was built without valid Supabase configuration.
class RippleConfigErrorApp extends StatelessWidget {
  final String message;

  const RippleConfigErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RippleTheme.darkTheme,
      home: Scaffold(
        backgroundColor: RippleColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: RippleColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.build_circle_outlined,
                      size: 44,
                      color: RippleColors.error,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Ripple is misconfigured',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: RippleColors.textPrimary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This build is missing a valid Supabase configuration '
                    '(SUPABASE_URL / SUPABASE_ANON_KEY). Ask the repo '
                    'maintainer to add those secrets, then rebuild or '
                    're-download Ripple.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: RippleColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: RippleColors.textTertiary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
