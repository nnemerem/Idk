import 'package:flutter_test/flutter_test.dart';
import 'package:ripple/config/constants.dart';

void main() {
  group('RippleConstants.appInfo', () {
    test('appName is Ripple', () {
      expect(RippleConstants.appName, 'Ripple');
    });

    test('appVersion is 1.0.0', () {
      expect(RippleConstants.appVersion, '1.0.0');
    });
  });

  group('RippleConstants.tables', () {
    test('table names are non-empty strings', () {
      expect(RippleConstants.tableProfiles, isNotEmpty);
      expect(RippleConstants.tablePosts, isNotEmpty);
      expect(RippleConstants.tableReels, isNotEmpty);
      expect(RippleConstants.tableFollows, isNotEmpty);
      expect(RippleConstants.tablePostComments, isNotEmpty);
      expect(RippleConstants.tableReelComments, isNotEmpty);
    });

    test('reaction tables are defined', () {
      expect(RippleConstants.tablePostCommentReactions, 'post_comment_reactions');
      expect(RippleConstants.tableReelCommentReactions, 'reel_comment_reactions');
    });

    test('privacy tables are defined', () {
      expect(RippleConstants.tableBlockedAccounts, 'blocked_accounts');
      expect(RippleConstants.tableRestrictedAccounts, 'restricted_accounts');
    });
  });

  group('RippleConstants.pagination', () {
    test('defaultPageSize is 20', () {
      expect(RippleConstants.defaultPageSize, 20);
    });

    test('maxPageSize is 50', () {
      expect(RippleConstants.maxPageSize, 50);
    });
  });
}
