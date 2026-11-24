import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/config/router.dart';
import 'package:ripple/services/supabase_service.dart';
import 'package:ripple/core/utils/guest_mode.dart';
import 'package:ripple/core/utils/auth_guard.dart';
import 'package:ripple/presentation/components/followers_list_sheet.dart';
import 'package:ripple/presentation/components/update_banner.dart';
import 'package:ripple/presentation/components/share_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _reels = [];
  List<Map<String, dynamic>> _savedPosts = [];
  List<Map<String, dynamic>> _likedPosts = [];
  List<Map<String, dynamic>> _collections = [];
  String? _selectedCollectionId; // null = view all saved items
  Map<String, List<Map<String, dynamic>>> _collectionItems = {};
  bool _isLoading = true;
  int _postsCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _loadProfile();
    _loadSavedPosts();
    _loadLikedPosts();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null) return;

      final profile = await SupabaseService().getProfile(currentUserId);
      final followersCount = await SupabaseService().getFollowersCount(currentUserId);
      final followingCount = await SupabaseService().getFollowingCount(currentUserId);

      if (mounted) {
        setState(() {
          _profile = profile;
          _followersCount = followersCount;
          _followingCount = followingCount;
          _postsCount = profile?['posts_count'] as int? ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadProfile(),
      _loadPosts(),
      _loadReels(),
      _loadSavedPosts(),
      _loadLikedPosts(),
      _loadCollections(),
    ]);
  }

  Future<void> _loadPosts() async {
    try {
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null) return;

      final response = await SupabaseService().client
          .from(RippleConstants.tablePosts)
          .select()
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _loadReels() async {
    try {
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null) return;

      final response = await SupabaseService().client
          .from(RippleConstants.tableReels)
          .select()
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _reels = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _loadSavedPosts() async {
    try {
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null) return;

      final postResponse = await SupabaseService().client
          .from(RippleConstants.tableSavedPosts)
          .select('post_id, posts:posts(*)')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      final savedPosts = (postResponse as List)
          .where((row) => row['posts'] != null)
          .map((row) => row['posts'] as Map<String, dynamic>)
          .toList();

      final reelResponse = await SupabaseService().client
          .from(RippleConstants.tableSavedPosts)
          .select('reel_id, reels:reels(*)')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      final savedReels = (reelResponse as List)
          .where((row) => row['reels'] != null)
          .map((row) => {...(row['reels'] as Map<String, dynamic>), '_isReel': true})
          .toList();

      if (mounted) {
        setState(() {
          _savedPosts = [...savedPosts, ...savedReels];
        });
      }
    } catch (e) {
      // Ignore — saved list is non-critical
    }
  }

  // ---------------------------------------------------------------------------
  // Saved collections
  // ---------------------------------------------------------------------------

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

  /// Open (or close) a specific collection. null = view all saved items.
  void _selectCollection(String? collectionId) {
    setState(() => _selectedCollectionId = collectionId);
    if (collectionId != null) {
      _loadCollectionItems(collectionId);
    } else {
      _collectionItems.remove(collectionId);
    }
  }

  /// Load items inside a specific collection.
  Future<void> _loadCollectionItems(String collectionId) async {
    try {
      final items = await SupabaseService().getCollectionItems(collectionId);
      if (mounted) {
        setState(() {
          _collectionItems[collectionId] =
              List<Map<String, dynamic>>.from(items);
        });
      }
    } catch (e) {
      // Non-critical
    }
  }

  /// Show a dialog to create a new saved collection.
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
                  _selectCollection(id);
                });
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadLikedPosts() async {
    try {
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null) return;

      final postResponse = await SupabaseService().client
          .from('post_likes')
          .select('post_id, posts:posts(*)')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      final likedPosts = (postResponse as List)
          .where((row) => row['posts'] != null)
          .map((row) => row['posts'] as Map<String, dynamic>)
          .toList();

      final reelResponse = await SupabaseService().client
          .from('reel_likes')
          .select('reel_id, reels:reels(*)')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      final likedReels = (reelResponse as List)
          .where((row) => row['reels'] != null)
          .map((row) => {...(row['reels'] as Map<String, dynamic>), '_isReel': true})
          .toList();

      if (mounted) {
        setState(() {
          _likedPosts = [...likedPosts, ...likedReels];
        });
      }
    } catch (e) {
      // Ignore — liked list is non-critical
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = GuestMode.isGuestMode;
    return Scaffold(
      backgroundColor: RippleColors.background,
      appBar: AppBar(
        title: _profile != null
            ? Row(
                children: [
                  Text(
                    _profile!['username'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (isGuest) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: RippleColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(RippleConstants.borderRadiusFull),
                      ),
                      child: Text(
                        'Guest',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: RippleColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              )
            : const Text('Profile'),
        actions: [
          if (!isGuest)
            IconButton(
              icon: SvgPicture.asset(
                'assets/icons/plus_circle.svg',
                width: 26,
                height: 26,
              ),
              onPressed: () => context.go(RippleConstants.routeCreatePost),
            ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/menu.svg',
              width: 26,
              height: 26,
            ),
            onPressed: () => _showMenuOptions(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: RippleColors.primary))
          : RefreshIndicator(
              onRefresh: _loadAll,
              color: RippleColors.primary,
              backgroundColor: RippleColors.surface,
              child: CustomScrollView(
                slivers: [
                  // Update banner (if a newer release is published)
                  const SliverToBoxAdapter(child: UpdateBanner()),

                  // Profile header
                  SliverToBoxAdapter(child: _buildProfileHeader()),

                  // Stats
                  SliverToBoxAdapter(child: _buildStats()),

                  // Bio
                  SliverToBoxAdapter(child: _buildBio()),

                  // Edit profile button
                  SliverToBoxAdapter(child: _buildActionButtons()),

                  // Tab bar
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverTabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        indicatorColor: RippleColors.primary,
                        indicatorWeight: 3,
                        labelColor: RippleColors.textPrimary,
                        unselectedLabelColor: RippleColors.textSecondary,
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: [
                          Tab(icon: SvgPicture.asset('assets/icons/grid_on.svg', width: 24, height: 24)),
                          Tab(icon: SvgPicture.asset('assets/icons/video_library.svg', width: 24, height: 24)),
                          Tab(icon: SvgPicture.asset('assets/icons/bookmark.svg', width: 24, height: 24)),
                          Tab(icon: SvgPicture.asset('assets/icons/heart.svg', width: 24, height: 24)),
                        ],
                      ),
                    ),
                  ),

                  // Tab content
                  TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPostsGrid(),
                      _buildReelsGrid(),
                      _buildSavedGrid(),
                      _buildLikedGrid(),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: RippleConstants.avatarSizeLarge / 2,
            backgroundColor: RippleColors.surfaceVariant,
            backgroundImage: _profile?['avatar_url'] != null
                ? CachedNetworkImageProvider(_profile!['avatar_url'])
                : null,
            child: _profile?['avatar_url'] == null
                ? Text(
                    _profile?['username']?[0]?.toUpperCase() ?? '?',
                    style: const TextStyle(
                      color: RippleColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 32,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _StatItem(
            count: _postsCount,
            label: 'Posts',
            onTap: () => _tabController.animateTo(0),
          ),
          _StatItem(
            count: _followersCount,
            label: 'Followers',
            onTap: () {
              final id = SupabaseService().currentUser?.id;
              if (id != null) {
                FollowersListSheet.show(context, profileId: id, isFollowers: true);
              }
            },
          ),
          _StatItem(
            count: _followingCount,
            label: 'Following',
            onTap: () {
              final id = SupabaseService().currentUser?.id;
              if (id != null) {
                FollowersListSheet.show(context, profileId: id, isFollowers: false);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBio() {
    if (_profile == null) return const SizedBox.shrink();

    final displayName = _profile!['display_name'] as String?;
    final bio = _profile!['bio'] as String?;
    final website = _profile!['website'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (displayName != null && displayName.isNotEmpty)
            Text(
              displayName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              bio,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (website != null && website.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              website,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: RippleColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.go(RippleConstants.routeEditProfile),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RippleConstants.borderRadiusFull),
                ),
              ),
              child: const Text('Edit Profile'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.go(RippleConstants.routeSettings),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RippleConstants.borderRadiusFull),
                ),
              ),
              child: const Text('Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikedGrid() {
    if (_likedPosts.isNotEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1,
        ),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _likedPosts.length,
        itemBuilder: (context, index) {
          final item = _likedPosts[index];
          if (item['_isReel'] == true) {
            return _buildReelGridItem(item);
          }
          return _buildGridItem(item);
        },
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/heart.svg',
            width: 64,
            height: 64,
            colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
          ),
          const SizedBox(height: 16),
          Text(
            'Nothing liked yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: RippleColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Posts you like will appear here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RippleColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGridItem(Map<String, dynamic> item, {bool isReel = false}) {
    final isOwner = item['user_id'] == SupabaseService().currentUser?.id;
    if (!isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only your own items can be deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RippleColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RippleConstants.borderRadiusLarge),
        ),
        title: Text(isReel ? 'Delete reel?' : 'Delete post?'),
        content: const Text(
          'This cannot be undone. Likes, comments, and saves will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onDeleteGridItem(item, isReel: isReel);
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

  Future<void> _onDeleteGridItem(Map<String, dynamic> item, {bool isReel = false}) async {
    AuthGuard.run(context, onAuthenticated: () async {
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null) return;
      try {
        await SupabaseService().client
            .from(isReel ? RippleConstants.tableReels : RippleConstants.tablePosts)
            .delete()
            .eq('id', item['id'] as String)
            .eq('user_id', currentUserId);

        if (!isReel) {
          try {
            await SupabaseService().client.rpc(
              'decrement_posts_count',
              params: {'user_id': currentUserId},
            );
          } catch (_) {
            // Counter is cosmetic
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isReel ? 'Reel deleted' : 'Post deleted'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadAll();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete item'),
              backgroundColor: RippleColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }, actionName: 'delete');
  }

  Widget _buildPostsGrid() {
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/photo_library.svg',
              width: 64,
              height: 64,
              colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
            ),
            const SizedBox(height: 16),
            Text(
              'No posts yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: RippleColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you share posts, they\'ll appear here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: RippleColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.go(RippleConstants.routeCreatePost),
              icon: SvgPicture.asset('assets/icons/photo_library.svg', width: 20, height: 20),
              label: const Text('Create Post'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _posts.length,
      itemBuilder: (context, index) => _buildGridItem(_posts[index]),
    );
  }

  Widget _buildReelsGrid() {
    if (_reels.isNotEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1,
        ),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _reels.length,
        itemBuilder: (context, index) => _buildReelGridItem(_reels[index]),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/video_library.svg',
            width: 64,
            height: 64,
            colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
          ),
          const SizedBox(height: 16),
          Text(
            'No Reels yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: RippleColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you create Reels, they\'ll appear here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RippleColors.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.go(RippleConstants.routeCreateReel),
            icon: SvgPicture.asset('assets/icons/video.svg', width: 20, height: 20),
            label: const Text('Create Reel'),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedGrid() {
    final currentUserId = SupabaseService().currentUser?.id;
    final isGuest = GuestMode.isGuestMode;

    if (isGuest) {
      return _buildGuestSavedEmpty();
    }

    // Items for the currently selected collection (or all saved)
    final itemsForCollection = _selectedCollectionId == null
        ? _savedPosts
        : (_collectionItems[_selectedCollectionId] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collections selector row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'Collections',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.add,
                  size: 20,
                  color: RippleColors.primary,
                ),
                onPressed: _showCreateCollectionDialog,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'New collection',
              ),
            ],
          ),
        ),
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _collections.length + 1,
            itemBuilder: (context, index) {
              final isAll = index == 0;
              final collection = isAll
                  ? null
                  : _collections[index - 1];
              final isSelected = _selectedCollectionId ==
                  (isAll ? null : collection!['id']);
              return GestureDetector(
                onTap: () => _selectCollection(isAll ? null : collection!['id']),
                child: Container(
                  margin: index == 0
                      ? const EdgeInsets.only(left: 16, right: 8)
                      : const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? RippleColors.primary.withValues(alpha: 0.15)
                        : RippleColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? Border.all(color: RippleColors.primary, width: 1.5)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isSelected)
                        Icon(
                          Icons.bookmark_border,
                          size: 16,
                          color: isSelected
                              ? RippleColors.primary
                              : RippleColors.textSecondary,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        isAll ? 'All Saved' : (collection!['name'] ?? 'Collection'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? RippleColors.primary
                              : RippleColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Items grid
        Expanded(
          child: itemsForCollection.isEmpty
              ? _buildSavedEmpty(collectionName: _selectedCollectionId == null
                  ? null
                  : _collections
                      .firstWhere((c) => c['id'] == _selectedCollectionId, orElse: () => {})['name'])
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: 1,
                  ),
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: itemsForCollection.length,
                  itemBuilder: (context, index) {
                    final item = itemsForCollection[index];
                    if (item['_isReel'] == true) {
                      return _buildReelGridItem(item);
                    }
                    return _buildGridItem(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGuestSavedEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/bookmark.svg',
            width: 64,
            height: 64,
            colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
          ),
          const SizedBox(height: 16),
          Text(
            'Sign in to save',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: RippleColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Posts and Reels you save will appear here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RippleColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedEmpty({String? collectionName}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/bookmark.svg',
            width: 64,
            height: 64,
            colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
          ),
          const SizedBox(height: 16),
          Text(
            collectionName != null
                ? 'No items in "$collectionName"'
                : 'No saved items',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: RippleColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            collectionName != null
                ? 'Save posts and Reels to this collection.'
                : 'Posts and Reels you save will appear here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RippleColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(Map<String, dynamic> post) {
    final mediaUrls = _getMediaUrls(post);
    if (mediaUrls.isEmpty) return const SizedBox.shrink();

    final mediaUrl = mediaUrls.first;
    final isVideo = post['media']?.firstWhere(
      (m) => m['url'] == mediaUrl,
      orElse: () => <String, dynamic>{},
    )['type'] == 'video';

    return GestureDetector(
      onTap: () => context.go('${RippleConstants.routeFeed}/post/${post['id']}'),
      onLongPress: () => _confirmDeleteGridItem(post),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: mediaUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: RippleColors.surfaceVariant,
              child: Center(
                child: CircularProgressIndicator(
                  color: RippleColors.primary,
                  strokeWidth: 1.5,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: RippleColors.surfaceVariant,
              child: SvgPicture.asset(
                'assets/icons/photo_library.svg',
                width: 32,
                height: 32,
                colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
              ),
            ),
          ),
          if (isVideo)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SvgPicture.asset(
                  'assets/icons/play.svg',
                  width: 14,
                  height: 14,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReelGridItem(Map<String, dynamic> reel) {
    final thumb = reel['thumbnail_url'] as String? ?? reel['video_url'] as String?;
    if (thumb == null || thumb.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.go('${RippleConstants.routeReels}/reel/${reel['id']}'),
      onLongPress: () => _confirmDeleteGridItem(reel, isReel: true),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: thumb,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: RippleColors.surfaceVariant,
              child: Center(
                child: CircularProgressIndicator(
                  color: RippleColors.primary,
                  strokeWidth: 1.5,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: RippleColors.surfaceVariant,
              child: SvgPicture.asset(
                'assets/icons/video_library.svg',
                width: 32,
                height: 32,
                colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SvgPicture.asset(
                'assets/icons/play.svg',
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getMediaUrls(Map<String, dynamic> post) {
    final media = post['media'] as List<dynamic>?;
    if (media == null) return [];

    return media
        .where((m) => m['url'] != null && m['url'].toString().isNotEmpty)
        .map((m) => m['url'] as String)
        .toList();
  }

  void _showMenuOptions() {
    final isGuest = GuestMode.isGuestMode;
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
            if (isGuest)
              ListTile(
                leading: SvgPicture.asset('assets/icons/person_add.svg', width: 24, height: 24),
                title: const Text('Switch to Real Account'),
                onTap: () {
                  Navigator.pop(context);
                  GuestMode.exitGuestMode(context);
                },
              ),
            if (!isGuest)
              ListTile(
                leading: SvgPicture.asset('assets/icons/settings.svg', width: 24, height: 24),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  context.go(RippleConstants.routeSettings);
                },
              ),
            ListTile(
              leading: SvgPicture.asset('assets/icons/send.svg', width: 24, height: 24),
              title: const Text('Share Profile'),
              onTap: () {
                Navigator.pop(context);
                final username = _profile?['username'] as String?;
                if (username == null || username.isEmpty) return;
                ShareSheet.show(
                  context,
                  link: 'ripple://user/$username',
                  shareText: 'Check out my profile on Ripple @$username!',
                );
              },
            ),
            ListTile(
              leading: SvgPicture.asset('assets/icons/info.svg', width: 24, height: 24),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),
            const Divider(color: RippleColors.divider),
            if (!isGuest)
              ListTile(
                leading: SvgPicture.asset(
                  'assets/icons/logout.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(RippleColors.error, BlendMode.srcIn),
                ),
                title: Text(
                  'Log Out',
                  style: TextStyle(color: RippleColors.error),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await SupabaseService().signOut();
                  if (mounted) {
                    context.go(RippleConstants.routeLogin);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RippleColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RippleConstants.borderRadiusLarge),
        ),
        title: const Text('About Ripple'),
        content: Text(
          'Ripple v${RippleConstants.appVersion}\n\nYour visual social world.\n\n'
          'Posts, Reels, Stories, and DMs in one place.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final int count;
  final String label;
  final VoidCallback onTap;

  const _StatItem({
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Text(
              _formatCount(count),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: RippleColors.textSecondary,
              ),
            ),
          ],
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
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: RippleColors.background,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}