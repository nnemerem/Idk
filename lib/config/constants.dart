class RippleConstants {
  // App info
  static const String appName = 'Ripple';
  static const String appVersion = '1.0.0';
  static const String appBundleId = 'com.n.o_group.ripple';

  // Supabase (injected at build time via --dart-define)
  // Using static getters with String.fromEnvironment for dart-define support
  static String get supabaseUrl => String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );

  static String get supabaseAnonKey => String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key-here',
  );

  // Route names
  static const String routeSplash = '/splash';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeHome = '/';
  static const String routeFeed = '/feed';
  static const String routeReels = '/reels';
  static const String routeExplore = '/explore';
  static const String routeDms = '/dms';
  static const String routeProfile = '/profile';
  static const String routeCreatePost = '/create/post';
  static const String routeCreateReel = '/create/reel';
  static const String routeCreateStory = '/create/story';
  static const String routePostDetail = '/post/:id';
  static const String routeReelDetail = '/reel/:id';
  static const String routeUserProfile = '/user/:username';
  static const String routeChat = '/chat/:id';
  static const String routeSearch = '/search';
  static const String routeSettings = '/profile/settings';
  static const String routeEditProfile = '/profile/edit-profile';
  static const String routeNotifications = '/notifications';
  static const String routeBlockedAccounts = '/profile/blocked-accounts';
  static const String routeRestrictedAccounts = '/profile/restricted-accounts';

  // Storage buckets
  static const String bucketAvatars = 'avatars';
  static const String bucketPosts = 'posts';
  static const String bucketReels = 'reels';
  static const String bucketStories = 'stories';

  // Database tables
  static const String tableProfiles = 'profiles';
  static const String tablePosts = 'posts';
  static const String tableReels = 'reels';
  static const String tableStories = 'stories';
  static const String tableFollows = 'follows';
  static const String tablePostComments = 'post_comments';
  static const String tableReelComments = 'reel_comments';
  static const String tableMessages = 'messages';
  static const String tableConversations = 'conversations';
  static const String tableConversationParticipants = 'conversation_participants';
  static const String tableSavedPosts = 'saved_posts';
  static const String tableNotifications = 'notifications';
  static const String tableStoryViews = 'story_views';
  static const String tableSavedCollections = 'saved_collections';
  static const String tableSavedCollectionItems = 'saved_collection_items';
  static const String tablePostCommentLikes = 'post_comment_likes';
  static const String tableReelCommentLikes = 'reel_comment_likes';
  static const String tablePostCommentReactions = 'post_comment_reactions';
  static const String tableReelCommentReactions = 'reel_comment_reactions';
  static const String tablePostReposts = 'post_reposts';
  static const String tableReelReposts = 'reel_reposts';
  static const String tableBlockedAccounts = 'blocked_accounts';
  static const String tableRestrictedAccounts = 'restricted_accounts';

  // Post types
  static const String postTypeImage = 'image';
  static const String postTypeCarousel = 'carousel';
  static const String postTypeVideo = 'video';

  // Reel settings
  static const int maxReelDurationSeconds = 90;
  static const int maxStoryDurationSeconds = 15;

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;

  // UI constants
  static const double storyRingSize = 72;
  static const double storyRingStrokeWidth = 3;
  static const double avatarSizeSmall = 32;
  static const double avatarSizeMedium = 40;
  static const double avatarSizeLarge = 80;
  static const double avatarSizeXLarge = 120;
  static const double bottomNavHeight = 92;
  static const double topNavHeight = 56;
  static const double maxContentWidth = 614;
  static const double borderRadiusSmall = 8;
  static const double borderRadiusMedium = 12;
  static const double borderRadiusLarge = 16;
  static const double borderRadiusXLarge = 20;
  static const double borderRadiusFull = 999;

  // Animation durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 250);
  static const Duration animationSlow = Duration(milliseconds: 350);

  // Default placeholder images
  static const String placeholderAvatar = 'https://api.dicebear.com/7.x/avataaars/svg?seed=';
  static const String placeholderPost = 'https://picsum.photos/seed/ripple/614/614';
  static const String placeholderReel = 'https://picsum.photos/seed/ripple_reel/340/600';

  // Regex patterns
  static final RegExp usernameRegex = RegExp(r'^[a-zA-Z0-9._]{1,30}$');
  static final RegExp emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  static final RegExp hashtagRegex = RegExp(r'#(\w+)');
  static final RegExp mentionRegex = RegExp(r'@(\w+)');

  // Feature flags
  static const bool enableReels = true;
  static const bool enableStories = true;
  static const bool enableDms = true;
  static const bool enableSearch = true;
  static const bool enableSavePosts = true;
}