import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  Timer? _debounceTimer;

  // Discovery categories
  static const List<String> _discoveryTabs = [
    'For You',
    'Hashtags',
    'Locations',
    'Audio',
  ];
  String _discoveryTab = 'For You';

  // Search results tabs
  static const List<String> _resultsTabs = ['Top', 'Accounts', 'Posts', 'Reels'];
  String _resultsTab = 'Top';

  // Standard search results
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _reels = [];

  // Discovery results
  List<Map<String, dynamic>> _hashtagPosts = [];
  List<Map<String, dynamic>> _locationPosts = [];
  List<Map<String, dynamic>> _audioReels = [];

  // Discovery (shown when the query is empty)
  List<Map<String, dynamic>> _suggested = [];
  List<Map<String, dynamic>> _trending = [];
  List<String> _recentSearches = [];

  bool _isSearching = false;
  final Set<String> _followingIds = {};
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _searchController.addListener(_onSearchChanged);
    _loadFollowingIds();
    _loadDiscovery();
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

  /// Load suggested accounts + trending posts for the "For You" discovery view.
  Future<void> _loadDiscovery() async {
    if (GuestMode.isGuestMode) return;

    try {
      final results = await Future.wait([
        SupabaseService().getSuggestedAccounts(limit: 10),
        SupabaseService().getTrendingPosts(limit: 10),
      ]);

      if (mounted) {
        setState(() {
          _suggested = results[0] as List<Map<String, dynamic>>;
          _trending = results[1] as List<Map<String, dynamic>>;
        });
      }
    } catch (e) {
      // Discovery is non-critical
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
        _hashtagPosts.clear();
        _locationPosts.clear();
        _audioReels.clear();
        _isSearching = false;
        _hasSearched = false;
      });
    }
  }

  void _addRecentSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _recentSearches.remove(trimmed);
      _recentSearches.insert(0, trimmed);
      if (_recentSearches.length > 10) _recentSearches.removeLast();
    });
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;
    _addRecentSearch(trimmed);

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await Future.wait([
        SupabaseService().client
            .from(RippleConstants.tableProfiles)
            .select()
            .ilike('username', '%$trimmed%')
            .limit(20),
        SupabaseService().client
            .from(RippleConstants.tablePosts)
            .select('''
              *,
              profiles:user_id (id, username, display_name, avatar_url),
              likes:post_likes (count),
              comments:post_comments (count)
            ''')
            .ilike('caption', '%$trimmed%')
            .limit(20),
        SupabaseService().client
            .from(RippleConstants.tableReels)
            .select('''
              *,
              profiles:user_id (id, username, display_name, avatar_url),
              likes:reel_likes (count),
              comments:reel_comments (count)
            ''')
            .ilike('caption', '%$trimmed%')
            .limit(20),
      ]);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(results[0]);
          _posts = List<Map<String, dynamic>>.from(results[1]);
          _reels = List<Map<String, dynamic>>.from(results[2]);
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  /// Run a discovery search for the active discovery tab (hashtag / location / audio).
  Future<void> _searchDiscovery(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;
    _addRecentSearch(trimmed);

    setState(() => _isSearching = true);

    try {
      switch (_discoveryTab) {
        case 'Hashtags':
          _hashtagPosts = await SupabaseService().searchByHashtag(trimmed);
          break;
        case 'Locations':
          _locationPosts = await SupabaseService().searchByLocation(trimmed);
          break;
        case 'Audio':
          _audioReels = await SupabaseService().searchReelsByAudio(trimmed);
          break;
        default:
      }
    } catch (_) {
      // Discovery search is non-critical
    } finally {
      if (mounted) setState(() => _isSearching = false);
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
      _suggested = _suggested.map((u) {
        if (u['id'] == targetId) {
          return u..['_optimisticFollowing'] = !currentlyFollowing;
        }
        return u;
      }).toList();
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
        _suggested = _suggested.map((u) {
          if (u['id'] == targetId) {
            return u..['_optimisticFollowing'] = currentlyFollowing;
          }
          return u;
        }).toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not update follow status'),
            backgroundColor: RippleColors.error,
          ),
        );
      }
    }
  }

  void _clearRecentSearches() {
    setState(() => _recentSearches.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RippleColors.background,
      appBar: AppBar(
        backgroundColor: RippleColors.background,
        elevation: 0,
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
                        _hashtagPosts.clear();
                        _locationPosts.clear();
                        _audioReels.clear();
                        _isSearching = false;
                        _hasSearched = false;
                      });
                    },
                  )
                : null,
          ),
          onSubmitted: (value) {
            if (value.trim().length >= 2) {
              final trimmed = value.trim();
              if (_discoveryTab == 'For You') {
                _search(trimmed);
              } else {
                _searchDiscovery(trimmed);
              }
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Discovery category chips (hashtag / location / audio)
          Container(
            color: RippleColors.background,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _discoveryTabs.length,
                itemBuilder: (context, index) {
                  final tab = _discoveryTabs[index];
                  final selected = _discoveryTab == tab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(tab),
                      selected: selected,
                      onSelected: (_) => setState(() => _discoveryTab = tab),
                      backgroundColor: RippleColors.surfaceVariant,
                      labelStyle: TextStyle(
                        color: selected ? RippleColors.primary : RippleColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: selected ? RippleColors.primary : RippleColors.border,
                          width: selected ? 1.5 : 0.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Results / discovery body
          Expanded(
            child: _searchController.text.isEmpty
                ? _buildDiscoveryView()
                : (_discoveryTab == 'For You'
                    ? _buildSearchResults()
                    : _buildDiscoveryResults()),
          ),
        ],
      ),
    );
  }

  /// "For You" discovery view: suggested accounts, trending, recent searches.
  Widget _buildDiscoveryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Suggested accounts
          if (_suggested.isNotEmpty) ...[
            _buildSectionHeader('Suggested for you'),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _suggested.length,
                itemBuilder: (context, index) => _buildSuggestedAccountChip(_suggested[index]),
              ),
            ),
            const SizedBox(height: 28),
          ],

          // Trending posts
          if (_trending.isNotEmpty) ...[
            _buildSectionHeader('Trending'),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _trending.length,
                itemBuilder: (context, index) => _buildTrendingPostCard(_trending[index]),
              ),
            ),
            const SizedBox(height: 28),
          ],

          // Recent searches
          if (_recentSearches.isNotEmpty) ...[
            _buildSectionHeader('Recent searches'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((recent) {
                return ActionChip(
                  label: Text(recent),
                  onPressed: () {
                    _searchController.text = recent;
                    _searchController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: recent.length,
                    );
                    _focusNode.requestFocus();
                    final trimmed = recent.trim();
                    if (_discoveryTab == 'For You') {
                      _search(trimmed);
                    } else {
                      _searchDiscovery(trimmed);
                    }
                  },
                  avatar: const Icon(Icons.history, size: 16),
                  onDeleted: () {
                    setState(() => _recentSearches.remove(recent));
                  },
                );
              }).toList(),
            ),
            if (_recentSearches.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _clearRecentSearches,
                  child: const Text('Clear all'),
                ),
              ),
            ],
          ],

          if (_suggested.isEmpty && _trending.isEmpty && _recentSearches.isEmpty)
            _buildEmptyDiscovery(),
        ],
      ),
    );
  }

  Widget _buildEmptyDiscovery() {
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
            'Discover people, posts, and reels',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: RippleColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search by username, hashtag, location, or audio.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RippleColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  /// Suggested account shown as a horizontal chip with a follow button.
  Widget _buildSuggestedAccountChip(Map<String, dynamic> user) {
    final username = user['username'] as String? ?? 'Unknown';
    final displayName = user['display_name'] as String? ?? username;
    final avatarUrl = user['avatar_url'] as String?;
    final id = user['id'] as String?;
    final optimistic = user['_optimisticFollowing'] as bool? ?? false;
    final following = optimistic || _followingIds.contains(id);

    return SizedBox(
      width: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => context.go('/user/$username'),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: RippleColors.surfaceVariant,
                  backgroundImage: avatarUrl != null
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Text(
                          username[0].toUpperCase(),
                          style: const TextStyle(
                            color: RippleColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RippleColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '@$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: RippleColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (id != null)
            TextButton(
              onPressed: () => _toggleFollow(user),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                following ? 'Following' : 'Follow',
                style: TextStyle(
                  color: following ? RippleColors.textSecondary : RippleColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Trending post shown as a horizontal card in the discovery view.
  Widget _buildTrendingPostCard(Map<String, dynamic> post) {
    final media = post['media'] as List<dynamic>?;
    final mediaUrl = (media != null && media.isNotEmpty)
        ? (media.first as Map)['url'] as String?
        : null;
    final profile = post['profiles'] as Map<String, dynamic>?;
    final username = profile != null
        ? (profile['username'] as String? ?? 'Unknown')
        : 'Unknown';
    final likesCount = (post['likes'] as Map?)?['count'] as int? ?? 0;
    final postId = post['id'] as String?;

    return GestureDetector(
      onTap: postId != null
          ? () => context.go('${RippleConstants.routeFeed}/post/$postId')
          : null,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: RippleColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mediaUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: mediaUrl,
                  height: 140,
                  width: 150,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: RippleColors.surfaceVariant,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: RippleColors.surfaceVariant,
                    child: SvgPicture.asset(
                      'assets/icons/photo_library.svg',
                      width: 32,
                      height: 32,
                      colorFilter: ColorFilter.mode(
                        RippleColors.textTertiary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@$username',
                    style: TextStyle(
                      color: RippleColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 14,
                        color: RippleColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$likesCount',
                        style: TextStyle(
                          color: RippleColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Standard search results (users / posts / reels) for the "For You" tab.
  Widget _buildSearchResults() {
    final usersVisible = _resultsTab != 'Reels' && _users.isNotEmpty;
    final postsVisible = _resultsTab != 'Reels' && _resultsTab != 'Accounts' && _posts.isNotEmpty;
    final reelsVisible = _resultsTab != 'Accounts' && _reels.isNotEmpty;

    if (!usersVisible && !postsVisible && !reelsVisible && _isSearching == false) {
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
          // Results tabs
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _resultsTabs.length,
              itemBuilder: (context, index) {
                final tab = _resultsTabs[index];
                final selected = _resultsTab == tab;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(tab),
                    selected: selected,
                    onSelected: (_) => setState(() => _resultsTab = tab),
                    backgroundColor: RippleColors.surfaceVariant,
                    labelStyle: TextStyle(
                      color: selected ? RippleColors.primary : RippleColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: selected ? RippleColors.primary : RippleColors.border,
                        width: selected ? 1.5 : 0.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Users
          if (usersVisible) ...[
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
          if (postsVisible) ...[
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
          if (reelsVisible) ...[
            _buildSectionHeader('Reels'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 9 / 16,
              ),
              itemCount: _reels.length,
              itemBuilder: (context, index) => _buildReelGridItem(_reels[index]),
            ),
          ],
        ],
      ),
    );
  }

  /// Discovery results (hashtag / location / audio posts/reels).
  Widget _buildDiscoveryResults() {
    final hasResults = _hashtagPosts.isNotEmpty ||
        _locationPosts.isNotEmpty ||
        _audioReels.isNotEmpty;

    if (!hasResults && _isSearching == false) {
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
              'No ${_discoveryTab.toLowerCase()} results found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: RippleColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different keyword',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: RippleColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final query = _searchController.text.trim();
        if (query.length >= 2) await _searchDiscovery(query);
      },
      color: RippleColors.primary,
      backgroundColor: RippleColors.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_discoveryTab == 'Hashtags' && _hashtagPosts.isNotEmpty) ...[
            _buildSectionHeader('#${_searchController.text.trim()} posts'),
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
              itemCount: _hashtagPosts.length,
              itemBuilder: (context, index) =>
                  _buildDiscoveryPostGridItem(_hashtagPosts[index]),
            ),
            const SizedBox(height: 24),
          ],
          if (_discoveryTab == 'Locations' && _locationPosts.isNotEmpty) ...[
            _buildSectionHeader('${_searchController.text.trim()} posts'),
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
              itemCount: _locationPosts.length,
              itemBuilder: (context, index) =>
                  _buildDiscoveryPostGridItem(_locationPosts[index]),
            ),
            const SizedBox(height: 24),
          ],
          if (_discoveryTab == 'Audio' && _audioReels.isNotEmpty) ...[
            _buildSectionHeader('${_searchController.text.trim()} reels'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 9 / 16,
              ),
              itemCount: _audioReels.length,
              itemBuilder: (context, index) => _buildReelGridItem(_audioReels[index]),
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
                style: const TextStyle(
                  color: RippleColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
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

    final postId = post['id'] as String?;
    return GestureDetector(
      onTap: postId != null
          ? () => context.go('${RippleConstants.routeFeed}/post/$postId')
          : null,
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

  Widget _buildDiscoveryPostGridItem(Map<String, dynamic> post) {
    return _buildPostGridItem(post);
  }

  Widget _buildReelGridItem(Map<String, dynamic> reel) {
    final thumbnailUrl = reel['thumbnail_url'] as String?;
    final videoUrl = reel['video_url'] as String?;
    final reelId = reel['id'] as String?;

    return GestureDetector(
      onTap: reelId != null
          ? () => context.go('${RippleConstants.routeReels}/reel/$reelId')
          : null,
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
