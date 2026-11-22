import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/router.dart';
import '../../services/supabase_service.dart';
import '../../core/utils/auth_guard.dart';
import '../../presentation/components/story_ring.dart';
import '../../presentation/components/post_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _stories = [];
  bool _isLoadingPosts = false;
  bool _isLoadingStories = true;
  bool _hasMorePosts = true;
  int _postsPage = 0;
  static const int _postsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadStories(),
      _loadPosts(),
    ]);
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
          _stories = List<Map<String, dynamic>>.from(response);
          _isLoadingStories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStories = false);
      }
    }
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
      if (currentUserId == null) return;

      // Get posts from followed users + current user
      // For now, get all posts (in production, join with follows table)
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
            final likesCount = _posts[index]['likes']?['count'] ?? 0;
            _posts[index]['likes'] = {'count': currentlyLiked ? likesCount - 1 : likesCount + 1};
            _posts[index]['is_liked'] = !currentlyLiked;
          }
        });
      } catch (e) {
        // Revert on error
        setState(() {});
      }
    }, actionName: 'like');
  }
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
            final likesCount = _posts[index]['likes']?['count'] ?? 0;
            _posts[index]['likes'] = {'count': currentlyLiked ? likesCount - 1 : likesCount + 1};
            _posts[index]['is_liked'] = !currentlyLiked;
          }
        });
      } catch (e) {
        // Revert on error
        setState(() {});
      }
    });
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
    });
  }

  void _onSharePost(String postId) {
    AuthGuard.run(context, onAuthenticated: () {
      // TODO: Implement share functionality
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Share feature coming soon'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }, actionName: 'share');
  }
      // TODO: Implement share functionality
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Share feature coming soon'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
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
            else if (_stories.isNotEmpty)
              SliverToBoxAdapter(child: _buildStoriesBar())
            else
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      'No stories yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: RippleColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),

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
            fontFamily: 'Billabong',
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
            'assets/icons/heart.svg',
            width: 28,
            height: 28,
          ),
          onPressed: () {
            // TODO: Navigate to activity/likes screen
          },
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
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _stories.length + 1, // +1 for "Add Story"
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAddStoryButton();
          }
          final story = _stories[index - 1];
          final profile = story['profiles'] as Map<String, dynamic>?;
          return StoryRing(
            username: profile?['username'] ?? 'Unknown',
            displayName: profile?['display_name'] ?? 'Unknown',
            avatarUrl: profile?['avatar_url'],
            hasStory: true,
            isOwnStory: profile?['id'] == SupabaseService().currentUser?.id,
            onTap: () {
              // TODO: Navigate to story viewer
            },
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
        return StoryRing(
          username: 'Your Story',
          displayName: snapshot.data?['display_name'] ?? 'You',
          avatarUrl: avatarUrl,
          hasStory: false,
          isAddButton: true,
          onTap: () => context.go(RippleConstants.routeCreateStory),
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