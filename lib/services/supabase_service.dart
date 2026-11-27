import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/media_service.dart';

/// Raised when the app is built without valid Supabase configuration
/// (missing/placeholder SUPABASE_URL or SUPABASE_ANON_KEY at build time).
class ConfigurationException implements Exception {
  final String message;
  const ConfigurationException(this.message);

  @override
  String toString() => 'ConfigurationException: $message';
}

class SupabaseService {
  SupabaseService._internal();
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;

  bool _initialized = false;

  /// Whether the app was built with a usable Supabase configuration.
  bool get isConfigured {
    final url = RippleConstants.supabaseUrl;
    final key = RippleConstants.supabaseAnonKey;
    return url.isNotEmpty &&
        key.isNotEmpty &&
        !url.contains('your-project') &&
        !key.contains('your-anon-key');
  }

  Future<void> initialize() async {
    if (_initialized) return;

    if (!isConfigured) {
      throw ConfigurationException(
        'Ripple is not configured: the app was built without a valid '
        'SUPABASE_URL or SUPABASE_ANON_KEY. Rebuild with those dart-defines, '
        'or ask the repo maintainer to add them.',
      );
    }

    // Defaults: auto-refresh token, persist session, detect session in URL
    await Supabase.initialize(
      url: RippleConstants.supabaseUrl,
      publishableKey: RippleConstants.supabaseAnonKey,
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10,
      ),
    );

    _initialized = true;
  }

  SupabaseClient get client => Supabase.instance.client;
  // Explicit type depends on the supabase_flutter version; keep it dynamic.
  dynamic get auth => Supabase.instance.client.auth;
  RealtimeClient get realtime => Supabase.instance.client.realtime;

  // Auth helpers
  User? get currentUser => auth.currentUser;
  Session? get currentSession => auth.currentSession;
  bool get isAuthenticated => currentUser != null;

  // Stream of auth state changes
  Stream<dynamic> get authStateChanges => auth.onAuthStateChange;

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    String? displayName,
  }) async {
    final response = await auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
        'display_name': displayName ?? username,
      },
    );

    // Create profile if sign up successful
    if (response.user != null) {
      await createProfile(
        userId: response.user!.id,
        username: username,
        displayName: displayName ?? username,
      );
    }

    return response;
  }

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    await auth.resetPasswordForEmail(email);
  }

  // Update password
  Future<UserResponse> updatePassword(String newPassword) async {
    return await auth.updateUser(UserAttributes(password: newPassword));
  }

  // Create user profile
  Future<void> createProfile({
    required String userId,
    required String username,
    required String displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    await client.from(RippleConstants.tableProfiles).upsert({
      'id': userId,
      'username': username,
      'display_name': displayName,
      'bio': bio ?? '',
      'avatar_url': avatarUrl,
      'followers_count': 0,
      'following_count': 0,
      'posts_count': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // Get user profile
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await client
        .from(RippleConstants.tableProfiles)
        .select()
        .eq('id', userId)
        .maybeSingle();

    return response;
  }

  // Get profile by username
  Future<Map<String, dynamic>?> getProfileByUsername(String username) async {
    final response = await client
        .from(RippleConstants.tableProfiles)
        .select()
        .eq('username', username)
        .maybeSingle();

    return response;
  }

  // Update profile
  Future<void> updateProfile({
    required String userId,
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? website,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (username != null) updates['username'] = username;
    if (displayName != null) updates['display_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (website != null) updates['website'] = website;

    await client
        .from(RippleConstants.tableProfiles)
        .update(updates)
        .eq('id', userId);
  }

  // Upload file to storage
  Future<String?> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    String? contentType,
  }) async {
    try {
      await client.storage.from(bucket).uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: true,
        ),
      );
      return MediaService.getPublicUrl(bucket: bucket, path: path);
    } catch (e) {
      return null;
    }
  }

  // Delete file from storage
  Future<void> deleteFile(String bucket, String path) async {
    await client.storage.from(bucket).remove([path]);
  }

  // Get public URL
  String getPublicUrl(String bucket, String path) {
    return MediaService.getPublicUrl(bucket: bucket, path: path);
  }

  // Follow/unfollow user
  Future<void> followUser(String targetUserId) async {
    final currentUserId = currentUser!.id;
    await client.from(RippleConstants.tableFollows).upsert({
      'follower_id': currentUserId,
      'following_id': targetUserId,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Notify the followed user (best effort — never breaks the action)
    if (currentUserId != targetUserId) {
      try {
        final myProfile = await getProfile(currentUserId);
        final myUsername = myProfile?['username'] as String?;
        if (myUsername != null) {
          await createNotification(
            targetUserId: targetUserId,
            type: 'follow',
            title: '@$myUsername',
            body: 'started following you',
            data: {
              'actor_id': currentUserId,
              'target_username': myUsername,
            },
          );
        }
      } catch (e) {
        // Notification failures are non-fatal
      }
    }
  }

  Future<void> unfollowUser(String targetUserId) async {
    final currentUserId = currentUser!.id;
    await client
        .from(RippleConstants.tableFollows)
        .delete()
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId);
  }

  // Insert a notification (best effort, never throws)
  Future<void> createNotification({
    required String targetUserId,
    required String type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await client.from(RippleConstants.tableNotifications).insert({
        'user_id': targetUserId,
        'type': type,
        'title': title,
        'body': body,
        'data': data,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Notification creation must not break the action
    }
  }

  // Check if following
  Future<bool> isFollowing(String targetUserId) async {
    final currentUserId = currentUser!.id;
    final response = await client
        .from(RippleConstants.tableFollows)
        .select()
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId)
        .maybeSingle();

    return response != null;
  }

  // Get followers count
  Future<int> getFollowersCount(String userId) async {
    final response = await client
        .from(RippleConstants.tableFollows)
        .select('id')
        .eq('following_id', userId)
        .count(CountOption.exact);

    return response.count;
  }

  // Get following count
  Future<int> getFollowingCount(String userId) async {
    final response = await client
        .from(RippleConstants.tableFollows)
        .select('id')
        .eq('follower_id', userId)
        .count(CountOption.exact);

    return response.count;
  }

  // ---------------------------------------------------------------------------
  // Comment replies (threaded comments)
  // ---------------------------------------------------------------------------

  /// Fetch comments for a post.
  ///
  /// When [parentId] is null only top-level comments are returned.
  /// When [parentId] is set only the replies to that comment are returned.
  Future<List<Map<String, dynamic>>> getPostComments(
    String postId, {
    String? parentId,
  }) async {
    final response = await client
        .from(RippleConstants.tablePostComments)
        .select('*, user:profiles(username, display_name, avatar_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: false);

    final all = List<Map<String, dynamic>>.from(response);
    if (parentId == null) {
      return all.where((c) => c['parent_id'] == null).toList();
    }
    return all.where((c) => c['parent_id'] == parentId).toList();
  }

  /// Create a comment on a post, optionally as a reply to [parentId].
  Future<void> createPostComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    final currentUserId = currentUser!.id;
    await client.from(RippleConstants.tablePostComments).insert({
      'post_id': postId,
      'user_id': currentUserId,
      'content': content,
      'parent_id': parentId,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Notify the post owner (and the parent comment author for replies)
    // best effort — never breaks the action
    try {
      final post = await client
          .from(RippleConstants.tablePosts)
          .select('user_id')
          .eq('id', postId)
          .maybeSingle();
      final postOwnerId = post?['user_id'] as String?;
      if (postOwnerId != null && postOwnerId != currentUserId) {
        final myProfile = await getProfile(currentUserId);
        final myUsername = myProfile?['username'] as String?;
        if (myUsername != null) {
          await createNotification(
            targetUserId: postOwnerId,
            type: 'post_comment',
            title: '@$myUsername',
            body: parentId == null
                ? 'commented on your post'
                : 'replied to your comment',
            data: {
              'actor_id': currentUserId,
              'post_id': postId,
              'parent_id': parentId,
            },
          );
        }
      }
      if (parentId != null && parentId != currentUserId) {
        final parent = await client
            .from(RippleConstants.tablePostComments)
            .select('user_id')
            .eq('id', parentId)
            .maybeSingle();
        final parentAuthorId = parent?['user_id'] as String?;
        if (parentAuthorId != null && parentAuthorId != currentUserId &&
            parentAuthorId != postOwnerId) {
          final myProfile = await getProfile(currentUserId);
          final myUsername = myProfile?['username'] as String?;
          if (myUsername != null) {
            await createNotification(
              targetUserId: parentAuthorId,
              type: 'post_comment',
              title: '@$myUsername',
              body: 'replied to your comment',
              data: {
                'actor_id': currentUserId,
                'post_id': postId,
                'parent_id': parentId,
              },
            );
          }
        }
      }
    } catch (e) {
      // Notification failures are non-fatal
    }
  }

  /// Fetch comments for a reel.
  ///
  /// When [parentId] is null only top-level comments are returned.
  /// When [parentId] is set only the replies to that comment are returned.
  Future<List<Map<String, dynamic>>> getReelComments(
    String reelId, {
    String? parentId,
  }) async {
    final response = await client
        .from(RippleConstants.tableReelComments)
        .select('*, user:profiles(username, display_name, avatar_url)')
        .eq('reel_id', reelId)
        .order('created_at', ascending: false);

    final all = List<Map<String, dynamic>>.from(response);
    if (parentId == null) {
      return all.where((c) => c['parent_id'] == null).toList();
    }
    return all.where((c) => c['parent_id'] == parentId).toList();
  }

  /// Create a comment on a reel, optionally as a reply to [parentId].
  Future<void> createReelComment({
    required String reelId,
    required String content,
    String? parentId,
  }) async {
    final currentUserId = currentUser!.id;
    await client.from(RippleConstants.tableReelComments).insert({
      'reel_id': reelId,
      'user_id': currentUserId,
      'content': content,
      'parent_id': parentId,
      'created_at': DateTime.now().toIso8601String(),
    });

    try {
      final reel = await client
          .from(RippleConstants.tableReels)
          .select('user_id')
          .eq('id', reelId)
          .maybeSingle();
      final reelOwnerId = reel?['user_id'] as String?;
      if (reelOwnerId != null && reelOwnerId != currentUserId) {
        final myProfile = await getProfile(currentUserId);
        final myUsername = myProfile?['username'] as String?;
        if (myUsername != null) {
          await createNotification(
            targetUserId: reelOwnerId,
            type: 'reel_comment',
            title: '@$myUsername',
            body: parentId == null
                ? 'commented on your reel'
                : 'replied to your comment',
            data: {
              'actor_id': currentUserId,
              'reel_id': reelId,
              'parent_id': parentId,
            },
          );
        }
      }
      if (parentId != null && parentId != currentUserId) {
        final parent = await client
            .from(RippleConstants.tableReelComments)
            .select('user_id')
            .eq('id', parentId)
            .maybeSingle();
        final parentAuthorId = parent?['user_id'] as String?;
        if (parentAuthorId != null && parentAuthorId != currentUserId &&
            parentAuthorId != reelOwnerId) {
          final myProfile = await getProfile(currentUserId);
          final myUsername = myProfile?['username'] as String?;
          if (myUsername != null) {
            await createNotification(
              targetUserId: parentAuthorId,
              type: 'reel_comment',
              title: '@$myUsername',
              body: 'replied to your comment',
              data: {
                'actor_id': currentUserId,
                'reel_id': reelId,
                'parent_id': parentId,
              },
            );
          }
        }
      }
    } catch (e) {
      // Notification failures are non-fatal
    }
  }

  // ---------------------------------------------------------------------------
  // Saved collections
  // ---------------------------------------------------------------------------

  /// Create a named collection for the current user.
  Future<String?> createCollection(String name) async {
    final currentUserId = currentUser!.id;
    try {
      final response = await client
          .from(RippleConstants.tableSavedCollections)
          .insert({
            'user_id': currentUserId,
            'name': name,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();
      return response['id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// List the current user's collections.
  Future<List<Map<String, dynamic>>> getCollections() async {
    final currentUserId = currentUser!.id;
    final response = await client
        .from(RippleConstants.tableSavedCollections)
        .select()
        .eq('user_id', currentUserId)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Add a post or reel to a collection.
  Future<void> addToCollection({
    required String collectionId,
    String? postId,
    String? reelId,
  }) async {
    await client.from(RippleConstants.tableSavedCollectionItems).upsert({
      'collection_id': collectionId,
      'post_id': postId,
      'reel_id': reelId,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Touch the collection's updated_at
    await client
        .from(RippleConstants.tableSavedCollections)
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', collectionId);
  }

  /// Remove a post or reel from a collection.
  Future<void> removeFromCollection({
    required String collectionId,
    String? postId,
    String? reelId,
  }) async {
    final query = client
        .from(RippleConstants.tableSavedCollectionItems)
        .delete()
        .eq('collection_id', collectionId);

    if (postId != null) {
      query.eq('post_id', postId);
    }
    if (reelId != null) {
      query.eq('reel_id', reelId);
    }

    await query;
  }

  /// List items in a collection (post or reel rows joined).
  Future<List<Map<String, dynamic>>> getCollectionItems(String collectionId) async {
    final response = await client
        .from(RippleConstants.tableSavedCollectionItems)
        .select('*, post:posts(id, caption, media, post_type), reel:reels(id, caption, video_url, thumbnail_url)')
        .eq('collection_id', collectionId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ---------------------------------------------------------------------------
  // Comment likes
  // ---------------------------------------------------------------------------

  /// Like a post comment. No-op if already liked.
  Future<void> likePostComment(String commentId) async {
    final currentUserId = currentUser!.id;
    await client.from(RippleConstants.tablePostCommentLikes).insert({
      'post_comment_id': commentId,
      'user_id': currentUserId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Unlike a post comment. No-op if not liked.
  Future<void> unlikePostComment(String commentId) async {
    final currentUserId = currentUser!.id;
    await client
        .from(RippleConstants.tablePostCommentLikes)
        .delete()
        .eq('post_comment_id', commentId)
        .eq('user_id', currentUserId);
  }

  /// Whether the current user has liked a post comment.
  Future<bool> isPostCommentLiked(String commentId) async {
    final currentUserId = currentUser!.id;
    final response = await client
        .from(RippleConstants.tablePostCommentLikes)
        .select('id')
        .eq('post_comment_id', commentId)
        .eq('user_id', currentUserId)
        .maybeSingle();
    return response != null;
  }

  /// Like count for a post comment.
  Future<int> getPostCommentLikesCount(String commentId) async {
    final response = await client
        .from(RippleConstants.tablePostCommentLikes)
        .select('id')
        .eq('post_comment_id', commentId)
        .count(CountOption.exact);
    return response.count;
  }

  /// Like a reel comment. No-op if already liked.
  Future<void> likeReelComment(String commentId) async {
    final currentUserId = currentUser!.id;
    await client.from(RippleConstants.tableReelCommentLikes).insert({
      'reel_comment_id': commentId,
      'user_id': currentUserId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Unlike a reel comment. No-op if not liked.
  Future<void> unlikeReelComment(String commentId) async {
    final currentUserId = currentUser!.id;
    await client
        .from(RippleConstants.tableReelCommentLikes)
        .delete()
        .eq('reel_comment_id', commentId)
        .eq('user_id', currentUserId);
  }

  /// Whether the current user has liked a reel comment.
  Future<bool> isReelCommentLiked(String commentId) async {
    final currentUserId = currentUser!.id;
    final response = await client
        .from(RippleConstants.tableReelCommentLikes)
        .select('id')
        .eq('reel_comment_id', commentId)
        .eq('user_id', currentUserId)
        .maybeSingle();
    return response != null;
  }

  /// Like count for a reel comment.
  Future<int> getReelCommentLikesCount(String commentId) async {
    final response = await client
        .from(RippleConstants.tableReelCommentLikes)
        .select('id')
        .eq('reel_comment_id', commentId)
        .count(CountOption.exact);
    return response.count;
  }

  // ---------------------------------------------------------------------------
  // Mentions (@username)
  // ---------------------------------------------------------------------------

  /// Extract @usernames from text (e.g. "hello @alice @bob" → ["alice", "bob"]).
  ///
  /// Usernames are matched as @ followed by word characters (letters, digits,
  /// underscore, period). Case-insensitive matching against stored usernames
  /// happens at lookup time.
  static List<String> parseMentions(String text) {
    final RegExp mentionRegex = RegExp(r'@(\w[\w\.]*)');
    final matches = mentionRegex.allMatches(text);
    return matches.map((m) => m.group(1)!).toSet().toList();
  }

  /// Look up mentioned users and create a mention notification for each.
  ///
  /// [actorId] is the user who wrote the mention. [contextData] is extra data
  /// stored on the notification (e.g. post_id, reel_id, comment_id).
  /// [mentionedIn] is a human-readable description of where the mention
  /// appeared (e.g. "commented on your post").
  Future<void> notifyMentions({
    required String actorId,
    required String text,
    required Map<String, dynamic> contextData,
    required String mentionedIn,
  }) async {
    final usernames = parseMentions(text);
    if (usernames.isEmpty) return;

    for (final username in usernames) {
      try {
        final mentioned = await getProfileByUsername(username);
        if (mentioned == null) continue; // No such user — skip silently
        final mentionedId = mentioned['id'] as String?;
        if (mentionedId == null || mentionedId == actorId) continue;

        await createNotification(
          targetUserId: mentionedId,
          type: 'mention',
          title: '@$username',
          body: mentionedIn,
          data: contextData,
        );
      } catch (_) {
        // Mention notification failures are non-fatal
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Comment pinning
  // ---------------------------------------------------------------------------

  /// Pin a post comment (unpins any other pinned comment on the same post).
  /// Allowed for the comment author or the post owner.
  Future<void> pinPostComment(String commentId, String postId) async {
    final currentUserId = currentUser!.id;

    // Verify the current user may pin: comment author or post owner
    final comment = await client
        .from(RippleConstants.tablePostComments)
        .select('user_id')
        .eq('id', commentId)
        .maybeSingle();
    final commentAuthorId = comment?['user_id'] as String?;
    final post = await client
        .from(RippleConstants.tablePosts)
        .select('user_id')
        .eq('id', postId)
        .maybeSingle();
    final postOwnerId = post?['user_id'] as String?;

    if (commentAuthorId != currentUserId && postOwnerId != currentUserId) {
      return; // Not authorized to pin
    }

    // Unpin all other comments on this post
    await client
        .from(RippleConstants.tablePostComments)
        .update({'is_pinned': false})
        .eq('post_id', postId)
        .eq('is_pinned', true);

    // Pin this comment
    await client
        .from(RippleConstants.tablePostComments)
        .update({'is_pinned': true})
        .eq('id', commentId);
  }

  /// Unpin a post comment. Allowed for the comment author or the post owner.
  Future<void> unpinPostComment(String commentId, String postId) async {
    final currentUserId = currentUser!.id;

    final comment = await client
        .from(RippleConstants.tablePostComments)
        .select('user_id')
        .eq('id', commentId)
        .maybeSingle();
    final commentAuthorId = comment?['user_id'] as String?;
    final post = await client
        .from(RippleConstants.tablePosts)
        .select('user_id')
        .eq('id', postId)
        .maybeSingle();
    final postOwnerId = post?['user_id'] as String?;

    if (commentAuthorId != currentUserId && postOwnerId != currentUserId) {
      return; // Not authorized to unpin
    }

    await client
        .from(RippleConstants.tablePostComments)
        .update({'is_pinned': false})
        .eq('id', commentId);
  }

  /// Whether a post comment is pinned.
  Future<bool> isPostCommentPinned(String commentId) async {
    final response = await client
        .from(RippleConstants.tablePostComments)
        .select('is_pinned')
        .eq('id', commentId)
        .maybeSingle();
    return response?['is_pinned'] == true;
  }

  /// Pin a reel comment (unpins any other pinned comment on the same reel).
  /// Allowed for the comment author or the reel owner.
  Future<void> pinReelComment(String commentId, String reelId) async {
    final currentUserId = currentUser!.id;

    final comment = await client
        .from(RippleConstants.tableReelComments)
        .select('user_id')
        .eq('id', commentId)
        .maybeSingle();
    final commentAuthorId = comment?['user_id'] as String?;
    final reel = await client
        .from(RippleConstants.tableReels)
        .select('user_id')
        .eq('id', reelId)
        .maybeSingle();
    final reelOwnerId = reel?['user_id'] as String?;

    if (commentAuthorId != currentUserId && reelOwnerId != currentUserId) {
      return; // Not authorized to pin
    }

    await client
        .from(RippleConstants.tableReelComments)
        .update({'is_pinned': false})
        .eq('reel_id', reelId)
        .eq('is_pinned', true);

    await client
        .from(RippleConstants.tableReelComments)
        .update({'is_pinned': true})
        .eq('id', commentId);
  }

  /// Unpin a reel comment. Allowed for the comment author or the reel owner.
  Future<void> unpinReelComment(String commentId, String reelId) async {
    final currentUserId = currentUser!.id;

    final comment = await client
        .from(RippleConstants.tableReelComments)
        .select('user_id')
        .eq('id', commentId)
        .maybeSingle();
    final commentAuthorId = comment?['user_id'] as String?;
    final reel = await client
        .from(RippleConstants.tableReels)
        .select('user_id')
        .eq('id', reelId)
        .maybeSingle();
    final reelOwnerId = reel?['user_id'] as String?;

    if (commentAuthorId != currentUserId && reelOwnerId != currentUserId) {
      return; // Not authorized to unpin
    }

    await client
        .from(RippleConstants.tableReelComments)
        .update({'is_pinned': false})
        .eq('id', commentId);
  }

  /// Whether a reel comment is pinned.
  Future<bool> isReelCommentPinned(String commentId) async {
    final response = await client
        .from(RippleConstants.tableReelComments)
        .select('is_pinned')
        .eq('id', commentId)
        .maybeSingle();
    return response?['is_pinned'] == true;
  }

  // ---------------------------------------------------------------------------
  // Reposts
  // ---------------------------------------------------------------------------

  /// Repost a post. No-op if already reposted.
  Future<void> repostPost(String postId) async {
    final currentUserId = currentUser!.id;
    await client.from(RippleConstants.tablePostReposts).insert({
      'post_id': postId,
      'user_id': currentUserId,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Notify the post owner (skip self-reposts)
    final postOwnerId = await _getPostOwnerId(postId);
    if (postOwnerId != null && postOwnerId != currentUserId) {
      try {
        final myProfile = await getProfile(currentUserId);
        final myUsername = myProfile?['username'] as String?;
        if (myUsername != null) {
          await createNotification(
            targetUserId: postOwnerId,
            type: 'repost',
            title: '@$myUsername',
            body: 'reposted your post',
            data: {
              'actor_id': currentUserId,
              'post_id': postId,
            },
          );
        }
      } catch (_) {
        // Notification failures are non-fatal
      }
    }
  }

  /// Unrepost a post. No-op if not reposted.
  Future<void> unrepostPost(String postId) async {
    final currentUserId = currentUser!.id;
    await client
        .from(RippleConstants.tablePostReposts)
        .delete()
        .eq('post_id', postId)
        .eq('user_id', currentUserId);
  }

  /// Whether the current user has reposted a post.
  Future<bool> isPostReposted(String postId) async {
    final currentUserId = currentUser!.id;
    final response = await client
        .from(RippleConstants.tablePostReposts)
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', currentUserId)
        .maybeSingle();
    return response != null;
  }

  /// Repost count for a post.
  Future<int> getPostRepostCount(String postId) async {
    final response = await client
        .from(RippleConstants.tablePostReposts)
        .select('id')
        .eq('post_id', postId)
        .count(CountOption.exact);
    return response.count;
  }

  /// Repost a reel. No-op if already reposted.
  Future<void> repostReel(String reelId) async {
    final currentUserId = currentUser!.id;
    await client.from(RippleConstants.tableReelReposts).insert({
      'reel_id': reelId,
      'user_id': currentUserId,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Notify the reel owner (skip self-reposts)
    final reelOwnerId = await _getReelOwnerId(reelId);
    if (reelOwnerId != null && reelOwnerId != currentUserId) {
      try {
        final myProfile = await getProfile(currentUserId);
        final myUsername = myProfile?['username'] as String?;
        if (myUsername != null) {
          await createNotification(
            targetUserId: reelOwnerId,
            type: 'repost',
            title: '@$myUsername',
            body: 'reposted your reel',
            data: {
              'actor_id': currentUserId,
              'reel_id': reelId,
            },
          );
        }
      } catch (_) {
        // Notification failures are non-fatal
      }
    }
  }

  /// Unrepost a reel. No-op if not reposted.
  Future<void> unrepostReel(String reelId) async {
    final currentUserId = currentUser!.id;
    await client
        .from(RippleConstants.tableReelReposts)
        .delete()
        .eq('reel_id', reelId)
        .eq('user_id', currentUserId);
  }

  /// Whether the current user has reposted a reel.
  Future<bool> isReelReposted(String reelId) async {
    final currentUserId = currentUser!.id;
    final response = await client
        .from(RippleConstants.tableReelReposts)
        .select('id')
        .eq('reel_id', reelId)
        .eq('user_id', currentUserId)
        .maybeSingle();
    return response != null;
  }

  /// Repost count for a reel.
  Future<int> getReelRepostCount(String reelId) async {
    final response = await client
        .from(RippleConstants.tableReelReposts)
        .select('id')
        .eq('reel_id', reelId)
        .count(CountOption.exact);
    return response.count;
  }

  /// Helper: get the owner id of a post.
  Future<String?> _getPostOwnerId(String postId) async {
    final response = await client
        .from(RippleConstants.tablePosts)
        .select('user_id')
        .eq('id', postId)
        .maybeSingle();
    return response?['user_id'] as String?;
  }

  /// Helper: get the owner id of a reel.
  Future<String?> _getReelOwnerId(String reelId) async {
    final response = await client
        .from(RippleConstants.tableReels)
        .select('user_id')
        .eq('id', reelId)
        .maybeSingle();
    return response?['user_id'] as String?;
  }

  // ---------------------------------------------------------------------------
  // Emoji reactions — post comments
  // ---------------------------------------------------------------------------

  /// Add or replace the current user's emoji reaction on a post comment.
  /// Notifies the comment author (skips self-reactions).
  Future<void> addPostCommentReaction(String commentId, String emoji) async {
    final currentUserId = currentUser!.id;
    await client
        .from(RippleConstants.tablePostCommentReactions)
        .upsert({
      'comment_id': commentId,
      'user_id': currentUserId,
      'emoji': emoji,
      'created_at': DateTime.now().toIso8601String(),
    }, onConflict: 'comment_id, user_id');

    // Notify the comment owner (skip self-reactions)
    final commentOwnerId = await _getPostCommentOwnerId(commentId);
    if (commentOwnerId != null && commentOwnerId != currentUserId) {
      final myProfile = await getProfile(currentUserId);
      final myUsername = myProfile?['username'] as String?;
      if (myUsername != null) {
        try {
          await createNotification(
            targetUserId: commentOwnerId,
            type: 'comment_reaction',
            title: '@$myUsername',
            body: 'reacted with $emoji to your comment',
            data: {
              'actor_id': currentUserId,
              'comment_id': commentId,
              'emoji': emoji,
              'post_comment': true,
            },
          );
        } catch (_) {
          // Notification failures are non-fatal
        }
      }
    }
  }

  /// Remove the current user's reaction from a post comment.
  Future<void> removePostCommentReaction(String commentId) async {
    final currentUserId = currentUser!.id;
    await client
        .from(RippleConstants.tablePostCommentReactions)
        .delete()
        .eq('comment_id', commentId)
        .eq('user_id', currentUserId);
  }

  /// Reactions for a post comment: {'reactions': {emoji: count}, 'userReaction': String?}
  Future<Map<String, dynamic>> getPostCommentReactions(String commentId) async {
    final currentUserId = currentUser!.id;
    final response = await client
        .from(RippleConstants.tablePostCommentReactions)
        .select('emoji, user_id')
        .eq('comment_id', commentId);

    final reactions = <String, int>{};
    String? userReaction;
    for (final row in (response as List)) {
      final emoji = row['emoji'] as String;
      reactions[emoji] = (reactions[emoji] ?? 0) + 1;
      if (row['user_id'] == currentUserId) {
        userReaction = emoji;
      }
    }
    return {'reactions': reactions, 'userReaction': userReaction};
  }

  // ---------------------------------------------------------------------------
  // Emoji reactions — reel comments
  // ---------------------------------------------------------------------------

  /// Add or replace the current user's emoji reaction on a reel comment.
  /// Notifies the comment author (skips self-reactions).
  Future<void> addReelCommentReaction(String commentId, String emoji) async {
    final currentUserId = currentUser!.id;
    await client
        .from(RippleConstants.tableReelCommentReactions)
        .upsert({
      'comment_id': commentId,
      'user_id': currentUserId,
      'emoji': emoji,
      'created_at': DateTime.now().toIso8601String(),
    }, onConflict: 'comment_id, user_id');

    // Notify the comment owner (skip self-reactions)
    final commentOwnerId = await _getReelCommentOwnerId(commentId);
    if (commentOwnerId != null && commentOwnerId != currentUserId) {
      final myProfile = await getProfile(currentUserId);
      final myUsername = myProfile?['username'] as String?;
      if (myUsername != null) {
        try {
          await createNotification(
            targetUserId: commentOwnerId,
            type: 'comment_reaction',
            title: '@$myUsername',
            body: 'reacted with $emoji to your comment',
            data: {
              'actor_id': currentUserId,
              'comment_id': commentId,
              'emoji': emoji,
              'post_comment': false,
            },
          );
        } catch (_) {
          // Notification failures are non-fatal
        }
      }
    }
  }

  /// Remove the current user's reaction from a reel comment.
  Future<void> removeReelCommentReaction(String commentId) async {
    final currentUserId = currentUser!.id;
    await client
        .from(RippleConstants.tableReelCommentReactions)
        .delete()
        .eq('comment_id', commentId)
        .eq('user_id', currentUserId);
  }

  /// Reactions for a reel comment: {'reactions': {emoji: count}, 'userReaction': String?}
  Future<Map<String, dynamic>> getReelCommentReactions(String commentId) async {
    final currentUserId = currentUser!.id;
    final response = await client
        .from(RippleConstants.tableReelCommentReactions)
        .select('emoji, user_id')
        .eq('comment_id', commentId);

    final reactions = <String, int>{};
    String? userReaction;
    for (final row in (response as List)) {
      final emoji = row['emoji'] as String;
      reactions[emoji] = (reactions[emoji] ?? 0) + 1;
      if (row['user_id'] == currentUserId) {
        userReaction = emoji;
      }
    }
    return {'reactions': reactions, 'userReaction': userReaction};
  }

  /// Helper: get the owner id of a post comment.
  Future<String?> _getPostCommentOwnerId(String commentId) async {
    final response = await client
        .from(RippleConstants.tablePostComments)
        .select('user_id')
        .eq('id', commentId)
        .maybeSingle();
    return response?['user_id'] as String?;
  }

  /// Helper: get the owner id of a reel comment.
  Future<String?> _getReelCommentOwnerId(String commentId) async {
    final response = await client
        .from(RippleConstants.tableReelComments)
        .select('user_id')
        .eq('id', commentId)
        .maybeSingle();
    return response?['user_id'] as String?;
  }

  // ---------------------------------------------------------------------------
  // Discovery & Creators — search / suggested / trending
  // ---------------------------------------------------------------------------

  /// Search posts by hashtag. Matches captions containing `#$hashtag`.
  Future<List<Map<String, dynamic>>> searchByHashtag(String hashtag) async {
    final clean = hashtag.trim().replaceFirst(RegExp(r'^#'), '');
    final response = await client
        .from(RippleConstants.tablePosts)
        .select('''
          *,
          profiles:user_id (id, username, display_name, avatar_url),
          likes:post_likes (count),
          comments:post_comments (count)
        ''')
        .ilike('caption', '%#$clean%')
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Search posts by location. Matches the post's `location` field.
  Future<List<Map<String, dynamic>>> searchByLocation(String location) async {
    final response = await client
        .from(RippleConstants.tablePosts)
        .select('''
          *,
          profiles:user_id (id, username, display_name, avatar_url),
          likes:post_likes (count),
          comments:post_comments (count)
        ''')
        .ilike('location', '%$location%')
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Search reels by audio (music title or artist).
  Future<List<Map<String, dynamic>>> searchReelsByAudio(String query) async {
    final response = await client
        .from(RippleConstants.tableReels)
        .select('''
          *,
          profiles:user_id (id, username, display_name, avatar_url),
          likes:reel_likes (count),
          comments:reel_comments (count)
        ''')
        .or('music_title.ilike.%$query%,music_artist.ilike.%$query%')
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Suggested accounts: profiles the current user doesn't follow yet,
  /// ordered by follower count (popular first). Excludes the current user.
  Future<List<Map<String, dynamic>>> getSuggestedAccounts({int limit = 20}) async {
    final currentUserId = currentUser?.id;
    if (currentUserId == null) return [];

    final followsResponse = await client
        .from(RippleConstants.tableFollows)
        .select('following_id')
        .eq('follower_id', currentUserId);
    final followedIds = <String>{};
    for (final row in (followsResponse as List)) {
      final id = row['following_id'] as String?;
      if (id != null) followedIds.add(id);
    }
    followedIds.add(currentUserId);

    final profilesResponse = await client
        .from(RippleConstants.tableProfiles)
        .select('id, username, display_name, avatar_url, followers_count, bio')
        .order('followers_count', ascending: false)
        .limit(limit * 3);

    final candidates = List<Map<String, dynamic>>.from(profilesResponse);
    final suggested = candidates
        .where((p) => !followedIds.contains(p['id'] as String?))
        .take(limit)
        .toList();
    return suggested;
  }

  /// Trending posts: recent posts ranked by like count (most liked first).
  Future<List<Map<String, dynamic>>> getTrendingPosts({int limit = 20}) async {
    final response = await client
        .from(RippleConstants.tablePosts)
        .select('''
          *,
          profiles:user_id (id, username, display_name, avatar_url),
          likes:post_likes (count),
          comments:post_comments (count)
        ''')
        .order('created_at', ascending: false)
        .limit(100);

    final posts = List<Map<String, dynamic>>.from(response);
    posts.sort((a, b) {
      final aLikes = (a['likes'] as Map?)?['count'] as int? ?? 0;
      final bLikes = (b['likes'] as Map?)?['count'] as int? ?? 0;
      return bLikes.compareTo(aLikes);
    });
    return posts.take(limit).toList();
  }

  // ---------------------------------------------------------------------------
  // Privacy & Safety — private account, blocked / restricted accounts
  // ---------------------------------------------------------------------------

  /// Toggle the current user's private account setting.
  ///
  /// When private, new followers must be approved before they can follow.
  /// Returns the new `is_private` value.
  Future<bool> togglePrivateAccount(bool isPrivate) async {
    final currentUserId = currentUser!.id;
    await client
        .from(RippleConstants.tableProfiles)
        .update({'is_private': isPrivate})
        .eq('id', currentUserId);
    return isPrivate;
  }

  /// Whether the current user's account is private.
  Future<bool> isPrivateAccount() async {
    final currentUserId = currentUser!.id;
    final response = await client
        .from(RippleConstants.tableProfiles)
        .select('is_private')
        .eq('id', currentUserId)
        .maybeSingle();
    return response?['is_private'] == true;
  }

  /// Block a user. Removes any existing follow relationship in both directions.
  Future<void> blockUser(String targetUserId) async {
    final currentUserId = currentUser!.id;
    if (currentUserId == targetUserId) return;

    await client.from(RippleConstants.tableBlockedAccounts).upsert({
      'blocker_id': currentUserId,
      'blocked_id': targetUserId,
      'created_at': DateTime.now().toIso8601String(),
    }, onConflict: 'blocker_id, blocked_id');

    // Remove mutual follows
    await client
        .from(RippleConstants.tableFollows)
        .delete()
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId);
    await client
        .from(RippleConstants.tableFollows)
        .delete()
        .eq('follower_id', targetUserId)
        .eq('following_id', currentUserId);
  }

  /// Unblock a user.
  Future<void> unblockUser(String targetUserId) async {
    final currentUserId = currentUser!.id;
    await client
        .from(RippleConstants.tableBlockedAccounts)
        .delete()
        .eq('blocker_id', currentUserId)
        .eq('blocked_id', targetUserId);
  }

  /// List of accounts the current user has blocked.
  Future<List<Map<String, dynamic>>> getBlockedAccounts() async {
    final currentUserId = currentUser!.id;
    final response = await client
        .from(RippleConstants.tableBlockedAccounts)
        .select('''
          blocked_id,
          created_at,
          blocked:profiles!blocked_accounts_blocked_id_fkey (
            id, username, display_name, avatar_url
          )
        ''')
        .eq('blocker_id', currentUserId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Restrict a user. Their comments and messages are limited.
  Future<void> restrictUser(String targetUserId) async {
    final currentUserId = currentUser!.id;
    if (currentUserId == targetUserId) return;

    await client.from(RippleConstants.tableRestrictedAccounts).upsert({
      'restricter_id': currentUserId,
      'restricted_id': targetUserId,
      'created_at': DateTime.now().toIso8601String(),
    }, onConflict: 'restricter_id, restricted_id');
  }

  /// Unrestrict a user.
  Future<void> unrestrictUser(String targetUserId) async {
    final currentUserId = currentUser!.id;
    await client
        .from(RippleConstants.tableRestrictedAccounts)
        .delete()
        .eq('restricter_id', currentUserId)
        .eq('restricted_id', targetUserId);
  }

  /// List of accounts the current user has restricted.
  Future<List<Map<String, dynamic>>> getRestrictedAccounts() async {
    final currentUserId = currentUser!.id;
    final response = await client
        .from(RippleConstants.tableRestrictedAccounts)
        .select('''
          restricted_id,
          created_at,
          restricted:profiles!restricted_accounts_restricted_id_fkey (
            id, username, display_name, avatar_url
          )
        ''')
        .eq('restricter_id', currentUserId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Whether the current user has blocked a given account.
  Future<bool> isBlocked(String targetUserId) async {
    final currentUserId = currentUser!.id;
    final response = await client
        .from(RippleConstants.tableBlockedAccounts)
        .select('id')
        .eq('blocker_id', currentUserId)
        .eq('blocked_id', targetUserId)
        .maybeSingle();
    return response != null;
  }

  /// Whether the current user has restricted a given account.
  Future<bool> isRestricted(String targetUserId) async {
    final currentUserId = currentUser!.id;
    final response = await client
        .from(RippleConstants.tableRestrictedAccounts)
        .select('id')
        .eq('restricter_id', currentUserId)
        .eq('restricted_id', targetUserId)
        .maybeSingle();
    return response != null;
  }
}