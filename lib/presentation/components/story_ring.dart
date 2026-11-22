import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';

class StoryRing extends StatelessWidget {
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool hasStory;
  final bool isOwnStory;
  final bool isAddButton;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const StoryRing({
    super.key,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.hasStory,
    this.isOwnStory = false,
    this.isAddButton = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 72,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with ring
            Stack(
              alignment: Alignment.center,
              children: [
                // Gradient ring (only if has story)
                if (hasStory && !isAddButton)
                  Container(
                    width: RippleConstants.storyRingSize,
                    height: RippleConstants.storyRingSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: RippleColors.storyRingGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Container(
                      margin: EdgeInsets.all(RippleConstants.storyRingStrokeWidth),
                      decoration: BoxDecoration(
                        color: RippleColors.background,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                // Add button ring
                if (isAddButton)
                  Container(
                    width: RippleConstants.storyRingSize,
                    height: RippleConstants.storyRingSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: RippleColors.border,
                        width: RippleConstants.storyRingStrokeWidth,
                      ),
                    ),
                    child: Container(
                      margin: EdgeInsets.all(RippleConstants.storyRingStrokeWidth),
                      decoration: BoxDecoration(
                        color: RippleColors.background,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                // Avatar
                Container(
                  width: RippleConstants.storyRingSize - (RippleConstants.storyRingStrokeWidth * 2),
                  height: RippleConstants.storyRingSize - (RippleConstants.storyRingStrokeWidth * 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: RippleColors.background,
                      width: 2,
                    ),
                    image: avatarUrl != null && avatarUrl!.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatarUrl == null || avatarUrl!.isEmpty
                      ? SvgPicture.asset(
                          isAddButton ? 'assets/icons/plus_circle.svg' : 'assets/icons/profile.svg',
                          width: 28,
                          height: 28,
                          colorFilter: ColorFilter.mode(
                            isAddButton
                                ? RippleColors.primary
                                : RippleColors.textTertiary,
                            BlendMode.srcIn,
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Username
            Text(
              isAddButton ? 'Your Story' : username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: RippleColors.textPrimary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoryViewer extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;
  final VoidCallback? onClose;

  const StoryViewer({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    this.onClose,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  int _currentIndex = 0;
  bool _isPaused = false;
  static const Duration _storyDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _progressController = AnimationController(
      vsync: this,
      duration: _storyDuration,
    );
    _startProgress();
  }

  void _startProgress() {
    _progressController.forward(from: 0).then((_) {
      if (!_isPaused && mounted) {
        _nextStory();
      }
    });
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      _currentIndex++;
      _pageController.nextPage(
        duration: RippleConstants.animationNormal,
        curve: Curves.easeInOut,
      );
    } else {
      widget.onClose?.call();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _pageController.previousPage(
        duration: RippleConstants.animationNormal,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) => _handleTapDown,
        onTapUp: (_) => _handleTapUp,
        onLongPressStart: (_) => setState(() => _isPaused = true),
        onLongPressEnd: (_) => setState(() {
          _isPaused = false;
          _startProgress();
        }),
        child: Stack(
          children: [
            // Story content
            PageView.builder(
              controller: _pageController,
              itemCount: widget.stories.length,
              onPageChanged: (index) {
                _currentIndex = index;
                _progressController.reset();
                _startProgress();
              },
              itemBuilder: (context, index) {
                final story = widget.stories[index];
                final mediaUrl = story['media_url'] as String?;
                final mediaType = story['media_type'] as String? ?? 'image';
                final profile = story['profiles'] as Map<String, dynamic>?;

                return _StoryContent(
                  mediaUrl: mediaUrl,
                  mediaType: mediaType,
                  username: profile?['username'] ?? 'Unknown',
                  displayName: profile?['display_name'] ?? 'Unknown',
                  avatarUrl: profile?['avatar_url'],
                  caption: story['caption'] as String?,
                  timestamp: story['created_at'] as String?,
                );
              },
            ),

            // Top gradient overlay with progress bars
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        // Progress bars
                        Expanded(
                          child: Row(
                            children: List.generate(
                              widget.stories.length,
                              (index) => Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: index < widget.stories.length - 1 ? 4 : 0,
                                  ),
                                  child: _ProgressBar(
                                    index: index,
                                    currentIndex: _currentIndex,
                                    controller: _progressController,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Close button
                        IconButton(
                          icon: SvgPicture.asset(
                            'assets/icons/close.svg',
                            width: 28,
                            height: 28,
                          ),
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // User info at top
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: _buildStoryHeader(widget.stories[_currentIndex]),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;

    if (tapX < screenWidth / 3) {
      // Left third - previous story
      _previousStory();
    } else if (tapX > screenWidth * 2 / 3) {
      // Right third - next story
      _nextStory();
    }
  }

  void _handleTapUp(TapUpDetails details) {}

  Widget _buildStoryHeader(Map<String, dynamic> story) {
    final profile = story['profiles'] as Map<String, dynamic>?;
    final timestamp = story['created_at'] as String?;

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: RippleColors.surfaceVariant,
          backgroundImage: profile?['avatar_url'] != null
              ? CachedNetworkImageProvider(profile!['avatar_url'])
              : null,
          child: profile?['avatar_url'] == null
              ? SvgPicture.asset(
                  'assets/icons/profile.svg',
                  width: 16,
                  height: 16,
                  colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?['username'] ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (timestamp != null)
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        // Story actions
        Row(
          children: [
            IconButton(
              icon: SvgPicture.asset(
                'assets/icons/more_vert.svg',
                width: 22,
                height: 22,
              ),
              onPressed: () {
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
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: SvgPicture.asset('assets/icons/flag.svg', width: 24, height: 24),
                            title: const Text('Report story'),
                            onTap: () {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Thanks — our team reviews reports'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: SvgPicture.asset('assets/icons/visibility_off.svg', width: 24, height: 24),
                            title: const Text('Hide story'),
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onClose();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return timeago.format(dateTime, locale: 'en_short');
    } catch (e) {
      return '';
    }
  }
}

class _ProgressBar extends StatelessWidget {
  final int index;
  final int currentIndex;
  final AnimationController controller;

  const _ProgressBar({
    required this.index,
    required this.currentIndex,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        double progress = 0;
        if (index < currentIndex) {
          progress = 1;
        } else if (index == currentIndex) {
          progress = controller.value;
        }
        return Container(
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1.5),
            color: Colors.white.withValues(alpha: 0.3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1.5),
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StoryContent extends StatelessWidget {
  final String? mediaUrl;
  final String mediaType;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? caption;
  final String? timestamp;

  const _StoryContent({
    this.mediaUrl,
    required this.mediaType,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.caption,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: mediaType == 'video' && mediaUrl != null
          ? _VideoStoryPlayer(videoUrl: mediaUrl!)
          : mediaUrl != null
              ? CachedNetworkImage(
                  imageUrl: mediaUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                      color: RippleColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: RippleColors.surfaceVariant,
                    child: SvgPicture.asset(
                      'assets/icons/photo_library.svg',
                      width: 64,
                      height: 64,
                      colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
                    ),
                  ),
                )
              : Container(
                  color: RippleColors.surfaceVariant,
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/photo_library.svg',
                      width: 64,
                      height: 64,
                      colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
                    ),
                  ),
                ),
    );
  }
}

class _VideoStoryPlayer extends StatefulWidget {
  final String videoUrl;

  const _VideoStoryPlayer({required this.videoUrl});

  @override
  State<_VideoStoryPlayer> createState() => _VideoStoryPlayerState();
}

class _VideoStoryPlayerState extends State<_VideoStoryPlayer> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play();
          _controller.setLooping(true);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Center(
        child: CircularProgressIndicator(
          color: RippleColors.primary,
          strokeWidth: 2,
        ),
      );
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}