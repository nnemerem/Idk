import 'package:flutter/material.dart';
import 'package:ripple/presentation/components/likes_list_sheet.dart';
import 'package:ripple/presentation/components/share_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';
import 'package:ripple/core/utils/auth_guard.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _topLevelComments = [];
  Map<String, List<Map<String, dynamic>>> _repliesByParent = {};
  List<Map<String, dynamic>> _collections = [];
  Map<String, bool> _commentLikeStatus = {};   // commentId -> isLiked
  Map<String, int> _commentLikeCounts = {};    // commentId -> like count
  bool _isLoading = true;
  bool _isLoadingComments = false;
  bool _isSaved = false;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showAllComments = false;
  String? _replyingTo; // comment id whose reply input is open
  final Map<String, TextEditingController> _replyControllers = {};

  @override
  void initState() {
    super.initState();
    _loadPost();
    _loadComments();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    try {
      final collections = await SupabaseService().getCollections();
      if (mounted) {
        setState(() => _collections = List<Map<String, dynamic>>.from(collections));
      }
    } catch (e) {
      // Collections are non-critical
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    for (final c in _replyControllers.values) c.dispose();
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
        _loadSavedState();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSavedState() async {
    final userId = SupabaseService().currentUser?.id;
    if (userId == null) return;

    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tableSavedPosts)
          .select('post_id')
          .eq('user_id', userId)
          .eq('post_id', widget.postId);

      if (mounted) {
        setState(() => _isSaved = (response as List).isNotEmpty);
      }
    } catch (e) {
      // Best effort
    }
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);

    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tablePostComments)
          .select('''
            *,
            profiles:user_id (id, username, display_name, avatar_url)
          ''')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      final all = List<Map<String, dynamic>>.from(response);
      final topLevel = all.where((c) => c['parent_id'] == null).toList();
      final repliesByParent = <String, List<Map<String, dynamic>>>{};
      for (final c in all) {
        final pid = c['parent_id'];
        if (pid != null) {
          repliesByParent.putIfAbsent(pid, () => []).add(c);
        }
      }

      if (mounted) {
        setState(() {
          _topLevelComments = topLevel;
          _repliesByParent = repliesByParent;
          _isLoadingComments = false;
        });
        _loadCommentLikes();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingComments = false);
      }
    }
  }

  /// Load like status and counts for all comments (top-level + replies).
  Future<void> _loadCommentLikes() async {
    final currentUserId = SupabaseService().currentUser?.id;
    if (currentUserId == null) return;

    // Collect all comment ids
    final allIds = <String>[];
    for (final c in _topLevelComments) {
      final id = c['id'];
      if (id != null) allIds.add(id);
    }
    for (final replies in _repliesByParent.values) {
      for (final c in replies) {
        final id = c['id'];
        if (id != null) allIds.add(id);
      }
    }

    final likeStatus = <String, bool>{};
    final likeCounts = <String, int>{};

    for (final id in allIds) {
      try {
        final liked = await SupabaseService().isPostCommentLiked(id);
        final count = await SupabaseService().getPostCommentLikesCount(id);
        likeStatus[id] = liked;
        likeCounts[id] = count;
      } catch (_) {
        likeStatus[id] = false;
        likeCounts[id] = 0;
      }
    }

    if (mounted) {
      setState(() {
        _commentLikeStatus = likeStatus;
        _commentLikeCounts = likeCounts;
      });
    }
  }

  /// Toggle like on a post comment.
  Future<void> _toggleCommentLike(String commentId) async {
    final currentlyLiked = _commentLikeStatus[commentId] == true;
    final currentCount = _commentLikeCounts[commentId] ?? 0;

    // Optimistic update
    setState(() {
      _commentLikeStatus[commentId] = !currentlyLiked;
      _commentLikeCounts[commentId] = currentlyLiked
          ? (currentCount - 1).clamp(0, 1000000)
          : currentCount + 1;
    });

    try {
      if (currentlyLiked) {
        await SupabaseService().unlikePostComment(commentId);
      } else {
        await SupabaseService().likePostComment(commentId);
      }
      // Refresh to get authoritative state
      _loadCommentLikes();
    } catch (e) {
      // Revert optimistic update on failure
      setState(() {
        _commentLikeStatus[commentId] = currentlyLiked;
        _commentLikeCounts[commentId] = currentCount;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${currentlyLiked ? 'unlike' : 'like'} comment'),
            backgroundColor: RippleColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _addComment({String? parentId}) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    AuthGuard.run(context, onAuthenticated: () async {
      try {
        await SupabaseService().createPostComment(
          postId: widget.postId,
          content: content,
          parentId: parentId,
        );

        // Notify mentioned users (best effort — never breaks the comment)
        try {
          final myProfile = await SupabaseService().getProfile(
            SupabaseService().currentUser!.id,
          );
          final myUsername = myProfile?['username'] as String?;
          await SupabaseService().notifyMentions(
            actorId: SupabaseService().currentUser!.id,
            text: content,
            mentionedIn: myUsername != null
                ? '@$myUsername mentioned you in a comment'
                : 'mentioned you in a comment',
            contextData: {
              'actor_id': SupabaseService().currentUser!.id,
              'post_id': widget.postId,
              'parent_id': parentId,
            },
          );
        } catch (_) {
          // Mention notifications are non-fatal
        }

        _commentController.clear();
        if (parentId != null) {
          setState(() => _replyingTo = null);
          _replyControllers.remove(parentId)?.dispose();
        }
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
        final currentUserId = SupabaseService().currentUser!.id;
        final ownerId = _post!['user_id'] as String?;

        if (isLiked) {
          await SupabaseService().client
              .from('post_likes')
              .delete()
              .eq('post_id', widget.postId)
              .eq('user_id', currentUserId);
        } else {
          await SupabaseService().client.from('post_likes').insert({
            'post_id': widget.postId,
            'user_id': currentUserId,
            'created_at': DateTime.now().toIso8601String(),
          });

          // Notify the post owner (skip self-likes)
          if (ownerId != null && ownerId != currentUserId) {
            try {
              final myProfile = await SupabaseService().getProfile(currentUserId);
              final myUsername = myProfile?['username'] as String?;
              if (myUsername != null) {
                await SupabaseService().createNotification(
                  targetUserId: ownerId,
                  type: 'post_like',
                  title: '@$myUsername',
                  body: 'liked your post',
                  data: {'actor_id': currentUserId, 'post_id': widget.postId},
                );
              }
            } catch (_) {
              // Notification is best effort
            }
          }
        }

        setState(() {
          final likesCount = _post!['likes']?['count'] ?? 0;
          _post!['likes'] = {'count': isLiked ? likesCount - 1 : likesCount + 1};
          _post!['is_liked'] = !isLiked
              ? [
                  {'user_id': currentUserId}
                ]
              : [];
        });
      } catch (e) {
        setState(() {}); // Revert
      }
    }, actionName: 'like');
  }

  void _onSave() {
    AuthGuard.run(context, onAuthenticated: () async {
      final userId = SupabaseService().currentUser?.id;
      if (userId == null) return;

      try {
        if (_isSaved) {
          await SupabaseService().client
              .from(RippleConstants.tableSavedPosts)
              .delete()
              .eq('user_id', userId)
              .eq('post_id', widget.postId);
        } else {
          await SupabaseService().client.from(RippleConstants.tableSavedPosts).upsert({
            'user_id': userId,
            'post_id': widget.postId,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        if (mounted) {
          setState(() => _isSaved = !_isSaved);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isSaved ? 'Post saved' : 'Post unsaved'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update saved post'),
              backgroundColor: RippleColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }, actionName: 'save');
  }

  void _onShare() {
    AuthGuard.run(context, onAuthenticated: () {
      _shareOrCopy();
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
    return _topLevelComments.length +
        _repliesByParent.values.expand((r) => r).length;
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
            onPressed: () => _showPostOptions(),
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
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _showAllComments = !_showAllComments);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _showAllComments
                                  ? 'Hide comments'
                                  : 'View all $commentsCount comments',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: RippleColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _showAllComments
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 20,
                              color: RippleColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Comments section
          Container(
            height: _showAllComments
                ? MediaQuery.of(context).size.height * 0.65
                : 300,
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
                      : _topLevelComments.isEmpty
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
                              itemCount: _topLevelComments.length,
                              itemBuilder: (context, index) {
                                final comment = _topLevelComments[index];
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
              setState(() => _showAllComments = !_showAllComments);
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
              _isSaved ? 'assets/icons/bookmark_filled.svg' : 'assets/icons/bookmark.svg',
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

  bool get _isOwner {
    final currentUserId = SupabaseService().currentUser?.id;
    return currentUserId != null && _post?['user_id'] == currentUserId;
  }

  void _confirmDeletePost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RippleColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RippleConstants.borderRadiusLarge),
        ),
        title: const Text('Delete post?'),
        content: const Text(
          'This cannot be undone. Your likes, comments, and saves will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onDeletePost();
            },
            child: Text(
              'Delete',
              style: TextStyle(color: RippleColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDeletePost() async {
    AuthGuard.run(context, onAuthenticated: () async {
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null || _post == null) return;
      try {
        await SupabaseService().client
            .from(RippleConstants.tablePosts)
            .delete()
            .eq('id', widget.postId)
            .eq('user_id', currentUserId);

        // Best effort counter decrement
        try {
          await SupabaseService().client.rpc(
            'decrement_posts_count',
            params: {'user_id': currentUserId},
          );
        } catch (_) {
          // Counter is cosmetic
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted'), behavior: SnackBarBehavior.floating),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete post'),
              backgroundColor: RippleColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }, actionName: 'delete');
  }

  void _showPostOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: const BoxConstraints(maxHeight: 400),
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
                leading: SvgPicture.asset('assets/icons/link.svg', width: 24, height: 24),
                title: const Text('Copy link'),
                onTap: () {
                  Navigator.of(context).pop();
                  _shareOrCopy();
                },
              ),
              ListTile(
                leading: SvgPicture.asset('assets/icons/flag.svg', width: 24, height: 24),
                title: const Text('Report'),
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
                leading: SvgPicture.asset('assets/icons/bookmark.svg', width: 24, height: 24),
                title: const Text('Add to collection'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showAddToCollectionDialog(itemType: 'post');
                },
              ),
              if (_isOwner)
                ListTile(
                  leading: SvgPicture.asset(
                    'assets/icons/delete.svg',
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(RippleColors.error, BlendMode.srcIn),
                  ),
                  title: Text(
                    'Delete post',
                    style: TextStyle(color: RippleColors.error),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _confirmDeletePost();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Add to collection
  // ---------------------------------------------------------------------------

  void _showAddToCollectionDialog({required String itemType}) {
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
            const Text(
              'Save to collection',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: RippleColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (_collections.isEmpty) ...[
              const Text(
                'No collections yet. Create one from your profile.',
                style: TextStyle(
                  fontSize: 14,
                  color: RippleColors.textTertiary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.add,
                  color: RippleColors.primary,
                  size: 20,
                ),
                title: const Text('New Collection'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateCollectionDialog();
                },
              ),
            ] else ...[
              ..._collections.map((collection) {
                return ListTile(
                  leading: const Icon(
                    Icons.bookmark,
                    color: RippleColors.textSecondary,
                    size: 22,
                  ),
                  title: Text(
                    collection['name'] ?? 'Collection',
                    style: TextStyle(
                      color: RippleColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await SupabaseService().addToCollection(
                      collectionId: collection['id'] as String,
                      postId: itemType == 'post' ? widget.postId : null,
                      reelId: itemType == 'reel' ? widget.postId : null,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Saved to collection'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                );
              }).toList(),
              const Divider(color: RippleColors.divider),
              ListTile(
                leading: const Icon(
                  Icons.add,
                  color: RippleColors.primary,
                  size: 20,
                ),
                title: const Text('New Collection'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateCollectionDialog();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Show a create-collection dialog
  void _showCreateCollectionDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RippleColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RippleConstants.borderRadiusLarge),
        ),
        title: const Text('New Collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: RippleColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Collection name',
            hintStyle: TextStyle(color: RippleColors.textTertiary),
            border: const UnderlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              final id = await SupabaseService().createCollection(name);
              if (id != null && mounted) {
                setState(() {
                  _collections.insert(0, {
                    'id': id,
                    'name': name,
                    'user_id': SupabaseService().currentUser?.id,
                    'created_at': DateTime.now().toIso8601String(),
                  });
                });
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareOrCopy() async {
    final caption = _post?['caption'] as String?;
    final author = _post?['profiles'] is Map
        ? (_post?['profiles'] as Map)['username']
        : null;
    final text = author != null
        ? 'Check out this post by @$author on Ripple!'
        : 'Check out this post on Ripple!';
    await ShareSheet.show(
      context,
      link: 'ripple://post/${_post?['id'] ?? ''}',
      caption: caption,
      shareText: text,
    );
  }

  Widget _buildLikesCount(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          LikesListSheet.show(
            context,
            table: 'post_likes',
            idColumn: 'post_id',
            id: _post!['id'] as String,
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

  Widget _buildComment(Map<String, dynamic> comment, Map<String, dynamic>? profile,
      {bool isReply = false}) {
    final content = comment['content'] as String?;
    final createdAt = comment['created_at'] as String?;
    final commentId = comment['id'] as String?;
    final isReplyingToThis = _replyingTo == commentId;
    final replyController =
        _replyControllers[commentId ?? ''];

    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        left: isReply ? 56 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            final id = commentId;
                            if (id == null) return;
                            setState(() {
                              _replyingTo = id;
                              _replyControllers.putIfAbsent(id, () => TextEditingController());
                            });
                          },
                          child: Text(
                            'Reply',
                            style: TextStyle(
                              color: RippleColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            final id = commentId;
                            if (id == null) return;
                            _toggleCommentLike(id);
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                _commentLikeStatus[commentId ?? ''] == true
                                    ? 'assets/icons/heart_filled.svg'
                                    : 'assets/icons/heart.svg',
                                width: 16,
                                height: 16,
                                colorFilter: ColorFilter.mode(
                                  _commentLikeStatus[commentId ?? ''] == true
                                      ? RippleColors.error
                                      : RippleColors.textSecondary,
                                  BlendMode.srcIn,
                                ),
                              ),
                              if ((_commentLikeCounts[commentId ?? ''] ?? 0) > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '${_commentLikeCounts[commentId ?? ''] ?? 0}',
                                  style: TextStyle(
                                    color: RippleColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    _buildCommentContent(content ?? ''),
                  ],
                ),
              ),
            ],
          ),
          if (isReplyingToThis && commentId != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: RippleColors.surfaceVariant,
                borderRadius: BorderRadius.circular(RippleConstants.borderRadiusMedium),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: RippleColors.surfaceVariant,
                    backgroundImage: SupabaseService().currentUser?.userMetadata?['avatar_url'] != null
                        ? CachedNetworkImageProvider(
                            SupabaseService().currentUser!.userMetadata!['avatar_url'])
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: replyController,
                      style: const TextStyle(color: RippleColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Reply...',
                        hintStyle: TextStyle(color: RippleColors.textTertiary, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _addComment(parentId: commentId),
                    ),
                  ),
                  IconButton(
                    icon: SvgPicture.asset(
                      'assets/icons/send.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(RippleColors.primary, BlendMode.srcIn),
                    ),
                    onPressed: () => _addComment(parentId: commentId),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: RippleColors.textTertiary),
                    onPressed: () {
                      setState(() {
                        _replyControllers[commentId]?.dispose();
                        _replyControllers.remove(commentId);
                        _replyingTo = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
          // Nested replies
          if (commentId != null) ...[
            for (final reply in _repliesByParent[commentId] ?? [])
              _buildComment(
                reply,
                reply['profiles'] as Map<String, dynamic>?,
                isReply: true,
              ),
          ],
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

  /// Render comment content with @username mentions as tappable links.
  Widget _buildCommentContent(String content) {
    final mentionRegex = RegExp(r'@(\w[\w\.]*)');
    final matches = mentionRegex.allMatches(content);
    final spans = <TextSpan>[];
    var lastIndex = 0;

    for (final match in matches) {
      // Text before the mention
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: content.substring(lastIndex, match.start),
          style: Theme.of(context).textTheme.bodyMedium,
        ));
      }

      final username = match.group(1)!;
      spans.add(TextSpan(
        text: '@$username',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: RippleColors.primary,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            context.go('/user/$username');
          },
      ));

      lastIndex = match.end;
    }

    // Remaining text after the last mention
    if (lastIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastIndex),
        style: Theme.of(context).textTheme.bodyMedium,
      ));
    }

    if (spans.isEmpty) {
      return Text(
        content,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return RichText(
      text: TextSpan(children: spans),
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