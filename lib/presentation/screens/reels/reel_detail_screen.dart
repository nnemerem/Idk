import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';
import 'package:ripple/core/utils/auth_guard.dart';

class ReelDetailScreen extends StatefulWidget {
  final String reelId;

  const ReelDetailScreen({super.key, required this.reelId});

  @override
  State<ReelDetailScreen> createState() => _ReelDetailScreenState();
}

class _ReelDetailScreenState extends State<ReelDetailScreen> {
  Map<String, dynamic>? _reel;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isLoadingComments = false;
  final TextEditingController _commentController = TextEditingController();
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _loadReel();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadReel() async {
    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tableReels)
          .select('''
            *,
            profiles:user_id (id, username, display_name, avatar_url),
            likes:reel_likes (count),
            comments:reel_comments (count),
            is_liked:reel_likes!inner (user_id)
          ''')
          .eq('id', widget.reelId)
          .single();

      if (mounted) {
        setState(() {
          _reel = response;
          _isLoading = false;
        });
        _initializeVideo();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initializeVideo() {
    final videoUrl = _reel?['video_url'] as String?;
    if (videoUrl == null) return;

    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _controller.setLooping(true);
            _controller.play();
            _isPlaying = true;
          });
        }
      });
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);

    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tableComments)
          .select('''
            *,
            profiles:user_id (id, username, display_name, avatar_url)
          ''')
          .eq('reel_id', widget.reelId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(response);
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingComments = false);
      }
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

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    AuthGuard.run(context, onAuthenticated: () async {
      try {
        final currentUserId = SupabaseService().currentUser!.id;
        await SupabaseService().client.from(RippleConstants.tableComments).insert({
          'reel_id': widget.reelId,
          'user_id': currentUserId,
          'content': content,
          'created_at': DateTime.now().toIso8601String(),
        });

        _commentController.clear();
        _loadComments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add comment'),
              backgroundColor: RippleColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }, actionName: 'comment');
  }

  void _onLike() {
    if (_reel == null) return;
    final isLiked = _getIsLiked();
    AuthGuard.run(context, onAuthenticated: () async {
      try {
        if (isLiked) {
          await SupabaseService().client
              .from('reel_likes')
              .delete()
              .eq('reel_id', widget.reelId)
              .eq('user_id', SupabaseService().currentUser!.id);
        } else {
          await SupabaseService().client.from('reel_likes').insert({
            'reel_id': widget.reelId,
            'user_id': SupabaseService().currentUser!.id,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        setState(() {
          final likesCount = _reel!['likes']?['count'] ?? 0;
          _reel!['likes'] = {'count': isLiked ? likesCount - 1 : likesCount + 1};
          _reel!['is_liked'] = !isLiked;
        });
      } catch (e) {
        setState(() {});
      }
    }, actionName: 'like');
  }

  void _onSave() {
    AuthGuard.run(context, onAuthenticated: () async {
      try {
        await SupabaseService().client.from(RippleConstants.tableSavedPosts).upsert({
          'user_id': SupabaseService().currentUser!.id,
          'reel_id': widget.reelId,
          'created_at': DateTime.now().toIso8601String(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reel saved'), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        // Ignore
      }
    }, actionName: 'save');
  }

  void _onShare() {
    AuthGuard.run(context, onAuthenticated: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share feature coming soon'), behavior: SnackBarBehavior.floating),
      );
    }, actionName: 'share');
  }

  int _getLikesCount() {
    final likes = _reel?['likes'];
    if (likes is Map && likes['count'] != null) {
      return likes['count'] as int;
    }
    return 0;
  }

  int _getCommentsCount() {
    final comments = _reel?['comments'];
    if (comments is Map && comments['count'] != null) {
      return comments['count'] as int;
    }
    return _comments.length;
  }

  bool _getIsLiked() {
    final isLiked = _reel?['is_liked'];
    if (isLiked is List) {
      return isLiked.isNotEmpty;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: RippleColors.primary)),
      );
    }

    if (_reel == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Reel not found', style: TextStyle(color: RippleColors.textSecondary)),
        ),
      );
    }

    final profile = _reel!['profiles'] as Map<String, dynamic>?;
    final caption = _reel!['caption'] as String?;
    final musicTitle = _reel!['music_title'] as String?;
    final musicArtist = _reel!['music_artist'] as String?;
    final likesCount = _getLikesCount();
    final commentsCount = _getCommentsCount();
    final isLiked = _getIsLiked();
    final videoUrl = _reel!['video_url'] as String?;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _togglePlayPause,
        onDoubleTap: _onLike,
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
            else
              Center(child: CircularProgressIndicator(color: RippleColors.primary)),

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

            // Play/pause indicator
            if (!_isInitialized || !_isPlaying)
              Center(
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

            // Right side actions
            Positioned(
              right: 16,
              bottom: 120,
              child: Column(
                children: [
                  _ActionButton(
                    icon: profile?['avatar_url'] != null ? null : Icons.person_outline,
                    avatarUrl: profile?['avatar_url'],
                    label: _formatCount(likesCount),
                    isActive: isLiked,
                    activeColor: RippleColors.error,
                    onTap: _onLike,
                  ),
                  const SizedBox(height: 24),
                  _ActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: _formatCount(commentsCount),
                    onTap: () {
                      // Comments are already visible
                    },
                  ),
                  const SizedBox(height: 24),
                  _ActionButton(
                    icon: Icons.send_outlined,
                    label: '',
                    onTap: _onShare,
                  ),
                  const SizedBox(height: 24),
                  _ActionButton(
                    icon: Icons.bookmark_outline,
                    label: '',
                    onTap: _onSave,
                  ),
                  const SizedBox(height: 24),
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
                    onTap: () {
                      if (profile?['username'] != null) {
                        context.go('/user/${profile!['username']}');
                      }
                    },
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
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Comments panel (bottom sheet style)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildCommentsPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsPanel() {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: RippleColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(RippleConstants.borderRadiusXLarge)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: RippleColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Comments header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$commentsCount',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: RippleColors.textSecondary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/icons/keyboard_arrow_down.svg',
                    width: 28,
                    height: 28,
                  ),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: RippleColors.divider),

          // Comments list
          Expanded(
            child: _isLoadingComments
                ? Center(child: CircularProgressIndicator(color: RippleColors.primary))
                : _comments.isEmpty
                    ? Center(
                        child: Text(
                          'No comments yet',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: RippleColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final commentProfile = comment['profiles'] as Map<String, dynamic>?;
                          return _buildComment(comment, commentProfile);
                        },
                      ),
          ),

          // Comment input
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildComment(Map<String, dynamic> comment, Map<String, dynamic>? profile) {
    final content = comment['content'] as String?;
    final createdAt = comment['created_at'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (profile?['username'] != null) {
                context.go('/user/${profile!['username']}');
              }
            },
            child: CircleAvatar(
              radius: 16,
              backgroundColor: RippleColors.surfaceVariant,
              backgroundImage: profile?['avatar_url'] != null
                  ? CachedNetworkImageProvider(profile!['avatar_url'])
                  : null,
              child: profile?['avatar_url'] == null
                  ? Text(
                      profile?['username']?[0]?.toUpperCase() ?? '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (profile?['username'] != null) {
                          context.go('/user/${profile!['username']}');
                        }
                      },
                      child: Text(
                        profile?['username'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (createdAt != null)
                      Text(
                        _formatTimestamp(createdAt),
                        style: TextStyle(color: RippleColors.textTertiary, fontSize: 11),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  content ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: RippleColors.surfaceVariant,
            backgroundImage: SupabaseService().currentUser?.userMetadata?['avatar_url'] != null
                ? CachedNetworkImageProvider(SupabaseService().currentUser!.userMetadata!['avatar_url'])
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _commentController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: TextStyle(color: RippleColors.textTertiary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _addComment(),
            ),
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/send.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            onPressed: _addComment,
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
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

class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final String? avatarUrl;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _ActionButton({
    this.icon,
    this.avatarUrl,
    required this.label,
    this.isActive = false,
    this.activeColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          if (avatarUrl != null)
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              backgroundImage: CachedNetworkImageProvider(avatarUrl!),
            )
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/icons/heart.svg',
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
        // TODO: Navigate to music page
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