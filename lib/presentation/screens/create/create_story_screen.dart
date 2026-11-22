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

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final ImagePicker _picker = ImagePicker();

  File? _selectedMedia;
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isVideo = false;
  bool _isPosting = false;

  // Story editor state
  List<StoryElement> _elements = [];
  Color _backgroundColor = Colors.black;
  String? _textContent;
  TextStyle _textStyle = const TextStyle(
    color: Colors.white,
    fontSize: 28,
    fontWeight: FontWeight.w500,
  );

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      final XFile? media = await _picker.pickMedia();

      if (media != null) {
        final file = File(media.path);
        final extension = media.path.split('.').last.toLowerCase();
        final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(extension);

        if (isVideo) {
          final duration = await _getVideoDuration(file);
          if (duration.inSeconds > RippleConstants.maxStoryDurationSeconds) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Video must be ${RippleConstants.maxStoryDurationSeconds} seconds or less',
                  ),
                  backgroundColor: RippleColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }
        }

        setState(() {
          _selectedMedia = file;
          _isVideo = isVideo;
          _elements.clear();
        });

        if (isVideo) {
          _initializeController(file);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick media: ${e.toString()}'),
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

  void _removeMedia() {
    setState(() {
      _selectedMedia = null;
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _isVideo = false;
      _elements.clear();
    });
  }

  void _addText() {
    showDialog(
      context: context,
      builder: (context) => _TextEditorDialog(
        initialText: _textContent,
        initialStyle: _textStyle,
        onSave: (text, style) {
          setState(() {
            _textContent = text;
            _textStyle = style;
            _elements.add(StoryElement(
              type: StoryElementType.text,
              content: text,
              style: style,
              position: Offset.zero,
            ));
          });
        },
      ),
    );
  }

  Future<void> _postStory() async {
    if (_selectedMedia == null && _elements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add a photo, video, or text'),
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

      String? mediaUrl;
      String? thumbnailUrl;

      if (_selectedMedia != null) {
        final bytes = await _selectedMedia!.readAsBytes();
        final extension = _selectedMedia!.path.split('.').last.toLowerCase();
        final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(extension);
        final fileName = '${currentUserId}_story_${DateTime.now().millisecondsSinceEpoch}.${isVideo ? 'mp4' : 'jpg'}';

        mediaUrl = await SupabaseService().uploadFile(
          bucket: RippleConstants.bucketStories,
          path: fileName,
          bytes: bytes,
          contentType: isVideo ? 'video/mp4' : 'image/jpeg',
        );

        if (!isVideo) {
          thumbnailUrl = mediaUrl;
        } else {
          // Video stories: no thumbnail is generated yet; the UI falls back
          // to the video URL.
          thumbnailUrl = null;
        }
      }

      // Create story
      await SupabaseService().client.from(RippleConstants.tableStories).insert({
        'user_id': currentUserId,
        'media_url': mediaUrl,
        'thumbnail_url': thumbnailUrl,
        'media_type': _isVideo ? 'video' : 'image',
        'caption': _textContent,
        'background_color': _backgroundColor.value.toRadixString(16),
        'elements': _elements.map((e) => e.toJson()).toList(),
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story shared successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post story: ${e.toString()}'),
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('New Story', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
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
            onPressed: _isPosting || (_selectedMedia == null && _elements.isEmpty) ? null : _postStory,
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
      body: _selectedMedia == null
          ? _buildEmptyState()
          : _buildStoryEditor(),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        // Camera option
        Expanded(
          flex: 2,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: RippleColors.brandGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: SvgPicture.asset(
                      'assets/icons/camera.svg',
                      width: 40,
                      height: 40,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                    onPressed: _pickMedia,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create a Story',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share moments that disappear after 24 hours',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: RippleColors.textSecondary),
                ),
              ],
            ),
          ),
        ),

        // Gallery grid
        Expanded(
          flex: 3,
          child: _buildGalleryGrid(),
        ),
      ],
    );
  }

  Widget _buildGalleryGrid() {
    // In a real app, this would show the user's recent photos/videos
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: 12,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: RippleColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/icons/photo_library.svg',
            width: 32,
            height: 32,
            colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryEditor() {
    return Stack(
      children: [
        // Background
        Container(
          width: double.infinity,
          height: double.infinity,
          color: _backgroundColor,
        ),

        // Media preview
        if (_selectedMedia != null)
          Positioned.fill(
            child: _isVideo
                ? _isInitialized
                    ? Center(
                        child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                      )
                    : Center(child: CircularProgressIndicator(color: RippleColors.primary))
                : Image.file(
                    _selectedMedia!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
          ),

        // Text elements
        ..._elements.where((e) => e.type == StoryElementType.text).map((element) {
          return Positioned(
            left: element.position.dx,
            top: element.position.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  element.position += details.delta;
                });
              },
              child: Text(
                element.content,
                style: element.style,
              ),
            ),
          );
        }),

        // Top toolbar
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: SvgPicture.asset(
                  'assets/icons/close.svg',
                  width: 28,
                  height: 28,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                onPressed: _removeMedia,
              ),
              // Background color picker
              Row(
                children: [
                  Colors.black,
                  Colors.white,
                  RippleColors.primary,
                  RippleColors.tertiary,
                  RippleColors.quaternary,
                ].map((color) => GestureDetector(
                  onTap: () => setState(() => _backgroundColor = color),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _backgroundColor == color
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),

        // Bottom toolbar
        Positioned(
          bottom: 100,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ToolbarButton(
                iconAsset: 'assets/icons/text.svg',
                label: 'Text',
                onTap: _addText,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String iconAsset;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              iconAsset,
              width: 26,
              height: 26,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

enum StoryElementType { text, sticker, drawing }

class StoryElement {
  final StoryElementType type;
  final String content;
  final TextStyle? style;
  final Offset position;

  StoryElement({
    required this.type,
    required this.content,
    this.style,
    required this.position,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'content': content,
    'style': style != null ? {
      'color': style!.color?.value.toRadixString(16),
      'fontSize': style!.fontSize,
      'fontWeight': style!.fontWeight?.index,
    } : null,
    'position': {'x': position.dx, 'y': position.dy},
  };
}

class _TextEditorDialog extends StatefulWidget {
  final String? initialText;
  final TextStyle initialStyle;
  final Function(String, TextStyle) onSave;

  const _TextEditorDialog({
    this.initialText,
    required this.initialStyle,
    required this.onSave,
  });

  @override
  State<_TextEditorDialog> createState() => _TextEditorDialogState();
}

class _TextEditorDialogState extends State<_TextEditorDialog> {
  late TextEditingController _controller;
  late TextStyle _currentStyle;
  final List<Color> _colors = [
    Colors.white,
    Colors.black,
    RippleColors.primary,
    RippleColors.tertiary,
    RippleColors.quaternary,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.pink,
    Colors.purple,
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _currentStyle = widget.initialStyle;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: RippleColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RippleConstants.borderRadiusXLarge),
      ),
      title: const Text('Add Text', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              maxLines: 4,
              maxLength: 200,
              style: _currentStyle.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type something...',
                hintStyle: TextStyle(color: RippleColors.textTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(RippleConstants.borderRadiusMedium),
                  borderSide: BorderSide(color: RippleColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(RippleConstants.borderRadiusMedium),
                  borderSide: BorderSide(color: RippleColors.primary),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text('Color', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: RippleColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colors.map((color) => GestureDetector(
                onTap: () => setState(() => _currentStyle = _currentStyle.copyWith(color: color)),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: _currentStyle.color == color
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
            Text('Style', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: RippleColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _StyleButton(
                  label: 'Normal',
                  isSelected: _currentStyle.fontWeight != FontWeight.bold,
                  onTap: () => setState(() => _currentStyle = _currentStyle.copyWith(fontWeight: FontWeight.normal)),
                ),
                _StyleButton(
                  label: 'Bold',
                  isSelected: _currentStyle.fontWeight == FontWeight.bold,
                  onTap: () => setState(() => _currentStyle = _currentStyle.copyWith(fontWeight: FontWeight.bold)),
                ),
                _StyleButton(
                  label: 'Outline',
                  isSelected: false,
                  onTap: () => setState(() => _currentStyle = _currentStyle.copyWith(
                    foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 2,
                  )),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              widget.onSave(_controller.text.trim(), _currentStyle);
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: RippleColors.primary),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _StyleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StyleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? RippleColors.primary : RippleColors.surfaceVariant,
          borderRadius: BorderRadius.circular(RippleConstants.borderRadiusFull),
          border: Border.all(
            color: isSelected ? RippleColors.primary : RippleColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : RippleColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}