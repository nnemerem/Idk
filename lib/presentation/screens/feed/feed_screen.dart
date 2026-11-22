import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/config/router.dart';
import 'package:ripple/services/supabase_service.dart';
import 'package:ripple/core/utils/auth_guard.dart';
import 'package:ripple/core/utils/guest_mode.dart';
import 'package:ripple/presentation/components/story_ring.dart';
import 'package:ripple/presentation/components/post_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _posts = [];
  List<_StoryUser> _storyUsers = [];
  bool _isLoadingPosts = false;
  bool _isLoadingStories = true;
  bool _hasMorePosts = true;
  int _postsPage = 0;
  static const int _postsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadStories();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStories() async {
    try {
      // Get stories from followed users + current user
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null) return;

      // For now, get recent stories from all users (in production, filter by follows)
      final response = await SupabaseService().client
          .from(RippleConstants.tableStories)
          .select('''
            *,
            profiles:user_id (id, username, display_name, avatar_url)
          ''')
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _storyUsers = _groupStoriesByUser(
            List<Map<String, dynamic>>.from(response),
          );
          _isLoadingStories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStories = false);
      }
    }
  }

  /// Group stories by the person who owns them (one ring per user).
  List<_StoryUser> _groupStoriesByUser(List<Map<String, dynamic>> stories) {
    final byUser = <String, List<Map<String, dynamic>>>{};
    for (final story in stories) {
      final userId = story['user_id'] as String?;
      if (userId == null) continue;
      byUser.putIfAbsent(userId, () => []).add(story);
    }

    final users = <_StoryUser>[];
    byUser.forEach((userId, userStories) {
      final profile = userStories.first['profiles'] as Map<String, dynamic>?;
      users.add(_StoryUser(
        userId: userId,
        profile: profile,
        stories: userStories,
      ));
    });
    return users;
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_isLoadingPosts) return;

    setState(() => _isLoadingPosts = true);

    if (refresh) {
      _postsPage = 0;
      _hasMorePosts = true;
    }

    try {
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null) {
        if (mounted) setState(() => _isLoadingPosts = false);
        return;
      }

      final response = await SupabaseService().client
          .from(RippleConstants.tablePosts)
          .select('''
            *,
            profiles:user_id (id, username, display_name, avatar_url),
            likes:post_likes (count),
            comments:post_comments (count),
            is_liked:post_likes!inner (user_id)
          ''')
          .order('created_at', ascending: false)
          .range(_postsPage * _postsPerPage, (_postsPage + 1) * _postsPerPage - 1);

      final newPosts = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          if (refresh) {
            _posts = newPosts;
          } else {
            _posts.addAll(newPosts);
          }
          _hasMorePosts = newPosts.length >= _postsPerPage;
          _postsPage++;
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPosts = false);
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadPosts();
    }
  }

  Future<void> _onRefresh() async {
    await _loadPosts(refresh: true);
    await _loadStories();
  }

  void _onLikePost(String postId, bool currentlyLiked) {
    AuthGuard.run(context, onAuthenticated: () async {
      try {
        if (currentlyLiked) {
          await SupabaseService().client
              .from('post_likes')
              .delete()
              .eq('post_id', postId)
              .eq('user_id', SupabaseService().currentUser!.id);
        } else {
          await SupabaseService().client.from('post_likes').insert({
            'post_id': postId,
            'user_id': SupabaseService().currentUser!.id,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        // Optimistic update
        setState(() {
          final index = _posts.indexWhere((p) => p['id'] == postId);
          if (index != -1) {
            final likes = _posts[index]['likes'];
            final count = (likes is Map ? (likes['count'] as int? ?? 0) : 0);
            _posts[index]['likes'] = {'count': currentlyLiked ? count - 1 : count + 1};
            _posts[index]['is_liked'] = currentlyLiked
                ? <Map<String, dynamic>>[]
                : [
                    {'user_id': SupabaseService().currentUser!.id}
                  ];
          }
        });
      } catch (e) {
        if (mounted) {
          setState(() {});
        }
      }
    }, actionName: 'like');
  }

  void _onSavePost(String postId) {
    AuthGuard.run(context, onAuthenticated: () async {
      try {
        await SupabaseService().client.from(RippleConstants.tableSavedPosts).upsert({
          'user_id': SupabaseService().currentUser!.id,
          'post_id': postId,
          'created_at': DateTime.now().toIso8601String(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post saved'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save post'),
              backgroundColor: RippleColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }, actionName: 'save');
  }

  void _onSharePost(String postId) {
    AuthGuard.run(context, onAuthenticated: () {
      final post = _posts.firstWhere(
        (p) => p['id'] == postId,
        orElse: () => <String, dynamic>{},
      );
      final author = post['profiles'] is Map ? (post['profiles'] as Map)['username'] : null;
      final caption = post['caption'] as String?;
      final text = author != null
          ? 'Check out this post by @$author on Ripple!'
          : 'Check out this post on Ripple!';

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _ShareSheet(
          postId: postId,
          caption: caption,
          shareText: text,
        ),
      );
    }, actionName: 'share');
  }

  Future<void> _openStoryViewer(_StoryUser storyUser) async {
    // Re-fetch fresh stories for this user so the viewer has current data
    List<Map<String, dynamic>> stories = List<Map<String, dynamic>>.from(storyUser.stories);
    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tableStories)
          .select('''
            *,
            profiles:user_id (id, username, display_name, avatar_url)
          ''')
          .eq('user_id', storyUser.userId)
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: true);
      if (response is List && response.isNotEmpty) {
        stories = List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      // Fall back to the already-loaded stories
    }

    if (stories.isEmpty || !mounted) return;
    if (GuestMode.isGuestMode) {
      // Guests can view stories (view-only)
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryViewer(
          stories: stories,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RippleColors.background,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: RippleColors.primary,
        backgroundColor: RippleColors.surface,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Stories bar
            if (_isLoadingStories)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: 8,
                    itemBuilder: (context, index) => _buildStorySkeleton(),
                  ),
                ),
              )
            else if (_storyUsers.isNotEmpty)
              SliverToBoxAdapter(child: _buildStoriesBar()),

            // Posts feed
            _posts.isEmpty && !_isLoadingPosts
                ? SliverFillRemaining(
                    child: _buildEmptyState(),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == _posts.length) {
                          return _isLoadingPosts
                              ? _buildLoadingPost()
                              : _hasMorePosts
                                  ? const SizedBox.shrink()
                                  : _buildEndOfFeed();
                        }
                        return PostCard(
                          post: _posts[index],
                          onLike: _onLikePost,
                          onSave: _onSavePost,
                          onShare: _onSharePost,
                          onTap: () => context.go(
                            '${RippleConstants.routeFeed}/post/${_posts[index]['id']}',
                          ),
                        );
                      },
                      childCount: _posts.length + (_hasMorePosts ? 1 : 0),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: RippleColors.brandGradient,
        ).createShader(bounds),
        child: const Text(
          RippleConstants.appName,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: SvgPicture.asset(
            'assets/icons/notification.svg',
            width: 28,
            height: 28,
          ),
          tooltip: 'Notifications',
          onPressed: () => context.go(RippleConstants.routeNotifications),
        ),
        IconButton(
          icon: SvgPicture.asset(
            'assets/icons/video.svg',
            width: 28,
            height: 28,
          ),
          tooltip: 'Reels',
          onPressed: () => context.go(RippleConstants.routeReels),
        ),
        IconButton(
          icon: SvgPicture.asset(
            'assets/icons/send.svg',
            width: 28,
            height: 28,
          ),
          onPressed: () => context.go(RippleConstants.routeDms),
        ),
      ],
    );
  }

  Widget _buildStoriesBar() {
    final currentUserId = SupabaseService().currentUser?.id;
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _storyUsers.length + 1, // +1 for "Add Story"
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAddStoryButton();
          }
          final storyUser = _storyUsers[index - 1];
          final profile = storyUser.profile;
          return StoryRing(
            username: profile?['username'] ?? 'Unknown',
            displayName: profile?['display_name'] ?? 'Unknown',
            avatarUrl: profile?['avatar_url'],
            hasStory: true,
            isOwnStory: storyUser.userId == currentUserId,
            onTap: () => _openStoryViewer(storyUser),
          );
        },
      ),
    );
  }

  Widget _buildAddStoryButton() {
    final currentUser = SupabaseService().currentUser;
    final profile = currentUser != null
        ? SupabaseService().getProfile(currentUser.id)
        : null;

    return FutureBuilder<Map<String, dynamic>?>(
      future: profile,
      builder: (context, snapshot) {
        final avatarUrl = snapshot.data?['avatar_url'];
        final isGuest = GuestMode.isGuestMode;
        return StoryRing(
          username: 'Your Story',
          displayName: snapshot.data?['display_name'] ?? 'You',
          avatarUrl: avatarUrl,
          hasStory: false,
          isAddButton: true,
          onTap: () {
            if (isGuest) {
              AuthGuard.run(context, onAuthenticated: () {}, actionName: 'create_story');
              return;
            }
            context.go(RippleConstants.routeCreateStory);
          },
        );
      },
    );
  }

  Widget _buildStorySkeleton() {
    return Container(
      width: 68,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: RippleColors.surfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: RippleColors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: RippleColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/icons/photo_library.svg',
                width: 40,
                height: 40,
                colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No posts yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: RippleColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow people to see their posts here',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: RippleColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go(RippleConstants.routeExplore),
              icon: SvgPicture.asset('assets/icons/search.svg', width: 20, height: 20),
              label: const Text('Explore People'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPost() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Header skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: RippleColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100,
                      height: 14,
                      decoration: BoxDecoration(
                        color: RippleColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 60,
                      height: 12,
                      decoration: BoxDecoration(
                        color: RippleColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Image skeleton
          Container(
            color: RippleColors.surfaceVariant,
            height: MediaQuery.of(context).size.width,
          ),
          // Actions skeleton
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: List.generate(4, (index) => Expanded(
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: RippleColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )),
            ),
          ),
          // Caption skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(3, (index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: RippleColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndOfFeed() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          'You\'re all caught up!',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: RippleColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _StoryUser {
  final String userId;
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> stories;

  const _StoryUser({
    required this.userId,
    required this.profile,
    required this.stories,
  });
}

/// Bottom sheet with the share link + native share button.
class _ShareSheet extends StatelessWidget {
  final String postId;
  final String? caption;
  final String shareText;

  const _ShareSheet({
    required this.postId,
    required this.caption,
    required this.shareText,
  });

  @override
  Widget build(BuildContext context) {
    final link = 'ripple://post/$postId';
    return Container(
      decoration: BoxDecoration(
        color: RippleColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RippleConstants.borderRadiusXLarge),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: RippleColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Share Post',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (caption != null && caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                caption!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: RippleColors.textSecondary,
                ),
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: RippleColors.surfaceVariant,
              borderRadius: BorderRadius.circular(RippleConstants.borderRadiusMedium),
            ),
            child: Text(
              link,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: RippleColors.textTertiary,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share link copied')),
                    );
                  },
                  child: const Text('Copy Link'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post shared')),
                    );
                  },
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
