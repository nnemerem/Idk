import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';
import 'package:ripple/core/utils/guest_mode.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await SupabaseService().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        context.go(RippleConstants.routeFeed);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: RippleColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred. Please try again.'),
            backgroundColor: RippleColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RippleColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: RippleColors.brandGradient,
                      ).createShader(bounds),
                      child: Text(
                        RippleConstants.appName,
                        style: const TextStyle(
                                                    fontSize: 52,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      style: const TextStyle(color: RippleColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: Icon(Icons.alternate_email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RippleConstants.emailRegex.hasMatch(value.trim())) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      style: const TextStyle(color: RippleColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: RippleColors.textSecondary,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _signIn(),
                    ),
                    const SizedBox(height: 8),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotPasswordDialog(),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sign in button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text('Log In'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Divider
                    Row(
                      children: [
                        const Expanded(child: Divider(color: RippleColors.divider)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: RippleColors.textTertiary,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: RippleColors.divider)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account? ',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: RippleColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go(RippleConstants.routeRegister),
                          child: const Text('Sign Up'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Check it out button (Guest mode)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => GuestMode.enterGuestMode(context),
                        icon: const Icon(Icons.visibility_outlined, size: 20),
                        label: const Text(
                          'Check It Out',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: RippleColors.textPrimary,
                          side: BorderSide(color: RippleColors.border, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(RippleConstants.borderRadiusLarge),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Meta/legal text
                    Text(
                      'By continuing, you agree to our Terms of Service, Privacy Policy, and Cookies Policy.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: RippleColors.textTertiary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _emailController.text.trim());
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: RippleColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RippleConstants.borderRadiusXLarge),
          ),
          title: Text(
            'Reset Password',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your email and we\'ll send you a link to reset your password.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: RippleColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                style: const TextStyle(color: RippleColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  prefixIcon: Icon(Icons.alternate_email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      try {
                        await SupabaseService().resetPassword(emailController.text.trim());
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password reset email sent!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: RippleColors.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } finally {
                        setState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Reset Link'),
            ),
          ],
        ),
      ),
    );
  }
}