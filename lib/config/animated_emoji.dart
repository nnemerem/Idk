import 'package:flutter/material.dart';
import 'package:ripple/config/theme.dart';

/// Where animated emoji assets are served from.
enum AnimatedEmojiSource {
  /// Bundled in the app (flutter assets).
  local,
  /// Served via CDN (Cloudflare R2 in front of the emoji pack).
  cdn,
}

/// Lookup key for an animated emoji. Stored in the DB as raw Unicode so
/// system emojis keep working everywhere; this map only affects rendering.
class AnimatedEmoji {
  /// The Unicode character (e.g. ❤️, 😂).
  final String glyph;

  /// Local asset path relative to `assets/animated_emojis/`, e.g.
  /// `red_heart/red_heart_animated.webp`. Null when not bundled locally.
  final String? assetPath;

  /// CDN URL, e.g. `https://cdn.ripple.app/animated_emojis/red_heart.webp`.
  /// Null when not served via CDN.
  final String? cdnUrl;

  /// Fallback size when rendered inline at text height.
  final double size;

  const AnimatedEmoji({
    required this.glyph,
    this.assetPath,
    this.cdnUrl,
    this.size = 24,
  });

  /// Resolve the best available provider for this emoji.
  ///
  /// Prefers CDN when `source == cdn` and a CDN URL exists, otherwise falls
  /// back to the local asset, otherwise returns null (caller renders the
  /// raw Unicode glyph as a system emoji).
  String? resolve({AnimatedEmojiSource source = AnimatedEmojiSource.local}) {
    if (source == AnimatedEmojiSource.cdn && cdnUrl != null) {
      return cdnUrl;
    }
    if (assetPath != null) {
      return 'packages/ripple/assets/animated_emojis/$assetPath';
    }
    return null;
  }
}

/// Registry of animated emojis. Add entries here (and drop the matching
/// asset files into `assets/animated_emojis/`) to extend the pack.
class AnimatedEmojiRegistry {
  static const _source = AnimatedEmojiSource.local;

  // Core reaction set — matches the reaction picker emojis, plus common
  // chat/feed emojis. Each entry keys off its raw Unicode glyph.
  static final Map<String, AnimatedEmoji> _byGlyph = {
    '❤️': const AnimatedEmoji(
      glyph: '❤️',
      assetPath: 'red_heart/red_heart_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/red_heart.webp',
    ),
    '😂': const AnimatedEmoji(
      glyph: '😂',
      assetPath: 'face_with_tears_of_joy/face_with_tears_of_joy_animated.webp',
      cdnUrl:
          'https://cdn.ripple.app/animated_emojis/face_with_tears_of_joy.webp',
    ),
    '😍': const AnimatedEmoji(
      glyph: '😍',
      assetPath: 'smiling_face_with_heart_eyes/smiling_face_with_heart_eyes_animated.webp',
      cdnUrl:
          'https://cdn.ripple.app/animated_emojis/smiling_face_with_heart_eyes.webp',
    ),
    '😮': const AnimatedEmoji(
      glyph: '😮',
      assetPath: 'face_with_open_mouth/face_with_open_mouth_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/face_with_open_mouth.webp',
    ),
    '😢': const AnimatedEmoji(
      glyph: '😢',
      assetPath: 'crying_face/crying_face_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/crying_face.webp',
    ),
    '😡': const AnimatedEmoji(
      glyph: '😡',
      assetPath: 'pouting_face/pouting_face_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/pouting_face.webp',
    ),
    '👍': const AnimatedEmoji(
      glyph: '👍',
      assetPath: 'thumbs_up/thumbs_up_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/thumbs_up.webp',
    ),
    '👎': const AnimatedEmoji(
      glyph: '👎',
      assetPath: 'thumbs_down/thumbs_down_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/thumbs_down.webp',
    ),
    '🔥': const AnimatedEmoji(
      glyph: '🔥',
      assetPath: 'fire/fire_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/fire.webp',
    ),
    '😎': const AnimatedEmoji(
      glyph: '😎',
      assetPath: 'smiling_face_with_sunglasses/smiling_face_with_sunglasses_animated.webp',
      cdnUrl:
          'https://cdn.ripple.app/animated_emojis/smiling_face_with_sunglasses.webp',
    ),
    '🤔': const AnimatedEmoji(
      glyph: '🤔',
      assetPath: 'thinking_face/thinking_face_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/thinking_face.webp',
    ),
    '🎉': const AnimatedEmoji(
      glyph: '🎉',
      assetPath: 'party_popper/party_popper_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/party_popper.webp',
    ),
    '🙌': const AnimatedEmoji(
      glyph: '🙌',
      assetPath: 'raising_hands/raising_hands_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/raising_hands.webp',
    ),
    '💯': const AnimatedEmoji(
      glyph: '💯',
      assetPath: 'hundred_points/hundred_points_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/hundred_points.webp',
    ),
    '🥺': const AnimatedEmoji(
      glyph: '🥺',
      assetPath: 'pleading_face/pleading_face_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/pleading_face.webp',
    ),
    '😴': const AnimatedEmoji(
      glyph: '😴',
      assetPath: 'sleeping_face/sleeping_face_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/sleeping_face.webp',
    ),
    '🤩': const AnimatedEmoji(
      glyph: '🤩',
      assetPath: 'star_struck/star_struck_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/star_struck.webp',
    ),
    '😘': const AnimatedEmoji(
      glyph: '😘',
      assetPath: 'face_blowing_a_kiss/face_blowing_a_kiss_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/face_blowing_a_kiss.webp',
    ),
    '😱': const AnimatedEmoji(
      glyph: '😱',
      assetPath: 'face_screaming_in_fear/face_screaming_in_fear_animated.webp',
      cdnUrl:
          'https://cdn.ripple.app/animated_emojis/face_screaming_in_fear.webp',
    ),
    '🤯': const AnimatedEmoji(
      glyph: '🤯',
      assetPath: 'exploding_head/exploding_head_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/exploding_head.webp',
    ),
    '🤬': const AnimatedEmoji(
      glyph: '🤬',
      assetPath: 'face_with_symbols_on_mouth/face_with_symbols_on_mouth_animated.webp',
      cdnUrl:
          'https://cdn.ripple.app/animated_emojis/face_with_symbols_on_mouth.webp',
    ),
    '😅': const AnimatedEmoji(
      glyph: '😅',
      assetPath: 'grinning_face_with_sweat/grinning_face_with_sweat_animated.webp',
      cdnUrl:
          'https://cdn.ripple.app/animated_emojis/grinning_face_with_sweat.webp',
    ),
    '😉': const AnimatedEmoji(
      glyph: '😉',
      assetPath: 'winking_face/winking_face_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/winking_face.webp',
    ),
    '🙏': const AnimatedEmoji(
      glyph: '🙏',
      assetPath: 'folded_hands/folded_hands_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/folded_hands.webp',
    ),
    '💪': const AnimatedEmoji(
      glyph: '💪',
      assetPath: 'flexed_biceps/flexed_biceps_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/flexed_biceps.webp',
    ),
    '🎊': const AnimatedEmoji(
      glyph: '🎊',
      assetPath: 'confetti_ball/confetti_ball_animated.webp',
      cdnUrl: 'https://cdn.ripple.app/animated_emojis/confetti_ball.webp',
    ),
  };

  /// Look up an animated emoji by its raw Unicode glyph.
  static AnimatedEmoji? byGlyph(String glyph) => _byGlyph[glyph];

  /// All registered emojis.
  static Iterable<AnimatedEmoji> get all => _byGlyph.values;

  /// Whether a glyph has an animated replacement registered.
  static bool has(String glyph) => _byGlyph.containsKey(glyph);

  /// Current asset source (local vs cdn).
  static AnimatedEmojiSource get source => _source;
}

/// A single animated emoji rendered inline.
///
/// Uses Flutter's `Image` widget which natively plays animated WebP and GIF.
/// Falls back to the raw Unicode `Text` glyph when no animated asset is
/// available (graceful degradation).
class AnimatedEmojiInline extends StatelessWidget {
  /// The raw Unicode emoji character.
  final String glyph;

  /// Rendered size (height/width).
  final double size;

  /// Whether to loop indefinitely (true) or play once then pause on the last
  /// frame (false). Defaults to true for emojis in feeds/pickers.
  final bool loop;

  const AnimatedEmojiInline({
    super.key,
    required this.glyph,
    this.size = 24,
    this.loop = true,
  }) : assert(size > 0);

  @override
  Widget build(BuildContext context) {
    final emoji = AnimatedEmojiRegistry.byGlyph(glyph);
    final resolved =
        emoji?.resolve(source: AnimatedEmojiRegistry.source) ??
            (emoji != null ? emoji.assetPath : null);

    if (resolved == null || resolved.isEmpty) {
      // No animated asset — fall back to system emoji text.
      return Text(
        glyph,
        style: TextStyle(fontSize: size),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        resolved,
        width: size,
        height: size,
        fit: BoxFit.contain,
        // `Image.asset` plays animated WebP/GIF automatically. `repeat` is
        // `ImageRepeat.noRepeat` by default; for non-looping we rely on the
        // asset's own frame count.
        package: 'ripple',
        errorBuilder: (_, __, ___) {
          // Asset missing — fall back to system emoji so the UI never breaks.
          return Text(
            glyph,
            style: TextStyle(fontSize: size),
          );
        },
      ),
    );
  }
}

/// Replaces supported Unicode emojis in a text run with animated versions,
/// one span per segment, leaving unsupported characters as system text.
///
/// Use this wherever user-generated text is rendered (post captions,
/// comments, DMs, bios) to get animated emojis app-wide.
class AnimatedEmojiText extends StatelessWidget {
  final String data;
  final TextStyle style;
  final double emojiSize;
  final bool loop;

  const AnimatedEmojiText({
    super.key,
    required this.data,
    required this.style,
    this.emojiSize = 20,
    this.loop = true,
  });

  @override
  Widget build(BuildContext context) {
    // Unicode emoji regex: matches most common emoji codepoint ranges plus
    // ZWJ sequences and skin-tone modifiers.
    final emojiRegex = RegExp(
      r'(\p{Extended_Pictographic}|\p{Emoji}\uFE0F?|\u200D|\u{1F3FB}-\u{1F3FF})',
      unicode: true,
      caseSensitive: false,
    );

    final spans = <TextSpan>[];
    var lastIndex = 0;

    for (final match in emojiRegex.allMatches(data)) {
      // Text before this emoji.
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: data.substring(lastIndex, match.start),
          style: style,
        ));
      }

      final glyph = match.group(0) ?? '';
      final animated = AnimatedEmojiRegistry.has(glyph)
          ? WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: AnimatedEmojiInline(
                glyph: glyph,
                size: emojiSize,
                loop: loop,
              ),
            )
          : TextSpan(text: glyph, style: style);

      spans.add(animated);
      lastIndex = match.end;
    }

    // Remaining text after the last emoji.
    if (lastIndex < data.length) {
      spans.add(TextSpan(
        text: data.substring(lastIndex),
        style: style,
      ));
    }

    if (spans.isEmpty) {
      return Text(data, style: style);
    }

    return RichText(text: TextSpan(children: spans));
  }
}
