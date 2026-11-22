import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();

  Map<String, dynamic>? _profile;
  File? _selectedImage;
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null) return;

      final profile = await SupabaseService().getProfile(currentUserId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _usernameController.text = profile?['username'] ?? '';
          _displayNameController.text = profile?['display_name'] ?? '';
          _bioController.text = profile?['bio'] ?? '';
          _websiteController.text = profile?['website'] ?? '';
          _avatarUrl = profile?['avatar_url'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: RippleColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to take photo: ${e.toString()}'),
            backgroundColor: RippleColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: RippleColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(RippleConstants.borderRadiusXLarge),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: RippleColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: SvgPicture.asset('assets/icons/photo_library.svg', width: 24, height: 24),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: SvgPicture.asset('assets/icons/camera.svg', width: 24, height: 24),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            if (_avatarUrl != null || _selectedImage != null)
              ListTile(
                leading: SvgPicture.asset(
                  'assets/icons/delete.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(RippleColors.error, BlendMode.srcIn),
                ),
                title: Text(
                  'Remove Photo',
                  style: TextStyle(color: RippleColors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                    _avatarUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null) return;

      String? newAvatarUrl = _avatarUrl;

      // Upload new avatar if selected
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final fileName = '${currentUserId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        newAvatarUrl = await SupabaseService().uploadFile(
          bucket: RippleConstants.bucketAvatars,
          path: fileName,
          bytes: bytes,
          contentType: 'image/jpeg',
        );
      }

      // Update profile
      await SupabaseService().updateProfile(
        userId: currentUserId,
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: newAvatarUrl,
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: RippleColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RippleColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/icons/close.svg',
            width: 26,
            height: 26,
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: RippleColors.primary))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Avatar
                  Center(
                    child: GestureDetector(
                      onTap: _showImagePickerOptions,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: RippleColors.surfaceVariant,
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!)
                                : _avatarUrl != null
                                    ? CachedNetworkImageProvider(_avatarUrl!)
                                    : null,
                            child: _selectedImage == null && _avatarUrl == null
                                ? Text(
                                    _profile?['username']?[0]?.toUpperCase() ?? '?',
                                    style: const TextStyle(
                                      color: RippleColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 36,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: RippleColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: RippleColors.background,
                                  width: 2,
                                ),
                              ),
                              child: SvgPicture.asset(
                                'assets/icons/camera.svg',
                                width: 16,
                                height: 16,
                                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Username
                  TextFormField(
                    controller: _usernameController,
                    style: const TextStyle(color: RippleColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'Enter username',
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

                  // Display Name
                  TextFormField(
                    controller: _displayNameController,
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

                  // Bio
                  TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    maxLength: 150,
                    style: const TextStyle(color: RippleColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      hintText: 'Tell us about yourself',
                      prefixIcon: Icon(Icons.info_outline),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Website
                  TextFormField(
                    controller: _websiteController,
                    style: const TextStyle(color: RippleColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Website',
                      hintText: 'https://example.com',
                      prefixIcon: Icon(Icons.link_outlined),
                    ),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final uri = Uri.tryParse(value.trim());
                        if (uri == null || !uri.hasScheme) {
                          return 'Please enter a valid URL (e.g., https://example.com)';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Personal Information section
                  Text(
                    'Personal Information',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: RippleColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    iconAsset: 'assets/icons/email.svg',
                    label: 'Email',
                    value: _profile?['email'] ?? 'Not set',
                  ),
                  _InfoTile(
                    iconAsset: 'assets/icons/phone.svg',
                    label: 'Phone',
                    value: _profile?['phone_number'] ?? 'Not set',
                  ),
                  _InfoTile(
                    iconAsset: 'assets/icons/cake.svg',
                    label: 'Date of Birth',
                    value: _profile?['date_of_birth'] ?? 'Not set',
                  ),
                  _InfoTile(
                    iconAsset: 'assets/icons/gender.svg',
                    label: 'Gender',
                    value: _profile?['gender'] ?? 'Not set',
                  ),
                ],
              ),
            ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String iconAsset;
  final String label;
  final String value;

  const _InfoTile({
    required this.iconAsset,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RippleColors.surface,
        borderRadius: BorderRadius.circular(RippleConstants.borderRadiusMedium),
        border: Border.all(color: RippleColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            iconAsset,
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(RippleColors.textSecondary, BlendMode.srcIn),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: RippleColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}