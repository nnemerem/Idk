import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/config/router.dart';
import 'package:ripple/services/supabase_service.dart';
import 'package:ripple/core/utils/guest_mode.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  static const int _perPage = 20;
  int _selectedGridCount = 3;
  String _selectedCategory = 'For You';

  final List<String> _categories = [
    'For You',
    'Following',
    'Reels',
    'Shop',
    'Music',
    'Travel',
    'Food',
    'Style',
    'Art',
    'Sports',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    if (refresh) {
      _page = 0;
      _hasMore = true;
    }

    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tablePosts)
          .select('''
            *,
            profiles:user_id (id, username, display_name, avatar_url),
            likes:post_likes (count),
            comments:post_comments (count)
          ''')
          .order('created_at', ascending: false)
          .range(_page * _perPage, (_page + 1) * _perPage - 1);

      final newPosts = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          if (refresh) {
            _posts = newPosts;
          } else {
            _posts.addAll(newPosts);
          }
          _hasMore = newPosts.length >= _perPage;
          _page++;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = GuestMode.isGuestMode;
    return Scaffold(
      backgroundColor: RippleColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            ShaderMask(
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
            if (isGuest) ...[
              const SizedBox(width: 12),
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
        ),
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/search.svg',
              width: 28,
              height: 28,
            ),
            onPressed: () => context.go(RippleConstants.routeSearch),
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/grid_on.svg',
              width: 28,
              height: 28,
            ),
            tooltip: 'Grid',
            onPressed: () {
              setState(() => _selectedGridCount = _selectedGridCount == 3 ? 2 : 3);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: RippleColors.background,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              indicatorColor: RippleColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              labelColor: RippleColors.textPrimary,
              unselectedLabelColor: RippleColors.textSecondary,
              tabs: _categories.map((cat) => Tab(text: cat)).toList(),
              onTap: (index) {
                final category = _categories[index];
                if (category == 'Reels') {
                  context.go(RippleConstants.routeReels);
                  return;
                }
                setState(() {
                  _selectedCategory = category;
                  _posts.clear();
                  _page = 0;
                  _hasMore = true;
                });
                _loadPosts(refresh: true);
              },
            ),
          ),
        ),
      ),
      body: _posts.isEmpty && !_isLoading
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: () => _loadPosts(refresh: true),
              color: RippleColors.primary,
              backgroundColor: RippleColors.surface,
              child: GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(2),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _selectedGridCount,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 1,
                ),
                itemCount: _posts.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _posts.length) {
                    return _buildLoadingGridItem();
                  }
                  return _buildGridPost(_posts[index]);
                },
              ),
            ),
    );
  }

  Widget _buildGridPost(Map<String, dynamic> post) {
    final mediaUrls = _getMediaUrls(post);
    if (mediaUrls.isEmpty) return const SizedBox.shrink();

    final mediaUrl = mediaUrls.first;
    final isVideo = post['media']?.firstWhere(
      (m) => m['url'] == mediaUrl,
      orElse: () => <String, dynamic>{},
    )['type'] == 'video';

    return GestureDetector(
      onTap: () {
        context.go('${RippleConstants.routeFeed}/post/${post['id']}');
      },
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

  Widget _buildLoadingGridItem() {
    return Container(
      color: RippleColors.surfaceVariant,
      child: Center(
        child: CircularProgressIndicator(
          color: RippleColors.primary,
          strokeWidth: 1.5,
        ),
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
                'assets/icons/search.svg',
                width: 40,
                height: 40,
                colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Explore',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: RippleColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Discover photos, videos, and Reels from accounts you don\'t follow yet.',
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
}