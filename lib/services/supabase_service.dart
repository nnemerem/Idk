import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';

class SupabaseService {
  SupabaseService._internal();
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    await Supabase.initialize(
      url: RippleConstants.supabaseUrl,
      anonKey: RippleConstants.supabaseAnonKey,
      authOptions: const AuthOptions(
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10,
      ),
    );

    _initialized = true;
  }

  SupabaseClient get client => Supabase.instance.client;
  SupabaseAuthClient get auth => Supabase.instance.client.auth;
  RealtimeClient get realtime => Supabase.instance.client.realtime;

  // Auth helpers
  User? get currentUser => auth.currentUser;
  Session? get currentSession => auth.currentSession;
  bool get isAuthenticated => currentUser != null;

  // Stream of auth state changes
  Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

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
        bytes,
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
  }

  Future<void> unfollowUser(String targetUserId) async {
    final currentUserId = currentUser!.id;
    await client
        .from(RippleConstants.tableFollows)
        .delete()
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId);
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

    return response.count ?? 0;
  }

  // Get following count
  Future<int> getFollowingCount(String userId) async {
    final response = await client
        .from(RippleConstants.tableFollows)
        .select('id')
        .eq('follower_id', userId)
        .count(CountOption.exact);

    return response.count ?? 0;
  }
}