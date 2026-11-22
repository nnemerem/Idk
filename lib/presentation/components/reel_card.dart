import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';

typedef LikeCallback = void Function(String reelId, bool currentlyLiked);
typedef SaveCallback = void Function(String reelId);
typedef ShareCallback = void Function(String reelId);
typedef CommentCallback = void Function(String reelId);
typedef ProfileTapCallback = void Function(String username);

class ReelCard extends StatefulWidget {
  final Map<String, dynamic> reel;
  final bool isCurrent;
  final bool isSaved;
  final LikeCallback onLike;
  final SaveCallback onSave;
  final ShareCallback onShare;
  final CommentCallback onComment;
  final ProfileTapCallback onProfileTap;

  const ReelCard({
    super.key,
    required this.reel,
    required this.isCurrent,
    this.isSaved = false,
    required this.onLike,
    required this.onSave,
    required this.onShare,
    required this.onComment,
    required this.onProfileTap,
  });

  @override
  State<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<ReelCard> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant ReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent != oldWidget.isCurrent) {
      if (widget.isCurrent && _isInitialized) {
        _controller.play();
        setState(() => _isPlaying = true);
      } else {
        _controller.pause();
        setState(() => _isPlaying = false);
      }
    }
  }

  Future<void> _initializeVideo() async {
    final videoUrl = widget.reel['video_url'] as String?;
    if (videoUrl == null) return;

    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    try {
      await _controller.initialize();
      _controller.setLooping(true);
      if (mounted) {
        setState(() {
          _isInitialized = true;
          if (widget.isCurrent) {
            _controller.play();
            _isPlaying = true;
          }
        });
      }
    } catch (e) {
      // Video failed to load
    }
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;

    setState(() {
      if (_isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
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
    final profile = widget.reel['profiles'] as Map<String, dynamic>?;
    final caption = widget.reel['caption'] as String?;
    final musicTitle = widget.reel['music_title'] as String?;
    final musicArtist = widget.reel['music_artist'] as String?;
    final likesCount = _getLikesCount();
    final commentsCount = _getCommentsCount();
    final isLiked = _getIsLiked();
    final videoUrl = widget.reel['video_url'] as String?;
    final thumbnailUrl = widget.reel['thumbnail_url'] as String?;

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: () => widget.onLike(
        widget.reel['id'] as String,
        isLiked,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player
          if (_isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          else if (thumbnailUrl != null)
            CachedNetworkImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => Container(
                color: RippleColors.surfaceVariant,
                child: Center(
                  child: CircularProgressIndicator(color: RippleColors.primary),
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
          else
            Container(color: RippleColors.surfaceVariant),

          // Gradient overlay at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Play/pause indicator (center)
          if (!_isInitialized || !widget.isCurrent)
            Center(
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: RippleConstants.animationFast,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    _isPlaying ? 'assets/icons/pause.svg' : 'assets/icons/play.svg',
                    width: 40,
                    height: 40,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
              ),
            ),

          // Right side actions
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                _ActionButton(
                  iconAsset: 'assets/icons/heart.svg',
                  activeIconAsset: 'assets/icons/heart_filled.svg',
                  label: _formatCount(likesCount),
                  isActive: isLiked,
                  activeColor: RippleColors.error,
                  onTap: () => widget.onLike(
                    widget.reel['id'] as String,
                    isLiked,
                  ),
                ),
                const SizedBox(height: 24),
                _ActionButton(
                  iconAsset: 'assets/icons/comment.svg',
                  label: _formatCount(commentsCount),
                  onTap: () => widget.onComment(widget.reel['id'] as String),
                ),
                const SizedBox(height: 24),
                _ActionButton(
                  iconAsset: 'assets/icons/send.svg',
                  label: '',
                  onTap: () => widget.onShare(widget.reel['id'] as String),
                ),
                const SizedBox(height: 24),
                _ActionButton(
                  iconAsset: 'assets/icons/bookmark.svg',
                  activeIconAsset: 'assets/icons/bookmark_filled.svg',
                  label: '',
                  isActive: widget.isSaved,
                  onTap: () => widget.onSave(widget.reel['id'] as String),
                ),
                const SizedBox(height: 24),
                // Music/remix button
                if (musicTitle != null)
                  _MusicButton(
                    musicTitle: musicTitle,
                    musicArtist: musicArtist,
                  ),
              ],
            ),
          ),

          // Left side - profile and caption
          Positioned(
            left: 16,
            right: 100,
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile row
                GestureDetector(
                  onTap: () => widget.onProfileTap(profile?['username'] ?? ''),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: RippleColors.surfaceVariant,
                        backgroundImage: profile?['avatar_url'] != null
                            ? CachedNetworkImageProvider(profile!['avatar_url'])
                            : null,
                        child: profile?['avatar_url'] == null
                            ? Text(
                                profile?['username']?[0]?.toUpperCase() ?? '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?['display_name'] ?? profile?['username'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (musicTitle != null)
                            Row(
                              children: [
                                SvgPicture.asset(
                                  'assets/icons/music.svg',
                                  width: 12,
                                  height: 12,
                                  colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: 0.8), BlendMode.srcIn),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '$musicTitle${musicArtist != null ? ' - $musicArtist' : ''}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Caption
                if (caption != null && caption.isNotEmpty)
                  Text(
                    caption,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getLikesCount() {
    final likes = widget.reel['likes'];
    if (likes is Map && likes['count'] != null) {
      return likes['count'] as int;
    }
    return 0;
  }

  int _getCommentsCount() {
    final comments = widget.reel['comments'];
    if (comments is Map && comments['count'] != null) {
      return comments['count'] as int;
    }
    return 0;
  }

  bool _getIsLiked() {
    final isLiked = widget.reel['is_liked'];
    if (isLiked is List) {
      return isLiked.isNotEmpty;
    }
    return false;
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class _ActionButton extends StatelessWidget {
  final String iconAsset;
  final String? activeIconAsset;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.iconAsset,
    this.activeIconAsset,
    required this.label,
    this.isActive = false,
    this.activeColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final asset = isActive && activeIconAsset != null
        ? activeIconAsset!
        : iconAsset;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              asset,
              width: 28,
              height: 28,
              colorFilter: ColorFilter.mode(
                isActive ? activeColor : Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MusicButton extends StatelessWidget {
  final String musicTitle;
  final String? musicArtist;

  const _MusicButton({
    required this.musicTitle,
    this.musicArtist,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: RippleColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RippleConstants.borderRadiusLarge),
            ),
            title: const Text('Music'),
            content: Text('$musicTitle${musicArtist != null ? ' — $musicArtist' : ''}'),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(RippleConstants.borderRadiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/music.svg',
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(RippleColors.primary, BlendMode.srcIn),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    musicTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (musicArtist != null)
                    Text(
                      musicArtist!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}