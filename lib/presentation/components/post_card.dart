import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ripple/presentation/components/likes_list_sheet.dart';
import 'package:ripple/presentation/components/double_tap_like_burst.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';

typedef LikeCallback = void Function(String postId, bool currentlyLiked);
typedef SaveCallback = void Function(String postId);
typedef ShareCallback = void Function(String postId);
typedef TapCallback = void Function();

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isSaved;
  final LikeCallback onLike;
  final SaveCallback onSave;
  final ShareCallback onShare;
  final TapCallback onTap;

  const PostCard({
    super.key,
    required this.post,
    this.isSaved = false,
    required this.onLike,
    required this.onSave,
    required this.onShare,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final profile = post['profiles'] as Map<String, dynamic>?;
    final mediaUrls = _getMediaUrls();
    final isCarousel = mediaUrls.length > 1;
    final likesCount = _getLikesCount();
    final commentsCount = _getCommentsCount();
    final isLiked = _getIsLiked();
    final caption = post['caption'] as String?;
    final location = post['location'] as String?;
    final createdAt = post['created_at'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: RippleColors.background,
        border: Border(
          bottom: BorderSide(color: RippleColors.divider, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context, profile, location, createdAt),

          // Media (image/video/carousel)
          _buildMedia(context, mediaUrls, isCarousel),

          // Actions
          _buildActions(context, likesCount, commentsCount, isLiked),

          // Likes count
          if (likesCount > 0) _buildLikesCount(context, likesCount),

          // Caption
          if (caption != null && caption.isNotEmpty) _buildCaption(context, profile, caption),

          // Comments preview
          if (commentsCount > 0) _buildCommentsPreview(context, commentsCount),

          // Timestamp
          if (createdAt != null) _buildTimestamp(context, createdAt),
        ],
      ),
    );
  }

  List<String> _getMediaUrls() {
    final media = post['media'] as List<dynamic>?;
    if (media == null) return [];

    return media
        .where((m) => m['url'] != null && m['url'].toString().isNotEmpty)
        .map((m) => m['url'] as String)
        .toList();
  }

  int _getLikesCount() {
    final likes = post['likes'];
    if (likes is Map && likes['count'] != null) {
      return likes['count'] as int;
    }
    return 0;
  }

  int _getCommentsCount() {
    final comments = post['comments'];
    if (comments is Map && comments['count'] != null) {
      return comments['count'] as int;
    }
    return 0;
  }

  bool _getIsLiked() {
    final isLiked = post['is_liked'];
    if (isLiked is List) {
      return isLiked.isNotEmpty;
    }
    return false;
  }

  Widget _buildHeader(
    BuildContext context,
    Map<String, dynamic>? profile,
    String? location,
    String? createdAt,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () {
              final username = profile?['username'] as String?;
              if (username != null) context.go('/user/$username');
            },
            child: CircleAvatar(
              radius: RippleConstants.avatarSizeMedium / 2,
              backgroundColor: RippleColors.surfaceVariant,
              backgroundImage: profile?['avatar_url'] != null
                  ? CachedNetworkImageProvider(profile!['avatar_url'])
                  : null,
              child: profile?['avatar_url'] == null
                  ? Text(
                      profile?['username']?[0]?.toUpperCase() ?? '?',
                      style: const TextStyle(
                        color: RippleColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Username and location
          Expanded(
            child: GestureDetector(
              onTap: () {
                final username = profile?['username'] as String?;
                if (username != null) context.go('/user/$username');
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?['username'] ?? 'Unknown',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (location != null && location.isNotEmpty)
                    Text(
                      location,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: RippleColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          // More options
          PopupMenuButton<String>(
            icon: SvgPicture.asset(
              'assets/icons/more_vert.svg',
              width: 24,
              height: 24,
            ),
            color: RippleColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RippleConstants.borderRadiusLarge),
            ),
            onSelected: (value) {
              if (value == 'copy_link') {
                onShare(post['id'] as String);
              } else if (value == 'report') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thanks — our team reviews reports'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'copy_link',
                child: Row(
                  children: [
                    SvgPicture.asset('assets/icons/link.svg', width: 18, height: 18),
                    const SizedBox(width: 12),
                    const Text('Copy link'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    SvgPicture.asset('assets/icons/flag.svg', width: 18, height: 18),
                    const SizedBox(width: 12),
                    const Text('Report'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(BuildContext context, List<String> mediaUrls, bool isCarousel) {
    if (mediaUrls.isEmpty) return const SizedBox.shrink();

    if (isCarousel) {
      return _buildCarousel(context, mediaUrls);
    }

    // Single media
    final mediaUrl = mediaUrls.first;
    final isVideo = post['media']?.firstWhere(
      (m) => m['url'] == mediaUrl,
      orElse: () => <String, dynamic>{},
    )['type'] == 'video';

    return DoubleTapLikeBurst(
      onTap: onTap,
      onDoubleTap: () {
        // Instagram parity: double-tap on media likes the post.
        final liked = _getIsLiked();
        if (!liked) onLike(post['id'] as String, false);
      },
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Media
          if (isVideo)
            _VideoPlayerWidget(videoUrl: mediaUrl)
          else
            CachedNetworkImage(
              imageUrl: mediaUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: MediaQuery.of(context).size.width,
              placeholder: (context, url) => Container(
                color: RippleColors.surfaceVariant,
                height: MediaQuery.of(context).size.width,
                child: Center(
                  child: CircularProgressIndicator(
                    color: RippleColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: RippleColors.surfaceVariant,
                height: MediaQuery.of(context).size.width,
                child: SvgPicture.asset(
                  'assets/icons/photo_library.svg',
                  width: 64,
                  height: 64,
                  colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
                ),
              ),
            ),
          // Video play indicator
          if (isVideo)
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/icons/play.svg',
                  width: 32,
                  height: 32,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCarousel(BuildContext context, List<String> mediaUrls) {
    return SizedBox(
      height: MediaQuery.of(context).size.width,
      child: PageView.builder(
        itemCount: mediaUrls.length,
        itemBuilder: (context, index) {
          final mediaUrl = mediaUrls[index];
          final mediaItem = post['media']?.firstWhere(
            (m) => m['url'] == mediaUrl,
            orElse: () => <String, dynamic>{},
          );
          final isVideo = mediaItem?['type'] == 'video';

          return DoubleTapLikeBurst(
            key: ValueKey(mediaUrl),
            onTap: onTap,
            onDoubleTap: () {
              final liked = _getIsLiked();
              if (!liked) onLike(post['id'] as String, false);
            },
            child: isVideo
                ? _VideoPlayerWidget(videoUrl: mediaUrl)
                : CachedNetworkImage(
                    imageUrl: mediaUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      color: RippleColors.surfaceVariant,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: RippleColors.primary,
                          strokeWidth: 2,
                        ),
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
                  ),
          );
        },
      ),
    );
  }

  Widget _buildActions(BuildContext context, int likesCount, int commentsCount, bool isLiked) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Like
          IconButton(
            icon: SvgPicture.asset(
              isLiked ? 'assets/icons/heart_filled.svg' : 'assets/icons/heart.svg',
              width: 28,
              height: 28,
              colorFilter: ColorFilter.mode(
                isLiked ? RippleColors.error : RippleColors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () => onLike(post['id'] as String, isLiked),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          const SizedBox(width: 4),
          // Comment
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/comment.svg',
              width: 28,
              height: 28,
            ),
            onPressed: () => onTap(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          const SizedBox(width: 4),
          // Share
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/send.svg',
              width: 28,
              height: 28,
            ),
            onPressed: () => onShare(post['id'] as String),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          const Spacer(),
          // Save
          IconButton(
            icon: SvgPicture.asset(
              isSaved ? 'assets/icons/bookmark_filled.svg' : 'assets/icons/bookmark.svg',
              width: 28,
              height: 28,
              colorFilter: isSaved
                  ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                  : null,
            ),
            onPressed: () => onSave(post['id'] as String),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  Widget _buildLikesCount(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          LikesListSheet.show(
            context,
            table: 'post_likes',
            idColumn: 'post_id',
            id: post['id'] as String,
          );
        },
        child: Text(
          '${_formatCount(count)} likes',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCaption(BuildContext context, Map<String, dynamic>? profile, String caption) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: RippleColors.textPrimary,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: '${profile?['username'] ?? 'Unknown'} ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: caption),
          ],
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCommentsPreview(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: () => onTap(),
        child: Text(
          'View all ${_formatCount(count)} comments',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: RippleColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context, String createdAt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        _formatTimestamp(createdAt),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: RippleColors.textTertiary,
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
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

class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const _VideoPlayerWidget({required this.videoUrl});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.setLooping(true);
          _controller.play();
        }
      })
      ..addListener(() {
        if (_controller.value.hasError) {
          // Handle error silently
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
    if (!_isInitialized) {
      return Container(
        color: RippleColors.surfaceVariant,
        height: MediaQuery.of(context).size.width,
        child: Center(
          child: CircularProgressIndicator(
            color: RippleColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}