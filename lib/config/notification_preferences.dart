/// User notification preferences.
///
/// Defaults follow Instagram's out-of-the-box behavior: likes, comments,
/// follows, mentions, tags, and shares are all on. Each toggle controls
/// whether the app creates/shows that category of notification.
///
/// Persistence (Supabase row or local storage) is intentionally a follow-up
/// so this screen can ship and be verified without new dependencies or
/// credentials.
class NotificationPreferences {
  /// Likes on your posts and reels.
  bool postLikes;
  bool reelLikes;

  /// Comments on your posts and reels.
  bool postComments;
  bool reelComments;

  /// New followers.
  bool follows;

  /// Mentions (@username) in posts, reels, comments, captions.
  bool mentions;

  /// Tags in posts, reels, stories.
  bool tags;

  /// Shares of your content.
  bool shares;

  /// Push notifications (device-level; gated behind OS permission).
  bool pushEnabled;

  NotificationPreferences({
    this.postLikes = true,
    this.reelLikes = true,
    this.postComments = true,
    this.reelComments = true,
    this.follows = true,
    this.mentions = true,
    this.tags = true,
    this.shares = true,
    this.pushEnabled = true,
  });

  /// All preference values as a map, keyed by notification type string.
  Map<String, bool> toMap() => {
    'post_like': postLikes,
    'reel_like': reelLikes,
    'post_comment': postComments,
    'reel_comment': reelComments,
    'follow': follows,
    'mention': mentions,
    'tag': tags,
    'share': shares,
  };

  /// Whether a given notification type is enabled.
  bool isEnabled(String type) {
    switch (type) {
      case 'post_like':
        return postLikes;
      case 'reel_like':
        return reelLikes;
      case 'post_comment':
        return postComments;
      case 'reel_comment':
        return reelComments;
      case 'follow':
        return follows;
      case 'mention':
      case 'tag':
        return tags;
      case 'share':
        return shares;
      default:
        return true;
    }
  }

  /// Create from a map (e.g. loaded from Supabase/local storage).
  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      postLikes: map['post_like'] as bool? ?? true,
      reelLikes: map['reel_like'] as bool? ?? true,
      postComments: map['post_comment'] as bool? ?? true,
      reelComments: map['reel_comment'] as bool? ?? true,
      follows: map['follow'] as bool? ?? true,
      mentions: map['mention'] as bool? ?? true,
      tags: map['tag'] as bool? ?? true,
      shares: map['share'] as bool? ?? true,
      pushEnabled: map['push_enabled'] as bool? ?? true,
    );
  }
}

/// In-memory preference store for the current session.
///
/// Replace with Supabase/local-storage persistence when credentials are
/// available. The UI reads/writes through this so swapping the backend is
/// a one-line change.
class NotificationPreferencesStore {
  static final NotificationPreferencesStore instance =
      NotificationPreferencesStore._();

  NotificationPreferencesStore._();

  var _prefs = NotificationPreferences();

  NotificationPreferences get prefs => _prefs;

  void setPrefs(NotificationPreferences prefs) {
    _prefs = prefs;
  }
}
