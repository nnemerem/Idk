import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/supabase_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  final List<File> _selectedImages = [];
  final List<XFile> _selectedFiles = [];
  bool _isPosting = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    if (_selectedFiles.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Maximum 10 items allowed'),
          backgroundColor: RippleColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final List<XFile>? images = await _picker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images != null && images.isNotEmpty) {
        final remainingSlots = 10 - _selectedFiles.length;
        final toAdd = images.take(remainingSlots).toList();

        setState(() {
          _selectedFiles.addAll(toAdd);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick images: ${e.toString()}'),
            backgroundColor: RippleColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _post() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one photo or video'),
          backgroundColor: RippleColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null) return;

      // Upload all media files
      final mediaList = <Map<String, dynamic>>[];
      for (int i = 0; i < _selectedFiles.length; i++) {
        final file = _selectedFiles[i];
        final bytes = await file.readAsBytes();
        final extension = file.path.split('.').last.toLowerCase();
        final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(extension);
        final fileName = '${currentUserId}_${DateTime.now().millisecondsSinceEpoch}_$i.${isVideo ? 'mp4' : 'jpg'}';

        final url = await SupabaseService().uploadFile(
          bucket: RippleConstants.bucketPosts,
          path: fileName,
          bytes: bytes,
          contentType: isVideo ? 'video/mp4' : 'image/jpeg',
        );

        if (url != null) {
          mediaList.add({
            'url': url,
            'type': isVideo ? 'video' : 'image',
            'order': i,
          });
        }
      }

      // Create post
      await SupabaseService().client.from(RippleConstants.tablePosts).insert({
        'user_id': currentUserId,
        'caption': _captionController.text.trim(),
        'location': _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        'media': mediaList,
        'post_type': mediaList.length > 1 ? 'carousel' : (mediaList.first['type'] == 'video' ? 'video' : 'image'),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update user posts count
      await SupabaseService().client.rpc('increment_posts_count', params: {'user_id': currentUserId});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post shared successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post: ${e.toString()}'),
            backgroundColor: RippleColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RippleColors.background,
      appBar: AppBar(
        title: const Text('New Post', style: TextStyle(fontWeight: FontWeight.w600)),
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
            onPressed: _isPosting || _selectedFiles.isEmpty ? null : _post,
            child: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Share',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Media preview
          if (_selectedFiles.isNotEmpty)
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(16),
                itemCount: _selectedFiles.length + 1,
                itemBuilder: (context, index) {
                  if (index == _selectedFiles.length) {
                    // Add more button
                    return _AddMediaButton(onTap: _pickMedia);
                  }
                  return _MediaPreviewItem(
                    file: _selectedFiles[index],
                    index: index,
                    onRemove: _removeMedia,
                  );
                },
              ),
            )
          else
            _EmptyMediaPlaceholder(onTap: _pickMedia),

          const Divider(height: 1, color: RippleColors.divider),

          // Caption and location
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Caption
                  TextField(
                    controller: _captionController,
                    maxLines: 8,
                    maxLength: 2200,
                    style: const TextStyle(color: RippleColors.textPrimary, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Write a caption...',
                      hintStyle: TextStyle(color: RippleColors.textTertiary),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location
                  TextField(
                    controller: _locationController,
                    style: const TextStyle(color: RippleColors.textPrimary, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Add location...',
                      hintStyle: TextStyle(color: RippleColors.textTertiary),
                      border: InputBorder.none,
                      prefixIcon: SvgPicture.asset(
                        'assets/icons/location.svg',
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Hashtag suggestions
                  _buildHashtagSuggestions(),

                  const SizedBox(height: 16),

                  // Tag people
                  _buildActionRow(
                    iconAsset: 'assets/icons/person_add.svg',
                    label: 'Tag People',
                    onTap: () {
                      // TODO: Tag people
                    },
                  ),

                  // Add music
                  _buildActionRow(
                    iconAsset: 'assets/icons/music.svg',
                    label: 'Add Music',
                    onTap: () {
                      // TODO: Add music
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHashtagSuggestions() {
    final hashtags = ['#photography', '#instagood', '#photooftheday', '#love', '#nature'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: hashtags.map((tag) => ActionChip(
        label: Text(tag, style: const TextStyle(color: RippleColors.primary)),
        backgroundColor: RippleColors.primary.withValues(alpha: 0.1),
        side: BorderSide(color: RippleColors.primary.withValues(alpha: 0.3)),
        onPressed: () {
          final text = _captionController.text;
          final newText = text.isEmpty ? tag : '$text $tag';
          _captionController.text = newText;
          _captionController.selection = TextSelection.collapsed(offset: newText.length);
        },
      )).toList(),
    );
  }

  Widget _buildActionRow({
    required String iconAsset,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RippleConstants.borderRadiusMedium),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SvgPicture.asset(
              iconAsset,
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(RippleColors.textSecondary, BlendMode.srcIn),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            SvgPicture.asset(
              'assets/icons/chevron_right.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPreviewItem extends StatefulWidget {
  final XFile file;
  final int index;
  final Function(int) onRemove;

  const _MediaPreviewItem({
    required this.file,
    required this.index,
    required this.onRemove,
  });

  @override
  State<_MediaPreviewItem> createState() => _MediaPreviewItemState();
}

class _MediaPreviewItemState extends State<_MediaPreviewItem> {
  late VideoPlayerController _controller;
  bool _isVideo = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkIfVideo();
  }

  void _checkIfVideo() {
    final extension = widget.file.path.split('.').last.toLowerCase();
    _isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(extension);

    if (_isVideo) {
      _controller = VideoPlayerController.file(File(widget.file.path))
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _isInitialized = true);
            _controller.setLooping(true);
            _controller.play();
          }
        });
    }
  }

  @override
  void dispose() {
    if (_isVideo) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 160,
          height: 160,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RippleConstants.borderRadiusMedium),
            color: RippleColors.surfaceVariant,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(RippleConstants.borderRadiusMedium),
            child: _isVideo
                ? _isInitialized
                    ? VideoPlayer(_controller)
                    : Center(child: CircularProgressIndicator(color: RippleColors.primary))
                : Image.file(
                    File(widget.file.path),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => widget.onRemove(widget.index),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: RippleColors.error,
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/icons/close.svg',
                width: 16,
                height: 16,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
        ),
        if (_isVideo)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SvgPicture.asset(
                'assets/icons/video.svg',
                width: 12,
                height: 12,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddMediaButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddMediaButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(RippleConstants.borderRadiusMedium),
          border: Border.all(
            color: RippleColors.border,
            width: 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: RippleColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/icons/plus.svg',
                width: 28,
                height: 28,
                colorFilter: ColorFilter.mode(RippleColors.primary, BlendMode.srcIn),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add Media',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: RippleColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMediaPlaceholder extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyMediaPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RippleConstants.borderRadiusLarge),
            border: Border.all(
              color: RippleColors.border,
              width: 1,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: RippleColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/icons/photo_library.svg',
                  width: 40,
                  height: 40,
                  colorFilter: ColorFilter.mode(RippleColors.primary, BlendMode.srcIn),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add Photos or Videos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select up to 10 photos or videos to share',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: RippleColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}