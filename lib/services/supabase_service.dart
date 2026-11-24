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
}