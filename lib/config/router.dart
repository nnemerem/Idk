import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ripple/core/utils/auth_guard.dart';
import 'package:ripple/core/utils/guest_mode.dart';
import 'package:ripple/presentation/screens/auth/login_screen.dart';
import 'package:ripple/presentation/screens/auth/register_screen.dart';
import 'package:ripple/presentation/screens/auth/splash_screen.dart';
import 'package:ripple/presentation/screens/feed/feed_screen.dart';
import 'package:ripple/presentation/screens/reels/reels_screen.dart';
import 'package:ripple/presentation/screens/explore/explore_screen.dart';
import 'package:ripple/presentation/screens/dms/dms_list_screen.dart';
import 'package:ripple/presentation/screens/profile/profile_screen.dart';
import 'package:ripple/presentation/screens/create/create_post_screen.dart';
import 'package:ripple/presentation/screens/create/create_reel_screen.dart';
import 'package:ripple/presentation/screens/create/create_story_screen.dart';
import 'package:ripple/presentation/screens/post/post_detail_screen.dart';
import 'package:ripple/presentation/screens/reels/reel_detail_screen.dart';
import 'package:ripple/presentation/screens/profile/user_profile_screen.dart';
import 'package:ripple/presentation/screens/chat/chat_screen.dart';
import 'package:ripple/presentation/screens/search/search_screen.dart';
import 'package:ripple/presentation/screens/notifications/notifications_screen.dart';
import 'package:ripple/presentation/screens/profile/settings_screen.dart';
import 'package:ripple/presentation/screens/profile/edit_profile_screen.dart';
import 'package:ripple/presentation/components/ripple_bottom_nav.dart';
import 'package:ripple/config/constants.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

final GoRouter appRouter = GoRouter(
  initialLocation: RippleConstants.routeSplash,
  redirect: _redirect,
  observers: [routeObserver],
  routes: [
    // Auth routes (no bottom nav)
    GoRoute(
      path: RippleConstants.routeSplash,
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: RippleConstants.routeLogin,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: RippleConstants.routeRegister,
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // Main shell with bottom navigation
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return RippleBottomNav(navigationShell: navigationShell);
      },
      branches: [
        // Feed branch (Home)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RippleConstants.routeFeed,
              name: 'feed',
              builder: (context, state) => const FeedScreen(),
              routes: [
                GoRoute(
                  path: 'post/:postId',
                  name: 'post-detail',
                  builder: (context, state) => PostDetailScreen(
                    postId: state.pathParameters['postId']!,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Explore branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RippleConstants.routeExplore,
              name: 'explore',
              builder: (context, state) => const ExploreScreen(),
            ),
          ],
        ),

        // Reels branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RippleConstants.routeReels,
              name: 'reels',
              builder: (context, state) => const ReelsScreen(),
              routes: [
                GoRoute(
                  path: 'reel/:reelId',
                  name: 'reel-detail',
                  builder: (context, state) => ReelDetailScreen(
                    reelId: state.pathParameters['reelId']!,
                  ),
                ),
              ],
            ),
          ],
        ),

        // DMs branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RippleConstants.routeDms,
              name: 'dms',
              builder: (context, state) => const DmsListScreen(),
              routes: [
                GoRoute(
                  path: 'chat/:conversationId',
                  name: 'chat',
                  builder: (context, state) => ChatScreen(
                    conversationId: state.pathParameters['conversationId']!,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Profile branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RippleConstants.routeProfile,
              name: 'profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'user/:username',
                  name: 'user-profile',
                  builder: (context, state) => UserProfileScreen(
                    username: state.pathParameters['username']!,
                  ),
                ),
                GoRoute(
                  path: 'settings',
                  name: 'settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
                GoRoute(
                  path: 'edit-profile',
                  name: 'edit-profile',
                  builder: (context, state) => const EditProfileScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // Create routes (modal/full screen, no bottom nav)
    GoRoute(
      path: RippleConstants.routeCreatePost,
      name: 'create-post',
      builder: (context, state) => const CreatePostScreen(),
    ),
    GoRoute(
      path: RippleConstants.routeCreateReel,
      name: 'create-reel',
      builder: (context, state) => const CreateReelScreen(),
    ),
    GoRoute(
      path: RippleConstants.routeCreateStory,
      name: 'create-story',
      builder: (context, state) => const CreateStoryScreen(),
    ),

    // Search route
    GoRoute(
      path: RippleConstants.routeSearch,
      name: 'search',
      builder: (context, state) => const SearchScreen(),
    ),

    // Notifications route
    GoRoute(
      path: RippleConstants.routeNotifications,
      name: 'notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),

    // Public user profile (accessible from anywhere)
    GoRoute(
      path: RippleConstants.routeUserProfile,
      name: 'public-user-profile',
      builder: (context, state) => UserProfileScreen(
        username: state.pathParameters['username']!,
      ),
    ),
  ],
);

String? _redirect(BuildContext context, GoRouterState state) {
  final session = Supabase.instance.client.auth.currentSession;
  final isLoggedIn = session != null;
  final isGuest = GuestMode.isGuestMode;
  final location = state.uri.toString();

  // Routes that guests CAN access (view-only)
  final guestAllowedRoutes = [
    RippleConstants.routeFeed,
    RippleConstants.routeReels,
    RippleConstants.routeExplore,
    RippleConstants.routeSearch,
    RippleConstants.routeNotifications,
    RippleConstants.routeFeed + '/post/',  // Post detail
    RippleConstants.routeReels + '/reel/', // Reel detail
    RippleConstants.routeUserProfile,      // Public profiles
  ];

  // Routes that require authentication (create, edit, DMs, profile settings)
  final authRequiredRoutes = [
    RippleConstants.routeDms,
    RippleConstants.routeDms + '/chat/',
    RippleConstants.routeProfile,
    RippleConstants.routeCreatePost,
    RippleConstants.routeCreateReel,
    RippleConstants.routeCreateStory,
    RippleConstants.routeSettings,
    RippleConstants.routeEditProfile,
  ];

  // Auth routes that should redirect logged-in users
  final authRoutes = [
    RippleConstants.routeLogin,
    RippleConstants.routeRegister,
  ];

  final isGuestAllowedRoute = guestAllowedRoutes.any((route) => location.startsWith(route));
  final isAuthRequiredRoute = authRequiredRoutes.any((route) => location.startsWith(route));
  final isAuthRoute = authRoutes.any((route) => location.startsWith(route));

  // Allow guests to access view-only routes
  if (isGuest && isGuestAllowedRoute) {
    return null; // Allow access
  }

  // Block guests from auth-required routes
  if (isGuest && isAuthRequiredRoute) {
    return RippleConstants.routeLogin;
  }

  // Redirect unauthenticated users from protected routes to login
  if (!isLoggedIn && !isGuest && isAuthRequiredRoute) {
    return RippleConstants.routeLogin;
  }

  // Redirect authenticated users from auth routes to feed
  if ((isLoggedIn || isGuest) && isAuthRoute) {
    return RippleConstants.routeFeed;
  }

  // Redirect from root to feed
  if (location == '/') {
    return (isLoggedIn || isGuest) ? RippleConstants.routeFeed : RippleConstants.routeLogin;
  }

  return null;
}