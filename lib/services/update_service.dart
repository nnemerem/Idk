import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ripple/config/constants.dart';

/// Result of an update check against the repo's latest GitHub release.
class ReleaseUpdate {
  final String tag;
  final String url;
  final bool isNewer;

  const ReleaseUpdate({
    required this.tag,
    required this.url,
    required this.isNewer,
  });
}

/// Checks the repo's latest published GitHub release against the app's
/// built-in version. Non-destructive and never throws — a failed check
/// simply returns null.
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static const String _repoApiUrl =
      'https://api.github.com/repos/nnemerem/Ripple/releases/latest';
  static const String _fallbackUrl =
      'https://github.com/nnemerem/Ripple/releases/latest';

  static const Duration _timeout = Duration(seconds: 10);

  Future<ReleaseUpdate?> checkForUpdate() async {
    try {
      final response = await http
          .get(
            Uri.parse(_repoApiUrl),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Ripple',
            },
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;

      final tag = body['tag_name'] as String?;
      final url = body['html_url'] as String?;
      if (tag == null || tag.isEmpty) return null;

      return ReleaseUpdate(
        tag: tag,
        url: (url != null && url.isNotEmpty) ? url : _fallbackUrl,
        isNewer: isNewerThan(tag, RippleConstants.appVersion),
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns true when [tag] names a version newer than [current].
  /// Versions are compared on (major, minor, patch), ignoring build
  /// metadata (e.g. `1.0.0+1`).
  static bool isNewerThan(String tag, String current) {
    final t = _parseVersion(tag);
    final c = _parseVersion(current);
    if (t == null || c == null) return false;
    for (var i = 0; i < 3; i++) {
      if (t[i] != c[i]) return t[i] > c[i];
    }
    return false;
  }

  static List<int>? _parseVersion(String v) {
    var clean = v.trim().toLowerCase();
    if (clean.startsWith('v')) clean = clean.substring(1);
    clean = clean.split('+').first.split('-').first;
    final parts = clean.split('.');
    if (parts.length != 3) return null;
    final result = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null) return null;
      result.add(n);
    }
    return result;
  }
}
