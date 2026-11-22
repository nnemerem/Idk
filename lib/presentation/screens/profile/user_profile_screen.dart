import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';
import 'package:ripple/services/conversation_service.dart';
import 'package:ripple/core/utils/auth_guard.dart';
import 'package:ripple/presentation/components/followers_list_sheet.dart';

class UserProfileScreen extends StatefulWidget {
  final String username;

  const UserProfileScreen({super.key, required this.username});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _reels = [];
  bool _isLoading = true;
  int _postsCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;
  bool _isOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await SupabaseService().getProfileByUsername(widget.username);
      if (profile == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final currentUserId = SupabaseService().currentUser?.id;
      _isOwnProfile = currentUserId == profile['id'];

      final followersCount = await SupabaseService().getFollowersCount(profile['id']);
      final followingCount = await SupabaseService().getFollowingCount(profile['id']);
      bool isFollowing = false;

      if (!_isOwnProfile && currentUserId != null) {
        isFollowing = await SupabaseService().isFollowing(profile['id']);
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _followersCount = followersCount;
          _followingCount = followingCount;
          _postsCount = profile['posts_count'] as int? ?? 0;
          _isFollowing = isFollowing;
          _isLoading = false;
        });
        _loadPosts();
        _loadReels();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadPosts() async {
    if (_profile == null) return;

    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tablePosts)
          .select()
          .eq('user_id', _profile!['id'])
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
    if (_profile == null) return;

    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tableReels)
          .select()
          .eq('user_id', _profile!['id'])
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

  Future<void> _openChatWithProfile() async {
    if (_profile == null) return;

    AuthGuard.run(context, onAuthenticated: () async {
      final targetId = _profile!['id'] as String?;
      if (targetId == null) return;

      final conversationId = await ConversationService.startConversation(targetId);
      if (conversationId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not start the conversation')),
          );
        }
        return;
      }

      if (mounted) {
        context.go('${RippleConstants.routeDms}/chat/$conversationId');
      }
    }, actionName: 'message');
  }

  Future<void> _toggleFollow() async {
    if (_profile == null || _isOwnProfile) return;

    setState(() {
      _isFollowing = !_isFollowing;
      _followersCount += _isFollowing ? 1 : -1;
    });

    try {
      if (_isFollowing) {
        await SupabaseService().followUser(_profile!['id']);
      } else {
        await SupabaseService().unfollowUser(_profile!['id']);
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isFollowing = !_isFollowing;
        _followersCount += _isFollowing ? 1 : -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RippleColors.background,
      appBar: AppBar(
        title: _profile != null
            ? Text(
                _profile!['username'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600),
              )
            : const Text('Profile'),
        actions: _isOwnProfile
            ? [
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/icons/menu.svg',
                    width: 26,
                    height: 26,
                  ),
                  onPressed: () => _showMenuOptions(),
                ),
              ]
            : [
                if (_isFollowing)
                  IconButton(
                    icon: SvgPicture.asset(
                      'assets/icons/person_remove.svg',
                      width: 26,
                      height: 26,
                    ),
                    onPressed: _toggleFollow,
                  )
                else
                  IconButton(
                    icon: SvgPicture.asset(
                      'assets/icons/person_add.svg',
                      width: 26,
                      height: 26,
                    ),
                    onPressed: _toggleFollow,
                  ),
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/icons/more_vert.svg',
                    width: 26,
                    height: 26,
                  ),
                  onPressed: () => _showUserOptions(),
                ),
              ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: RippleColors.primary))
          : _profile == null
              ? _buildUserNotFound()
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  color: RippleColors.primary,
                  backgroundColor: RippleColors.surface,
                  child: CustomScrollView(
                    slivers: [
                      // Profile header
                      SliverToBoxAdapter(child: _buildProfileHeader()),

                      // Stats
                      SliverToBoxAdapter(child: _buildStats()),

                      // Bio
                      SliverToBoxAdapter(child: _buildBio()),

                      // Follow/Message buttons
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
                            tabs: const [
                              Tab(icon: SvgPicture.asset('assets/icons/grid_on.svg', width: 24, height: 24)),
                              Tab(icon: SvgPicture.asset('assets/icons/video_library.svg', width: 24, height: 24)),
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
              final id = _profile?['id'] as String?;
              if (id != null) {
                FollowersListSheet.show(context, profileId: id, isFollowers: true);
              }
            },
          ),
          _StatItem(
            count: _followingCount,
            label: 'Following',
            onTap: () {
              final id = _profile?['id'] as String?;
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
    final displayName = _profile?['display_name'] as String?;
    final bio = _profile?['bio'] as String?;
    final website = _profile?['website'] as String?;

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
    if (_isOwnProfile) {
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFollowing ? RippleColors.surfaceVariant : RippleColors.primary,
                foregroundColor: _isFollowing ? RippleColors.textPrimary : RippleColors.textOnPrimary,
                side: _isFollowing
                    ? BorderSide(color: RippleColors.border, width: 1)
                    : BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RippleConstants.borderRadiusFull),
                ),
              ),
              child: Text(_isFollowing ? 'Following' : 'Follow'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _openChatWithProfile(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RippleConstants.borderRadiusFull),
                ),
              ),
              child: const Text('Message'),
            ),
          ),
        ],
      ),
    );
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
        ],
      ),
    );
  }

  Widget _buildReelGridItem(Map<String, dynamic> reel) {
    final thumb = reel['thumbnail_url'] as String? ?? reel['video_url'] as String?;
    if (thumb == null || thumb.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.go('${RippleConstants.routeReels}/reel/${reel['id']}'),
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

  List<String> _getMediaUrls(Map<String, dynamic> post) {
    final media = post['media'] as List<dynamic>?;
    if (media == null) return [];

    return media
        .where((m) => m['url'] != null && m['url'].toString().isNotEmpty)
        .map((m) => m['url'] as String)
        .toList();
  }

  Widget _buildUserNotFound() {
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
                'assets/icons/person_off.svg',
                width: 40,
                height: 40,
                colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'User not found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: RippleColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The user @${widget.username} doesn\'t exist.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: RippleColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenuOptions() {
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
            ListTile(
              leading: SvgPicture.asset('assets/icons/settings.svg', width: 24, height: 24),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.go(RippleConstants.routeSettings);
              },
            ),
            ListTile(
              leading: SvgPicture.asset('assets/icons/help.svg', width: 24, height: 24),
              title: const Text('Help'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: SvgPicture.asset('assets/icons/info.svg', width: 24, height: 24),
              title: const Text('About'),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(color: RippleColors.divider),
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

  void _showUserOptions() {
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
            ListTile(
              leading: SvgPicture.asset('assets/icons/flag.svg', width: 24, height: 24),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thanks — our team reviews reports'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
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