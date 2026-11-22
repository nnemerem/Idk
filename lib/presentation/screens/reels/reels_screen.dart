import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/config/router.dart';
import 'package:ripple/services/supabase_service.dart';
import 'package:ripple/core/utils/guest_mode.dart';
import 'package:ripple/core/utils/auth_guard.dart';
import 'package:ripple/presentation/components/reel_card.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final PageController _pageController = PageController();
  List<Map<String, dynamic>> _reels = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 0;
  static const int _perPage = 10;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadReels();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadReels({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    if (refresh) {
      _page = 0;
      _hasMore = true;
    }

    try {
      final response = await SupabaseService().client
          .from(RippleConstants.tableReels)
          .select('''
            *,
            profiles:user_id (id, username, display_name, avatar_url),
            likes:reel_likes (count),
            comments:reel_comments (count),
            is_liked:reel_likes!inner (user_id)
          ''')
          .order('created_at', ascending: false)
          .range(_page * _perPage, (_page + 1) * _perPage - 1);

      final newReels = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          if (refresh) {
            _reels = newReels;
          } else {
            _reels.addAll(newReels);
          }
          _hasMore = newReels.length >= _perPage;
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

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);

    // Preload next reel
    if (index >= _reels.length - 2 && _hasMore && !_isLoading) {
      _loadReels();
    }
  }

  void _onLikeReel(String reelId, bool currentlyLiked) {
    AuthGuard.run(context, onAuthenticated: () async {
      try {
        final userId = SupabaseService().currentUser!.id;
        if (currentlyLiked) {
          await SupabaseService().client
              .from('reel_likes')
              .delete()
              .eq('reel_id', reelId)
              .eq('user_id', userId);
        } else {
          await SupabaseService().client.from('reel_likes').insert({
            'reel_id': reelId,
            'user_id': userId,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        setState(() {
          final index = _reels.indexWhere((r) => r['id'] == reelId);
          if (index != -1) {
            final likes = _reels[index]['likes'];
            final count = likes is Map ? (likes['count'] as int? ?? 0) : 0;
            _reels[index]['likes'] = {'count': currentlyLiked ? count - 1 : count + 1};
            _reels[index]['is_liked'] = currentlyLiked
                ? <Map<String, dynamic>>[]
                : [
                    {'user_id': SupabaseService().currentUser!.id}
                  ];
          }
        });
      } catch (e) {
        if (mounted) setState(() {});
      }
    }, actionName: 'like');
  }

  void _onSaveReel(String reelId) {
    AuthGuard.run(context, onAuthenticated: () async {
      // Reels share the saved-posts table with posts.
      try {
        await SupabaseService().client.from(RippleConstants.tableSavedPosts).upsert({
          'user_id': SupabaseService().currentUser!.id,
          'post_id': reelId,
          'created_at': DateTime.now().toIso8601String(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reel saved'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save reel'),
              backgroundColor: RippleColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }, actionName: 'save');
  }

  void _onShareReel(String reelId) {
    AuthGuard.run(context, onAuthenticated: () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shared: ripple://reel/$reelId'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }, actionName: 'share');
  }

  void _onCommentReel(String reelId) {
    context.go('${RippleConstants.routeReels}/reel/$reelId');
  }

  void _onProfileTap(String username) {
    context.go('/user/$username');
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = GuestMode.isGuestMode;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _isLoading && _reels.isEmpty
              ? _buildLoadingState()
              : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _reels.length + (_hasMore ? 1 : 0),
              onPageChanged: _onPageChanged,
              physics: const ClampingScrollPhysics(),
              itemBuilder: (context, index) {
                if (index >= _reels.length) {
                  return _buildLoadingReel();
                }

                final reel = _reels[index];
                final isCurrent = index == _currentIndex;

                return ReelCard(
                  reel: reel,
                  isCurrent: isCurrent,
                  onLike: _onLikeReel,
                  onSave: _onSaveReel,
                  onShare: _onShareReel,
                  onComment: _onCommentReel,
                  onProfileTap: _onProfileTap,
                );
              },
            ),
          // Guest indicator
          if (isGuest)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(RippleConstants.borderRadiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/visibility.svg',
                        width: 14,
                        height: 14,
                        colorFilter: ColorFilter.mode(RippleColors.primary, BlendMode.srcIn),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Guest Mode',
                        style: TextStyle(
                          color: RippleColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: RippleColors.primary),
          const SizedBox(height: 16),
          Text(
            'Loading Reels...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RippleColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingReel() {
    return Container(
      color: RippleColors.surfaceVariant,
      child: Center(
        child: CircularProgressIndicator(color: RippleColors.primary),
      ),
    );
  }
}