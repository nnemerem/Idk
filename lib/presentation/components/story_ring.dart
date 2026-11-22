import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:timeago/timeago.dart' as timeago;
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
  final bool isViewed;
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
    this.isViewed = false,
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
                      gradient: isViewed
                          ? null
                          : LinearGradient(
                              colors: RippleColors.storyRingGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: isViewed ? RippleColors.border : null,
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

/// One user's stories as a single browsing group (Instagram parity).
class StoryUserGroup {
  final String userId;
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> stories;

  const StoryUserGroup({
    required this.userId,
    required this.profile,
    required this.stories,
  });
}

/// Fullscreen story viewer.
///
/// Browses every group (every user's story) as a flat PageView:
/// left tap = previous story, right tap = next story, swipe = next/prev,
/// long-press = pause. Progress bars reflect the stories in the current
/// group; video stories auto-advance at their real duration.
class StoryViewer extends StatefulWidget {
  final List<StoryUserGroup> groups;
  final int initialIndex;
  final String? currentUserId;
  final VoidCallback? onClose;
  final void Function(Map<String, dynamic> story, String ownerId)? onStoryShown;
  final void Function(String userId)? onHideGroup;

  const StoryViewer({
    super.key,
    required this.groups,
    this.initialIndex = 0,
    this.currentUserId,
    this.onClose,
    this.onStoryShown,
    this.onHideGroup,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  int _flatIndex = 0;
  bool _isPaused = false;
  static const Duration _imageDuration = Duration(seconds: 5);
  static const Duration _videoFallback = Duration(seconds: 5);
  final Map<int, Duration> _videoDurations = {};
  final Map<int, bool> _viewedPages = {};

  late final List<Map<String, dynamic>> _flat;
  late final List<int> _groupStart;
  late final List<int> _groupEnd;
  late final List<String> _groupUserId;

  @override
  void initState() {
    super.initState();
    _flat = [for (final g in widget.groups) ...g.stories];
    _groupStart = [];
    _groupEnd = [];
    _groupUserId = [];
    int cursor = 0;
    for (final g in widget.groups) {
      _groupStart.add(cursor);
      _groupEnd.add(cursor + g.stories.length - 1);
      _groupUserId.add(g.userId);
      cursor += g.stories.length;
    }
    _flatIndex = widget.initialIndex.clamp(0, _flat.length - 1);
    _pageController = PageController(initialPage: _flatIndex);
    _createProgressController();
    _markViewed(_flatIndex);
    _progressController.forward().then((_) {
      if (!_isPaused && mounted) _nextPage();
    });
  }

  int get _totalPages => _flat.length;

  int _groupOf(int flatIndex) {
    for (int i = 0; i < _groupStart.length; i++) {
      if (flatIndex >= _groupStart[i] && flatIndex <= _groupEnd[i]) return i;
    }
    return 0;
  }

  int _storyIndexInGroup(int flatIndex) => flatIndex - _groupStart[_groupOf(flatIndex)];

  int _storiesInCurrentGroup(int flatIndex) =>
      _groupEnd[_groupOf(flatIndex)] - _groupStart[_groupOf(flatIndex)] + 1;

  Duration _durationFor(int flatIndex) {
    final story = _flat[flatIndex];
    final mediaType = story['media_type'] as String? ?? 'image';
    if (mediaType == 'video') {
      final d = _videoDurations[flatIndex];
      return d != null && d.inMilliseconds > 0 ? d : _videoFallback;
    }
    return _imageDuration;
  }

  void _createProgressController() {
    _progressController = AnimationController(
      vsync: this,
      duration: _durationFor(_flatIndex),
    );
  }

  void _markViewed(int flatIndex) {
    if (flatIndex < 0 || flatIndex >= _totalPages) return;
    if (_viewedPages[flatIndex] == true) return;
    _viewedPages[flatIndex] = true;
    final story = _flat[flatIndex];
    widget.onStoryShown?.call(story, _groupUserId[_groupOf(flatIndex)]);
  }

  void _restartProgress() {
    final story = _flat[_flatIndex];
    final mediaType = story['media_type'] as String? ?? 'image';
    final duration = mediaType == 'video'
        ? (_videoDurations[_flatIndex] ?? _videoFallback)
        : _imageDuration;
    _progressController.dispose();
    _progressController = AnimationController(vsync: this, duration: duration);
    final started = _flatIndex;
    _progressController.forward().then((_) {
      if (!_isPaused && mounted && _flatIndex == started) _nextPage();
    });
  }

  void _onPageChanged(int page) {
    setState(() => _flatIndex = page);
    _markViewed(page);
    _restartProgress();
  }

  void _resumeProgress() {
    final started = _flatIndex;
    _progressController.forward(from: _progressController.value).then((_) {
      if (!_isPaused && mounted && _flatIndex == started) _nextPage();
    });
  }

  void _nextPage() {
    if (_flatIndex < _totalPages - 1) {
      _pageController.nextPage(
        duration: RippleConstants.animationNormal,
        curve: Curves.easeInOut,
      );
    } else {
      widget.onClose?.call();
    }
  }

  void _previousPage() {
    if (_flatIndex > 0) {
      _pageController.previousPage(
        duration: RippleConstants.animationNormal,
        curve: Curves.easeInOut,
      );
    }
  }

  void _onVideoReady(int flatIndex, Duration duration) {
    if (!mounted || flatIndex != _flatIndex) return;
    setState(() {
      _videoDurations[flatIndex] = duration;
    });
    if (!_isPaused && mounted) _restartProgress();
  }

  void _onVideoEnded(int flatIndex) {
    if (flatIndex != _flatIndex) return;
    _nextPage();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = _groupOf(_flatIndex);
    final groupStories = widget.groups[group].stories;
    final storyIdxInGroup = _storyIndexInGroup(_flatIndex);
    final currentStory = _flat[_flatIndex];
    final ownUserId = widget.currentUserId;
    final storyOwnerId = currentStory['user_id'] as String?;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) => _handleTapDown,
        onLongPressStart: (_) {
          setState(() => _isPaused = true);
          _progressController.stop();
        },
        onLongPressEnd: (_) => setState(() {
          _isPaused = false;
          _resumeProgress();
        }),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _totalPages,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final story = _flat[index];
                final mediaUrl = story['media_url'] as String?;
                final mediaType = story['media_type'] as String? ?? 'image';

                if (mediaType == 'video' && mediaUrl != null) {
                  return _VideoStoryPlayer(
                    videoUrl: mediaUrl,
                    isPaused: _isPaused,
                    onReady: (d) => _onVideoReady(index, d),
                    onEnded: () => _onVideoEnded(index),
                  );
                }
                return Center(
                  child: mediaUrl != null
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
                        // Progress bars (current group only)
                        Expanded(
                          child: Row(
                            children: [
                              for (int i = 0; i < groupStories.length; i++)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: i < groupStories.length - 1 ? 4 : 0,
                                    ),
                                    child: _ProgressBar(
                                      index: i,
                                      currentIndex: storyIdxInGroup,
                                      controller: _progressController,
                                    ),
                                  ),
                                ),
                            ],
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
              child: _buildStoryHeader(currentStory, ownUserId, storyOwnerId),
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
      _previousPage();
    } else if (tapX > screenWidth * 2 / 3) {
      _nextPage();
    }
  }

  Widget _buildStoryHeader(
    Map<String, dynamic> story,
    String? currentUserId,
    String? storyOwnerId,
  ) {
    final profile = story['profiles'] as Map<String, dynamic>?;
    final timestamp = story['created_at'] as String?;
    final isOwnStory = currentUserId != null && storyOwnerId == currentUserId;

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: RippleColors.surfaceVariant,
          backgroundImage: profile?['avatar_url'] != null
              ? CachedNetworkImageProvider(profile!['avatar_url'] as String)
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
        if (!isOwnStory && widget.onHideGroup != null) // Show actions only for others' stories
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
                            final viewerUserId = widget.groups[_groupOf(_flatIndex)].userId;
                            widget.onHideGroup?.call(viewerUserId);
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

class _VideoStoryPlayer extends StatefulWidget {
  final String videoUrl;
  final bool isPaused;
  final void Function(Duration duration)? onReady;
  final VoidCallback? onEnded;

  const _VideoStoryPlayer({
    required this.videoUrl,
    this.isPaused = false,
    this.onReady,
    this.onEnded,
  });

  @override
  State<_VideoStoryPlayer> createState() => _VideoStoryPlayerState();
}

class _VideoStoryPlayerState extends State<_VideoStoryPlayer> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _sentEnd = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            if (!widget.isPaused) {
              _controller.play();
            }
          });
          final duration = _controller.value.duration;
          widget.onReady?.call(duration);
        }
      });
    _controller.addListener(_onVideoTick);
  }

  void _onVideoTick() {
    if (_sentEnd) return;
    if (!_isInitialized) return;
    final value = _controller.value;
    if (value.duration.inMilliseconds > 0 && value.position >= value.duration) {
      _sentEnd = true;
      _controller.pause();
      widget.onEnded?.call();
    }
  }

  @override
  void didUpdateWidget(covariant _VideoStoryPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPaused != widget.isPaused) {
      if (widget.isPaused) {
        _controller.pause();
      } else {
        if (_isInitialized) _controller.play();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || !_controller.value.isInitialized) {
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
