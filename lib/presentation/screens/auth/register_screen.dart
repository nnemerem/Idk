import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';
import 'package:ripple/core/utils/guest_mode.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await SupabaseService().signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
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

                    // Username field
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      style: const TextStyle(color: RippleColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'Choose a username',
                        prefixIcon: Icon(Icons.person_outline),
                        helperText: 'Letters, numbers, underscores, periods',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a username';
                        }
                        if (!RippleConstants.usernameRegex.hasMatch(value.trim())) {
                          return 'Username can only contain letters, numbers, underscores, and periods';
                        }
                        if (value.trim().length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Display name field
                    TextFormField(
                      controller: _displayNameController,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      style: const TextStyle(color: RippleColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        hintText: 'Your name',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

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
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      style: const TextStyle(color: RippleColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Create a password',
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
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm password field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      style: const TextStyle(color: RippleColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Confirm your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: RippleColors.textSecondary,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword = !_obscureConfirmPassword,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _signUp(),
                    ),
                    const SizedBox(height: 24),

                    // Sign up button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signUp,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text('Create Account'),
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

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: RippleColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go(RippleConstants.routeLogin),
                          child: const Text('Log In'),
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
                      'By signing up, you agree to our Terms of Service, Privacy Policy, and Cookies Policy.',
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
}