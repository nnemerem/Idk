import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';
import 'package:ripple/core/utils/guest_mode.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _reels = [];
  bool _isSearching = false;
  String _selectedTab = 'Top';
  final Set<String> _followingIds = {};
  Timer? _debounceTimer;

  final List<String> _tabs = ['Top', 'Accounts', 'Reels'];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _searchController.addListener(_onSearchChanged);
    _loadFollowingIds();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFollowingIds() async {
    if (GuestMode.isGuestMode) return;

    final currentUserId = SupabaseService().currentUser?.id;
    if (currentUserId == null) return;

    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tableFollows)
          .select('following_id')
          .eq('follower_id', currentUserId);

      if (mounted) {
        setState(() {
          _followingIds.addAll(
            (response as List)
                .map((row) => row['following_id'] as String?)
                .whereType<String>(),
          );
        });
      }
    } catch (e) {
      // Best effort — follow buttons still work
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _debounceTimer?.cancel();
    if (query.length >= 2) {
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) _search(query);
      });
    } else {
      setState(() {
        _users.clear();
        _posts.clear();
        _reels.clear();
        _isSearching = false;
      });
    }
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);

    try {
      // Search users
      final usersResponse = await SupabaseService().client
          .from(RippleConstants.tableProfiles)
          .select()
          .ilike('username', '%$query%')
          .limit(20);

      // Search posts
      final postsResponse = await SupabaseService().client
          .from(RippleConstants.tablePosts)
          .select('''
            *,
            profiles:user_id (id, username, display_name, avatar_url)
          ''')
          .ilike('caption', '%$query%')
          .limit(20);

      // Search reels
      final reelsResponse = await SupabaseService().client
          .from(RippleConstants.tableReels)
          .select('''
            *,
            profiles:user_id (id, username, display_name, avatar_url)
          ''')
          .ilike('caption', '%$query%')
          .limit(20);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(usersResponse);
          _posts = List<Map<String, dynamic>>.from(postsResponse);
          _reels = List<Map<String, dynamic>>.from(reelsResponse);
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> user) async {
    if (GuestMode.isGuestMode) {
      GuestMode.showAuthRequired(context, 'follow');
      return;
    }
    final targetId = user['id'] as String?;
    if (targetId == null) return;

    final currentlyFollowing = _followingIds.contains(targetId);
    setState(() {
      if (currentlyFollowing) {
        _followingIds.remove(targetId);
      } else {
        _followingIds.add(targetId);
      }
    });

    try {
      if (currentlyFollowing) {
        await SupabaseService().unfollowUser(targetId);
      } else {
        await SupabaseService().followUser(targetId);
      }
    } catch (e) {
      setState(() {
        if (currentlyFollowing) {
          _followingIds.add(targetId);
        } else {
          _followingIds.remove(targetId);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Could not update follow status'), backgroundColor: RippleColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RippleColors.background,
      appBar: AppBar(
        backgroundColor: RippleColors.background,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/icons/arrow_back.svg',
            width: 24,
            height: 24,
          ),
          onPressed: () => context.pop(),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: TextStyle(color: RippleColors.textTertiary),
            border: InputBorder.none,
            prefixIcon: SvgPicture.asset(
              'assets/icons/search.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: SvgPicture.asset(
                      'assets/icons/close.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _users.clear();
                        _posts.clear();
                        _reels.clear();
                      });
                    },
                  )
                : null,
          ),
          onSubmitted: (value) {
            if (value.trim().length >= 2) {
              _search(value.trim());
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: RippleColors.background,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              indicatorColor: RippleColors.primary,
              indicatorWeight: 3,
              labelColor: RippleColors.textPrimary,
              unselectedLabelColor: RippleColors.textSecondary,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
              onTap: (index) => setState(() => _selectedTab = _tabs[index]),
            ),
          ),

          // Search results
          Expanded(
            child: _isSearching
                ? Center(child: CircularProgressIndicator(color: RippleColors.primary))
                : _searchController.text.isEmpty
                    ? _buildRecentSearches()
                    : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    // In a real app, this would show recent searches from local storage
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/search.svg',
            width: 64,
            height: 64,
            colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
          ),
          const SizedBox(height: 16),
          Text(
            'Search for people, posts, and reels',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: RippleColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Posts, accounts, and reels from the community',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RippleColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final usersVisible = _selectedTab != 'Reels' && _users.isNotEmpty;
    final postsVisible = _selectedTab != 'Reels' && _selectedTab != 'Accounts' && _posts.isNotEmpty;
    final reelsVisible = _selectedTab != 'Accounts' && _reels.isNotEmpty;
    if (!usersVisible && !postsVisible && !reelsVisible) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/search_off.svg',
              width: 64,
              height: 64,
              colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: RippleColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: RippleColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Users
          if (_selectedTab != 'Reels' && _users.isNotEmpty) ...[
            _buildSectionHeader('Accounts'),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _users.length,
              itemBuilder: (context, index) => _buildUserTile(_users[index]),
            ),
            const SizedBox(height: 24),
          ],

          // Posts
          if (_selectedTab != 'Reels' && _selectedTab != 'Accounts' && _posts.isNotEmpty) ...[
            _buildSectionHeader('Posts'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 1,
              ),
              itemCount: _posts.length,
              itemBuilder: (context, index) => _buildPostGridItem(_posts[index]),
            ),
            const SizedBox(height: 24),
          ],

          // Reels
          if (_selectedTab != 'Accounts' && _reels.isNotEmpty) ...[
            _buildSectionHeader('Reels'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 9/16,
              ),
              itemCount: _reels.length,
              itemBuilder: (context, index) => _buildReelGridItem(_reels[index]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: RippleColors.surfaceVariant,
        backgroundImage: user['avatar_url'] != null
            ? CachedNetworkImageProvider(user['avatar_url'])
            : null,
        child: user['avatar_url'] == null
            ? Text(
                user['username']?[0]?.toUpperCase() ?? '?',
                style: const TextStyle(color: RippleColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
              )
            : null,
      ),
      title: Text(
        user['display_name'] ?? user['username'] ?? 'Unknown',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '@${user['username']}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: RippleColors.textSecondary),
      ),
      trailing: TextButton(
        onPressed: () => _toggleFollow(user),
        child: Text(
          _followingIds.contains(user['id']) ? 'Following' : 'Follow',
          style: TextStyle(
            color: _followingIds.contains(user['id']) ? RippleColors.textSecondary : RippleColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: () => context.go('/user/${user['username']}'),
    );
  }

  Widget _buildPostGridItem(Map<String, dynamic> post) {
    final media = post['media'] as List<dynamic>?;
    if (media == null || media.isEmpty) return const SizedBox.shrink();

    final mediaUrl = media.first['url'] as String?;
    if (mediaUrl == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.go('${RippleConstants.routeFeed}/post/${post['id']}'),
      child: CachedNetworkImage(
        imageUrl: mediaUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: RippleColors.surfaceVariant),
        errorWidget: (context, url, error) => Container(
          color: RippleColors.surfaceVariant,
          child: SvgPicture.asset(
            'assets/icons/photo_library.svg',
            colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  Widget _buildReelGridItem(Map<String, dynamic> reel) {
    final thumbnailUrl = reel['thumbnail_url'] as String?;
    final videoUrl = reel['video_url'] as String?;

    return GestureDetector(
      onTap: () => context.go('${RippleConstants.routeReels}/reel/${reel['id']}'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl != null)
            CachedNetworkImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: RippleColors.surfaceVariant),
              errorWidget: (context, url, error) => Container(
                color: RippleColors.surfaceVariant,
                child: SvgPicture.asset(
                  'assets/icons/photo_library.svg',
                  colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
                ),
              ),
            )
          else if (videoUrl != null)
            Container(color: RippleColors.surfaceVariant)
          else
            Container(color: RippleColors.surfaceVariant),
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
                width: 12,
                height: 12,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
        ],
      ),
    );
  }
}