import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ripple/config/constants.dart';

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
      return client.storage.from(bucket).getPublicUrl(path);
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
    return client.storage.from(bucket).getPublicUrl(path);
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
}