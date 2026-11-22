import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/supabase_service.dart';
import '../../core/utils/auth_guard.dart';
import '../../presentation/components/post_card.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isLoadingComments = false;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPost();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tablePosts)
          .select('''
            *,
            profiles:user_id (id, username, display_name, avatar_url),
            likes:post_likes (count),
            comments:post_comments (count),
            is_liked:post_likes!inner (user_id)
          ''')
          .eq('id', widget.postId)
          .single();

      if (mounted) {
        setState(() {
          _post = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          .eq('post_id', widget.postId)
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

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    AuthGuard.run(context, onAuthenticated: () async {
      try {
        final currentUserId = SupabaseService().currentUser!.id;
        await SupabaseService().client.from(RippleConstants.tableComments).insert({
          'post_id': widget.postId,
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
    if (_post == null) return;
    final isLiked = _getIsLiked();
    AuthGuard.run(context, onAuthenticated: () async {
      try {
        if (isLiked) {
          await SupabaseService().client
              .from('post_likes')
              .delete()
              .eq('post_id', widget.postId)
              .eq('user_id', SupabaseService().currentUser!.id);
        } else {
          await SupabaseService().client.from('post_likes').insert({
            'post_id': widget.postId,
            'user_id': SupabaseService().currentUser!.id,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        setState(() {
          final likesCount = _post!['likes']?['count'] ?? 0;
          _post!['likes'] = {'count': isLiked ? likesCount - 1 : likesCount + 1};
          _post!['is_liked'] = !isLiked;
        });
      } catch (e) {
        setState(() {}); // Revert
      }
    }, actionName: 'like');
  }

  void _onSave() {
    AuthGuard.run(context, onAuthenticated: () async {
      try {
        await SupabaseService().client.from(RippleConstants.tableSavedPosts).upsert({
          'user_id': SupabaseService().currentUser!.id,
          'post_id': widget.postId,
          'created_at': DateTime.now().toIso8601String(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post saved'), behavior: SnackBarBehavior.floating),
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
    final likes = _post?['likes'];
    if (likes is Map && likes['count'] != null) {
      return likes['count'] as int;
    }
    return 0;
  }

  int _getCommentsCount() {
    final comments = _post?['comments'];
    if (comments is Map && comments['count'] != null) {
      return comments['count'] as int;
    }
    return _comments.length;
  }

  bool _getIsLiked() {
    final isLiked = _post?['is_liked'];
    if (isLiked is List) {
      return isLiked.isNotEmpty;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: RippleColors.background,
        appBar: AppBar(backgroundColor: RippleColors.background),
        body: Center(child: CircularProgressIndicator(color: RippleColors.primary)),
      );
    }

    if (_post == null) {
      return Scaffold(
        backgroundColor: RippleColors.background,
        appBar: AppBar(backgroundColor: RippleColors.background),
        body: Center(
          child: Text('Post not found', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: RippleColors.textSecondary)),
        ),
      );
    }

    final profile = _post!['profiles'] as Map<String, dynamic>?;
    final mediaUrls = _getMediaUrls();
    final isCarousel = mediaUrls.length > 1;
    final likesCount = _getLikesCount();
    final commentsCount = _getCommentsCount();
    final isLiked = _getIsLiked();
    final caption = _post!['caption'] as String?;
    final location = _post!['location'] as String?;
    final createdAt = _post!['created_at'] as String?;

    return Scaffold(
      backgroundColor: RippleColors.background,
      appBar: AppBar(
        backgroundColor: RippleColors.background,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/icons/arrow_back.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/more_vert.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            onPressed: () {
              // TODO: Post options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Post content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(profile, location, createdAt),

                  // Media
                  _buildMedia(mediaUrls, isCarousel),

                  // Actions
                  _buildActions(likesCount, commentsCount, isLiked),

                  // Likes
                  if (likesCount > 0) _buildLikesCount(likesCount),

                  // Caption
                  if (caption != null && caption.isNotEmpty)
                    _buildCaption(profile, caption),

                  // Comments preview
                  if (commentsCount > 0)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'View all $commentsCount comments',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: RippleColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Comments section
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: RippleColors.surface,
              border: Border(top: BorderSide(color: RippleColors.divider)),
            ),
            child: Column(
              children: [
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
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    Map<String, dynamic>? profile,
    String? location,
    String? createdAt,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (profile?['username'] != null) {
                context.go('/user/${profile!['username']}');
              }
            },
            child: CircleAvatar(
              radius: 20,
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
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (profile?['username'] != null) {
                  context.go('/user/${profile!['username']}');
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?['username'] ?? 'Unknown',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (location != null && location.isNotEmpty)
                    Row(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/location.svg',
                          width: 12,
                          height: 12,
                          colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          location,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: RippleColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (createdAt != null)
            Text(
              _formatTimestamp(createdAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: RippleColors.textTertiary,
              ),
            ),
        ],
      ),
    );
  }

  List<String> _getMediaUrls() {
    final media = _post!['media'] as List<dynamic>?;
    if (media == null) return [];

    return media
        .where((m) => m['url'] != null && m['url'].toString().isNotEmpty)
        .map((m) => m['url'] as String)
        .toList();
  }

  Widget _buildMedia(List<String> mediaUrls, bool isCarousel) {
    if (mediaUrls.isEmpty) return const SizedBox.shrink();

    if (isCarousel) {
      return SizedBox(
        height: MediaQuery.of(context).size.width,
        child: PageView.builder(
          itemCount: mediaUrls.length,
          itemBuilder: (context, index) {
            final mediaUrl = mediaUrls[index];
            final mediaItem = _post!['media']?.firstWhere(
              (m) => m['url'] == mediaUrl,
              orElse: () => <String, dynamic>{},
            );
            final isVideo = mediaItem?['type'] == 'video';

            return _buildMediaItem(mediaUrl, isVideo);
          },
        ),
      );
    }

    // Single media
    final mediaUrl = mediaUrls.first;
    final isVideo = _post!['media']?.firstWhere(
      (m) => m['url'] == mediaUrl,
      orElse: () => <String, dynamic>{},
    )['type'] == 'video';

    return _buildMediaItem(mediaUrl, isVideo);
  }

  Widget _buildMediaItem(String mediaUrl, bool isVideo) {
    return GestureDetector(
      onDoubleTap: _onLike,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
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
                  child: CircularProgressIndicator(color: RippleColors.primary, strokeWidth: 2),
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
        ],
      ),
    );
  }

  Widget _buildActions(int likesCount, int commentsCount, bool isLiked) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
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
            onPressed: _onLike,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/comment.svg',
              width: 28,
              height: 28,
            ),
            onPressed: () {
              // Scroll to comments
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/send.svg',
              width: 28,
              height: 28,
            ),
            onPressed: _onShare,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          const Spacer(),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/bookmark.svg',
              width: 28,
              height: 28,
            ),
            onPressed: _onSave,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  Widget _buildLikesCount(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          // TODO: Show likes list
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

  Widget _buildCaption(Map<String, dynamic>? profile, String caption) {
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
          CircleAvatar(
            radius: 16,
            backgroundColor: RippleColors.surfaceVariant,
            backgroundImage: profile?['avatar_url'] != null
                ? CachedNetworkImageProvider(profile!['avatar_url'])
                : null,
            child: profile?['avatar_url'] == null
                ? Text(
                    profile?['username']?[0]?.toUpperCase() ?? '?',
                    style: const TextStyle(color: RippleColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 11),
                  )
                : null,
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
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (createdAt != null)
                      Text(
                        _formatTimestamp(createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: RippleColors.textTertiary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  content ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RippleColors.surface,
        border: Border(top: BorderSide(color: RippleColors.divider)),
      ),
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
              style: const TextStyle(color: RippleColors.textPrimary),
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
              colorFilter: ColorFilter.mode(RippleColors.primary, BlendMode.srcIn),
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

class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const _VideoPlayerWidget({required this.videoUrl});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _controller.setLooping(true);
            _controller.play();
          });
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
        child: Center(child: CircularProgressIndicator(color: RippleColors.primary)),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}