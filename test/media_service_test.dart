import 'package:flutter_test/flutter_test.dart';
import 'package:ripple/services/media_service.dart';

void main() {
  group('MediaService.provider', () {
    test('defaults to supabase', () {
      expect(MediaService.provider, MediaProvider.supabase);
    });
  });

  group('MediaService.getPublicUrl', () {
    test('returns absolute URLs unchanged', () {
      final url = MediaService.getPublicUrl(
        bucket: 'posts',
        path: 'https://cdn.example.com/media/abc.png',
      );
      expect(url, 'https://cdn.example.com/media/abc.png');
    });

    test('returns http URLs unchanged', () {
      final url = MediaService.getPublicUrl(
        bucket: 'posts',
        path: 'http://example.com/media/abc.png',
      );
      expect(url, 'http://example.com/media/abc.png');
    });
  });

  group('MediaService.getAvatarUrl', () {
    test('returns absolute URLs unchanged', () {
      final url = MediaService.getAvatarUrl(
        bucket: 'avatars',
        path: 'https://cdn.example.com/avatar.png',
      );
      expect(url, 'https://cdn.example.com/avatar.png');
    });

    test('clamps size between 16 and 1024', () {
      final small = MediaService.getAvatarUrl(
        bucket: 'avatars',
        path: 'avatar.png',
        size: 1,
      );
      expect(small, contains('w_16,h_16'));

      final large = MediaService.getAvatarUrl(
        bucket: 'avatars',
        path: 'avatar.png',
        size: 9999,
      );
      expect(large, contains('w_1024,h_1024'));
    });
  });
}
