import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      // Check if user profile exists, if not create it
      final profile = await SupabaseService().getProfile(session.user.id);
      if (profile == null) {
        await SupabaseService().createProfile(
          userId: session.user.id,
          username: session.user.userMetadata?['username'] ?? 'user_${session.user.id.substring(0, 8)}',
          displayName: session.user.userMetadata?['display_name'] ?? 'User',
        );
      }
      context.go(RippleConstants.routeFeed);
    } else {
      context.go(RippleConstants.routeLogin);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RippleColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App logo with gradient ring
                    SvgPicture.asset(
                      'assets/icons/brand_logo.svg',
                      width: 100,
                      height: 100,
                    ),
                    const SizedBox(height: 24),
                    // App name
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: RippleColors.brandGradient,
                      ).createShader(bounds),
                      child: Text(
                        RippleConstants.appName,
                        style: const TextStyle(
                                                    fontSize: 42,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Visual Social World',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: RippleColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Loading indicator
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          RippleColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}