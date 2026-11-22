import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/router.dart';
import '../../core/utils/guest_mode.dart';

class RippleBottomNav extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const RippleBottomNav({
    super.key,
    required this.navigationShell,
  });

  @override
  State<RippleBottomNav> createState() => _RippleBottomNavState();
}

class _RippleBottomNavState extends State<RippleBottomNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: RippleConstants.animationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    if (index == 2) {
      // Center tab (Create) - show create options
      _showCreateOptions();
      return;
    }

    _animationController.forward().then((_) => _animationController.reverse());
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _showCreateOptions() {
    if (GuestMode.isGuestMode) {
      GuestMode.showAuthRequired(context, 'create posts, reels, or stories');
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CreateOptionsSheet(
        onCreatePost: () {
          context.pop();
          context.go(RippleConstants.routeCreatePost);
        },
        onCreateReel: () {
          context.pop();
          context.go(RippleConstants.routeCreateReel);
        },
        onCreateStory: () {
          context.pop();
          context.go(RippleConstants.routeCreateStory),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentBranchIndex();

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: RippleColors.background,
          border: Border(
            top: BorderSide(
              color: RippleColors.divider,
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: RippleConstants.bottomNavHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  index: 0,
                  currentIndex: currentIndex,
                  iconAsset: 'assets/icons/home.svg',
                  activeIconAsset: 'assets/icons/home_filled.svg',
                  onTap: () => _onTabTap(0),
                ),
                _NavItem(
                  index: 1,
                  currentIndex: currentIndex,
                  iconAsset: 'assets/icons/search.svg',
                  activeIconAsset: 'assets/icons/search_filled.svg',
                  onTap: () => _onTabTap(1),
                ),
                _CreateCenterButton(
                  onTap: () => _onTabTap(2),
                ),
                _NavItem(
                  index: 3,
                  currentIndex: currentIndex,
                  iconAsset: 'assets/icons/chat.svg',
                  activeIconAsset: 'assets/icons/chat_filled.svg',
                  onTap: () => _onTabTap(3),
                ),
                _NavItem(
                  index: 4,
                  currentIndex: currentIndex,
                  iconAsset: 'assets/icons/profile.svg',
                  activeIconAsset: 'assets/icons/profile_filled.svg',
                  onTap: () => _onTabTap(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _getCurrentBranchIndex() {
    final location = GoRouterState.of(context).uri.toString();

    if (location.startsWith(RippleConstants.routeFeed)) return 0;
    if (location.startsWith(RippleConstants.routeExplore)) return 1;
    if (location.startsWith(RippleConstants.routeReels)) return 1; // Reels in explore tab
    if (location.startsWith(RippleConstants.routeDms)) return 3;
    if (location.startsWith(RippleConstants.routeProfile)) return 4;

    return 0;
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final String iconAsset;
  final String activeIconAsset;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.iconAsset,
    required this.activeIconAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RippleConstants.borderRadiusFull),
          child: AnimatedContainer(
            duration: RippleConstants.animationFast,
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: AnimatedSwitcher(
              duration: RippleConstants.animationFast,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: SvgPicture.asset(
                isActive ? activeIconAsset : iconAsset,
                key: ValueKey(isActive),
                width: 28,
                height: 28,
                colorFilter: ColorFilter.mode(
                  isActive
                      ? RippleColors.textPrimary
                      : RippleColors.textSecondary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateCenterButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateCenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(RippleConstants.borderRadiusFull),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: RippleColors.brandGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: RippleColors.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SvgPicture.asset(
                'assets/icons/plus.svg',
                width: 28,
                height: 28,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateOptionsSheet extends StatelessWidget {
  final VoidCallback onCreatePost;
  final VoidCallback onCreateReel;
  final VoidCallback onCreateStory;

  const _CreateOptionsSheet({
    required this.onCreatePost,
    required this.onCreateReel,
    required this.onCreateStory,
  });

  @override
  Widget build(BuildContext context) {
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
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: RippleColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            'Create',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),

          // Options
          _CreateOption(
            iconAsset: 'assets/icons/photo_library.svg',
            iconBgColor: RippleColors.primary,
            title: 'Post',
            subtitle: 'Share photos and videos',
            onTap: onCreatePost,
          ),
          _CreateOption(
            iconAsset: 'assets/icons/video.svg',
            iconBgColor: RippleColors.tertiary,
            title: 'Reel',
            subtitle: 'Create short videos',
            onTap: onCreateReel,
          ),
          _CreateOption(
            iconAsset: 'assets/icons/plus_circle.svg',
            iconBgColor: RippleColors.quaternary,
            title: 'Story',
            subtitle: 'Share moments that disappear',
            onTap: onCreateStory,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CreateOption extends StatelessWidget {
  final String iconAsset;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CreateOption({
    required this.iconAsset,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RippleConstants.borderRadiusLarge),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBgColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(RippleConstants.borderRadiusMedium),
                ),
                child: SvgPicture.asset(
                  iconAsset,
                  width: 26,
                  height: 26,
                  colorFilter: ColorFilter.mode(iconBgColor, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: RippleColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SvgPicture.asset(
                'assets/icons/chevron_right.svg',
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}