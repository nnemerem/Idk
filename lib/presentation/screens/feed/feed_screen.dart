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
import 'package:ripple/presentation/components/share_sheet.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _posts = [];
  List<StoryUserGroup> _storyUsers = [];
  StoryUserGroup? _ownStoryUser;
  final Set<String> _viewedStoryIds = {};
  final Set<String> _savedPostIds = {};
  bool _isLoadingPosts = false;
  bool _isLoadingStories = true;
  bool _hasMorePosts = true;
  int _postsPage = 0;
  static const int _postsPerPage = 10;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadStories();
    _loadPosts();
    _loadSavedPosts();
    _loadUnreadNotifications();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _loadUnreadNotifications();
    _loadStories();
  }

  Future<void> _loadUnreadNotifications() async {
    final userId = SupabaseService().currentUser?.id;
    if (userId == null) return;

    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tableNotifications)
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      if (mounted) {
        setState(() => _unreadNotifications = (response as List).length);
      }
    } catch (e) {
      if (mounted) setState(() => _unreadNotifications = 0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStories() async {
    try {
      // Stories from followed users + current user (Instagram parity)
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null) return;

      final followsResponse = await SupabaseService().client
          .from(RippleConstants.tableFollows)
          .select('following_id')
          .eq('follower_id', currentUserId);

      final followedIds = (followsResponse as List)
          .map((row) => row['following_id'] as String?)
          .whereType<String>()
          .toSet();
      followedIds.add(currentUserId);

      final response = await SupabaseService().client
          .from(RippleConstants.tableStories)
          .select('''
            *,
            profiles:user_id (id, username, display_name, avatar_url)
          ''')
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      final filtered = (response as List)
          .where((story) => followedIds.contains(story['user_id']))
          .toList();

      await _loadStoryViews(currentUserId);

      if (mounted) {
        final storyUsers = _groupStoriesByUser(
          List<Map<String, dynamic>>.from(filtered),
        );
        final own = storyUsers.where((u) => u.userId == currentUserId).toList();
        _ownStoryUser = own.isNotEmpty ? own.first : null;
        _storyUsers = storyUsers.where((u) => u.userId != currentUserId).toList();
        setState(() {
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
  Future<void> _loadStoryViews(String userId) async {
    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tableStoryViews)
          .select('story_id')
          .eq('user_id', userId);

      final ids = (response as List)
          .map((row) => row['story_id'] as String?)
          .whereType<String>()
          .toSet();
      if (mounted) {
        setState(() => _viewedStoryIds.addAll(ids));
      }
    } catch (_) {
      // Best effort — viewed dimming is cosmetic
    }
  }

  Future<void> _persistViewed(String storyId, String userId) async {
    try {
      await SupabaseService().client.from(RippleConstants.tableStoryViews).insert({
        'user_id': userId,
        'story_id': storyId,
        'viewed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Duplicate rows are expected for already-viewed stories; ignore.
    }
  }

  void _onStoryShown(Map<String, dynamic> story, String ownerId) {
    final currentUserId = SupabaseService().currentUser?.id;
    if (currentUserId == null) return;
    if (ownerId == currentUserId) return; // don't mark own stories as viewed
    final storyId = story['id'] as String?;
    if (storyId == null) return;
    if (_viewedStoryIds.contains(storyId)) return;
    setState(() => _viewedStoryIds.add(storyId));
    _persistViewed(storyId, currentUserId);
  }

  void _hideStoryUser(String userId) {
    setState(() {
      _storyUsers = _storyUsers.where((u) => u.userId != userId).toList();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchUserStories(String userId) async {
    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tableStories)
          .select('''
            *,
            profiles:user_id (id, username, display_name, avatar_url)
          ''')
          .eq('user_id', userId)
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: true);
      if (response is List && response.isNotEmpty) {
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (_) {
      // Fall back to the feed-loaded stories
    }
    return [];
  }

  List<StoryUserGroup> _groupStoriesByUser(List<Map<String, dynamic>> stories) {
    final byUser = <String, List<Map<String, dynamic>>>{};
    for (final story in stories) {
      final userId = story['user_id'] as String?;
      if (userId == null) continue;
      byUser.putIfAbsent(userId, () => []).add(story);
    }

    final users = <StoryUserGroup>[];
    byUser.forEach((userId, userStories) {
      final profile = userStories.first['profiles'] as Map<String, dynamic>?;
      users.add(StoryUserGroup(
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
        final currentUserId = SupabaseService().currentUser!.id;
        final postIndex = _posts.indexWhere((p) => p['id'] == postId);
        final post = postIndex != -1 ? _posts[postIndex] : null;
        final ownerId = post?['user_id'] as String?;

        if (currentlyLiked) {
          await SupabaseService().client
              .from('post_likes')
              .delete()
              .eq('post_id', postId)
              .eq('user_id', currentUserId);
        } else {
          await SupabaseService().client.from('post_likes').insert({
            'post_id': postId,
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
                  data: {'actor_id': currentUserId, 'post_id': postId},
                );
              }
            } catch (_) {
              // Notification is best effort
            }
          }
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

  Future<void> _loadSavedPosts() async {
    final userId = SupabaseService().currentUser?.id;
    if (userId == null) return;

    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tableSavedPosts)
          .select('post_id')
          .eq('user_id', userId);

      if (mounted) {
        setState(() {
          _savedPostIds.addAll(
            (response as List)
                .map((row) => row['post_id'] as String?)
                .whereType<String>(),
          );
        });
      }
    } catch (e) {
      // Saved-posts state is best effort; the UI keeps working
    }
  }

  void _onSavePost(String postId) {
    AuthGuard.run(context, onAuthenticated: () async {
      final userId = SupabaseService().currentUser?.id;
      if (userId == null) return;

      final isSaved = _savedPostIds.contains(postId);
      try {
        if (isSaved) {
          await SupabaseService().client
              .from(RippleConstants.tableSavedPosts)
              .delete()
              .eq('user_id', userId)
              .eq('post_id', postId);
        } else {
          await SupabaseService().client.from(RippleConstants.tableSavedPosts).upsert({
            'user_id': userId,
            'post_id': postId,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        if (mounted) {
          setState(() {
            if (isSaved) {
              _savedPostIds.remove(postId);
            } else {
              _savedPostIds.add(postId);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isSaved ? 'Post unsaved' : 'Post saved'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
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

      ShareSheet.show(
        context,
        link: 'ripple://post/$postId',
        caption: caption,
        shareText: text,
      );
    }, actionName: 'share');
  }

  Future<void> _openStoryViewer(StoryUserGroup storyUser) async {
    // Fresh stories for the tapped user so the viewer is current
    var fresh = await _fetchUserStories(storyUser.userId);
    if (fresh.isEmpty) {
      fresh = List<Map<String, dynamic>>.from(storyUser.stories);
    }

    // Build the browsing groups: own group first (Instagram parity), then the rest.
    final groups = <StoryUserGroup>[];
    if (_ownStoryUser != null) {
      final ownStories = _ownStoryUser!.userId == storyUser.userId && fresh.isNotEmpty
          ? fresh
          : _ownStoryUser!.stories;
      if (ownStories.isNotEmpty) {
        groups.add(StoryUserGroup(
          userId: _ownStoryUser!.userId,
          profile: _ownStoryUser!.profile,
          stories: ownStories,
        ));
      }
    }
    for (final u in _storyUsers) {
      final stories = u.userId == storyUser.userId ? fresh : u.stories;
      if (stories.isEmpty) continue;
      groups.add(StoryUserGroup(userId: u.userId, profile: u.profile, stories: stories));
    }

    if (groups.isEmpty || !mounted) return;

    // Sort stories chronologically (oldest first) within every group
    final sortedGroups = <StoryUserGroup>[];
    for (final g in groups) {
      final sorted = List<Map<String, dynamic>>.from(g.stories)
        ..sort((a, b) {
          final ac = (a['created_at'] as String?) ?? '';
          final bc = (b['created_at'] as String?) ?? '';
          return ac.compareTo(bc);
        });
      sortedGroups.add(StoryUserGroup(
        userId: g.userId,
        profile: g.profile,
        stories: sorted,
      ));
    }

    // Resolve the flat starting index for the tapped user
    int start = 0;
    int targetStart = 0;
    for (var i = 0; i < sortedGroups.length; i++) {
      if (sortedGroups[i].userId == storyUser.userId) {
        targetStart = start;
        break;
      }
      start += sortedGroups[i].stories.length;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryViewer(
          groups: sortedGroups,
          initialIndex: targetStart,
          currentUserId: SupabaseService().currentUser?.id,
          onStoryShown: _onStoryShown,
          onHideGroup: (userId) {
            _hideStoryUser(userId);
            Navigator.of(context).pop();
          },
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
                          isSaved: _savedPostIds.contains(_posts[index]['id'] as String?),
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
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: SvgPicture.asset(
                'assets/icons/notification.svg',
                width: 28,
                height: 28,
              ),
              tooltip: 'Notifications',
              onPressed: () => context.go(RippleConstants.routeNotifications),
            ),
            if (_unreadNotifications > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: RippleColors.error,
                    borderRadius: BorderRadius.circular(RippleConstants.borderRadiusFull),
                  ),
                  child: Text(
                    _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
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
        itemCount: _storyUsers.length + 1, // +1 for own ring (add button or own story)
        itemBuilder: (context, index) {
          if (index == 0) {
            // Own ring: show the real own-story ring when you have stories,
            // otherwise the add-story button (Instagram parity).
            if (_ownStoryUser != null) {
              final ownProfile = _ownStoryUser!.profile;
              return StoryRing(
                username: ownProfile?['username'] ?? 'Your Story',
                displayName: ownProfile?['display_name'] ?? 'You',
                avatarUrl: ownProfile?['avatar_url'],
                hasStory: true,
                isOwnStory: true,
                isViewed: false,
                onTap: () => _openStoryViewer(_ownStoryUser!),
              );
            }
            return _buildAddStoryButton();
          }
          final storyUser = _storyUsers[index - 1];
          final profile = storyUser.profile;
          final isViewed = storyUser.stories.every(
            (s) => _viewedStoryIds.contains(s['id'] as String?),
          );
          return StoryRing(
            username: profile?['username'] ?? 'Unknown',
            displayName: profile?['display_name'] ?? 'Unknown',
            avatarUrl: profile?['avatar_url'],
            hasStory: true,
            isOwnStory: storyUser.userId == currentUserId,
            isViewed: isViewed,
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

