import 'package:flutter_test/flutter_test.dart';
import 'package:ripple/config/animated_emoji.dart';

void main() {
  group('AnimatedEmojiRegistry.byGlyph', () {
    test('returns registered emoji for known glyph', () {
      final emoji = AnimatedEmojiRegistry.byGlyph('❤️');
      expect(emoji, isNotNull);
      expect(emoji!.glyph, '❤️');
    });

    test('returns null for unknown glyph', () {
      expect(AnimatedEmojiRegistry.byGlyph('🌀'), isNull);
    });
  });

  group('AnimatedEmojiRegistry.has', () {
    test('returns true for registered glyph', () {
      expect(AnimatedEmojiRegistry.has('❤️'), isTrue);
    });

    test('returns false for unregistered glyph', () {
      expect(AnimatedEmojiRegistry.has('🌀'), isFalse);
    });
  });

  group('AnimatedEmojiRegistry.all', () {
    test('is not empty', () {
      expect(AnimatedEmojiRegistry.all, isNotEmpty);
    });

    test('contains the core reaction set', () {
      final glyphs = AnimatedEmojiRegistry.all.map((e) => e.glyph).toSet();
      expect(glyphs, contains('❤️'));
      expect(glyphs, contains('😂'));
      expect(glyphs, contains('🔥'));
    });
  });

  group('AnimatedEmoji.resolve', () {
    test('prefers local assetPath over cdnUrl when source is local', () {
      final emoji = AnimatedEmoji(
        glyph: '❤️',
        assetPath: 'red_heart/red_heart_animated.webp',
        cdnUrl: 'https://cdn.ripple.app/animated_emojis/red_heart.webp',
      );
      expect(
        emoji.resolve(source: AnimatedEmojiSource.local),
        'packages/ripple/assets/animated_emojis/red_heart/red_heart_animated.webp',
      );
    });

    test('prefers cdnUrl when source is cdn', () {
      final emoji = AnimatedEmoji(
        glyph: '❤️',
        assetPath: 'red_heart/red_heart_animated.webp',
        cdnUrl: 'https://cdn.ripple.app/animated_emojis/red_heart.webp',
      );
      expect(
        emoji.resolve(source: AnimatedEmojiSource.cdn),
        'https://cdn.ripple.app/animated_emojis/red_heart.webp',
      );
    });

    test('returns null when no asset is available', () {
      final emoji = AnimatedEmoji(glyph: '🌀');
      expect(emoji.resolve(), isNull);
    });
  });
}
