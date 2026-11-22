import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';

class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({super.key});

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen>
    with SingleTickerProviderStateMixin {
  final _captionController = TextEditingController();
  final _musicController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedVideo;
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPosting = false;
  Duration _videoDuration = Duration.zero;

  // Reel editor state
  double _trimStart = 0.0;
  double _trimEnd = 1.0;
  bool _isEditing = false;

  @override
  void dispose() {
    _captionController.dispose();
    _musicController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: RippleConstants.maxReelDurationSeconds),
      );

      if (video != null) {
        final file = File(video.path);
        final duration = await _getVideoDuration(file);

        if (duration.inSeconds > RippleConstants.maxReelDurationSeconds) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Video must be ${RippleConstants.maxReelDurationSeconds} seconds or less',
                ),
                backgroundColor: RippleColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedVideo = file;
          _videoDuration = duration;
          _trimStart = 0.0;
          _trimEnd = 1.0;
        });

        _initializeController(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick video: ${e.toString()}'),
            backgroundColor: RippleColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<Duration> _getVideoDuration(File file) async {
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    final duration = controller.value.duration;
    controller.dispose();
    return duration;
  }

  void _initializeController(File file) {
    _controller?.dispose();
    _controller = VideoPlayerController.file(file)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _controller!.setLooping(true);
            _controller!.play();
          });
        }
      });
  }

  void _removeVideo() {
    setState(() {
      _selectedVideo = null;
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _videoDuration = Duration.zero;
    });
  }

  Future<void> _postReel() async {
    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a video'),
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

      // Upload video
      final bytes = await _selectedVideo!.readAsBytes();
      final fileName = '${currentUserId}_reel_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final videoUrl = await SupabaseService().uploadFile(
        bucket: RippleConstants.bucketReels,
        path: fileName,
        bytes: bytes,
        contentType: 'video/mp4',
      );

      // Generate thumbnail (first frame)
      String? thumbnailUrl;
      // TODO: Generate and upload thumbnail

      // Create reel
      await SupabaseService().client.from(RippleConstants.tableReels).insert({
        'user_id': currentUserId,
        'caption': _captionController.text.trim(),
        'video_url': videoUrl,
        'thumbnail_url': thumbnailUrl,
        'music_title': _musicController.text.trim().isEmpty ? null : _musicController.text.trim(),
        'duration_seconds': _videoDuration.inSeconds,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reel shared successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post reel: ${e.toString()}'),
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('New Reel', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/icons/close.svg',
            width: 26,
            height: 26,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isPosting || _selectedVideo == null ? null : _postReel,
            child: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Share',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
                  ),
          ),
        ],
      ),
      body: _selectedVideo == null
          ? _buildEmptyState()
          : _buildVideoEditor(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: RippleColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/icons/video.svg',
              width: 48,
              height: 48,
              colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Create a Reel',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a video to create your first Reel',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RippleColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _pickVideo,
            icon: SvgPicture.asset('assets/icons/video_library.svg', width: 20, height: 20),
            label: const Text('Select Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: RippleColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoEditor() {
    return Column(
      children: [
        // Video preview
        Expanded(
          flex: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isInitialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                )
              else
                Center(child: CircularProgressIndicator(color: RippleColors.primary)),

              // Trim indicator
              if (_isEditing)
                Positioned(
                  bottom: 60,
                  left: 16,
                  right: 16,
                  child: _buildTrimSlider(),
                ),

              // Duration
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(RippleConstants.borderRadiusFull),
                  ),
                  child: Text(
                    _formatDuration(_videoDuration),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Controls
        Container(
          color: RippleColors.surface,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Trim button
              if (!_isEditing)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: SvgPicture.asset('assets/icons/trim.svg', width: 20, height: 20),
                    label: const Text('Trim Video'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: RippleColors.border),
                    ),
                  ),
                ),

              // Trim controls
              if (_isEditing)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _isEditing = false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RippleColors.surfaceVariant,
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // Caption
              TextField(
                controller: _captionController,
                maxLines: 3,
                maxLength: 2200,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Write a caption...',
                  hintStyle: TextStyle(color: RippleColors.textTertiary),
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),

              const SizedBox(height: 12),

              // Music
              TextField(
                controller: _musicController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Add music (optional)',
                  hintStyle: TextStyle(color: RippleColors.textTertiary),
                  border: InputBorder.none,
                  prefixIcon: SvgPicture.asset(
                    'assets/icons/music.svg',
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _removeVideo,
                      icon: SvgPicture.asset(
                        'assets/icons/delete.svg',
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(RippleColors.error, BlendMode.srcIn),
                      ),
                      label: Text('Remove', style: TextStyle(color: RippleColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: RippleColors.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrimSlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(RippleConstants.borderRadiusLarge),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(Duration(milliseconds: (_videoDuration.inMilliseconds * _trimStart).round())),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                _formatDuration(_videoDuration),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                _formatDuration(Duration(milliseconds: (_videoDuration.inMilliseconds * _trimEnd).round())),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RangeSlider(
            values: RangeValues(_trimStart, _trimEnd),
            min: 0.0,
            max: 1.0,
            divisions: 100,
            activeColor: RippleColors.primary,
            inactiveColor: RippleColors.border,
            onChanged: (values) {
              setState(() {
                _trimStart = values.start;
                _trimEnd = values.end;
              });
            },
          ),
        ],
      ),
    );
  }
}