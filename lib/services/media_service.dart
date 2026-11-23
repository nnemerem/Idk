import 'package:supabase_flutter/supabase_flutter.dart';

/// Which media provider the app uses to construct media URLs.
///
/// Configured at build time via --dart-define=MEDIA_PROVIDER=<name>.
///
/// - `supabase` (default): Supabase Storage public URLs (existing behaviour)
/// - `cloudflare`:  Cloudflare R2 / CDN — avatars & media served through the CDN domain
/// - `cloudinary`: Cloudinary — avatars/media with image transformations
enum MediaProvider {
  supabase,
  cloudflare,
  cloudinary;

  static MediaProvider from(String value) {
    switch (value.trim().toLowerCase()) {
      case 'cloudflare':
        return MediaProvider.cloudflare;
      case 'cloudinary':
        return MediaProvider.cloudinary;
      default:
        return MediaProvider.supabase;
    }
  }
}

/// Provider-aware URL construction for media.
///
/// UPLOADS still go through Supabase Storage (that is where assets live today).
/// This layer decides how media is **served** — it does not move upload logic.
///
/// Configured at build time via:
///   --dart-define=MEDIA_PROVIDER=supabase|cloudflare|cloudinary
///   --dart-define=CLOUDFLARE_CDN_BASE_URL=https://cdn.example.com
///   --dart-define=CLOUDINARY_CLOUD_NAME=<cloud>
class MediaService {
  MediaService();

  static MediaProvider get provider => MediaProvider.from(
        const String.fromEnvironment('MEDIA_PROVIDER', defaultValue: 'supabase'),
      );

  static String? get cloudinaryCloudName => const String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );

  static String? get cloudflareCdnBaseUrl => const String.fromEnvironment(
    'CLOUDFLARE_CDN_BASE_URL',
    defaultValue: '',
  );

  /// Public URL for a media path inside a bucket.
  ///
  /// If the stored URL is already absolute (starts with http:// or
  /// https://) it is returned unchanged — this keeps rows written under the
  /// old provider valid.
  static String getPublicUrl({
    required String bucket,
    required String path,
  }) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    switch (provider) {
      case MediaProvider.cloudflare:
        final base = cloudflareCdnBaseUrl;
        if (base != null && base.isNotEmpty) {
          return '${base.replaceAll(RegExp(r'/+$'), '')}/$path';
        }
        return _supabaseUrl(bucket, path);
      case MediaProvider.cloudinary:
        final cloudName = cloudinaryCloudName;
        if (cloudName != null && cloudName.isNotEmpty && !cloudName.contains('your-cloud-name')) {
          return 'https://res.cloudinary.com/$cloudName/image/upload/$path';
        }
        return _supabaseUrl(bucket, path);
      default:
        return _supabaseUrl(bucket, path);
    }
  }

  static String getAvatarUrl({
    required String bucket,
    required String path,
    int size = 128,
  }) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    if (provider == MediaProvider.cloudinary) {
      final cloudName = cloudinaryCloudName;
      if (cloudName != null && cloudName.isNotEmpty && !cloudName.contains('your-cloud-name')) {
        final safeSize = size.clamp(16, 1024);
        return 'https://res.cloudinary.com/$cloudName/image/upload/'
            'w_$safeSize,h_$safeSize,r_fill,c_thumb/$path';
      }
    }

    return getPublicUrl(bucket: bucket, path: path);
  }

  static String _supabaseUrl(String bucket, String path) {
    return Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
  }
}
