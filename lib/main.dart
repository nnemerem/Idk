import 'package:flutter/material.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/router.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService().initialize();

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