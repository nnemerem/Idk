import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';

/// Bottom sheet listing the users who liked a post or reel.
class LikesListSheet extends StatefulWidget {
  final String table;
  final String idColumn;
  final String id;

  const LikesListSheet({
    super.key,
    required this.table,
    required this.idColumn,
    required this.id,
  });

  static Future<void> show(
    BuildContext context, {
    required String table,
    required String idColumn,
    required String id,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LikesListSheet(table: table, idColumn: idColumn, id: id),
    );
  }

  @override
  State<LikesListSheet> createState() => _LikesListSheetState();
}

class _LikesListSheetState extends State<LikesListSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _likes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await SupabaseService().client
          .from(widget.table)
          .select('''
            user_id,
            profiles:user_id (id, username, display_name, avatar_url)
          ''')
          .eq(widget.idColumn, widget.id);

      if (mounted) {
        setState(() {
          _likes = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: RippleColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RippleConstants.borderRadiusXLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: RippleColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Liked by',
                style: TextStyle(
                  color: RippleColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const Divider(color: RippleColors.divider, height: 1),
          Flexible(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: RippleColors.primary),
                    ),
                  )
                : _likes.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No likes yet',
                            style: TextStyle(color: RippleColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shrinkWrap: true,
                        itemCount: _likes.length,
                        itemBuilder: (context, index) {
                          final like = _likes[index];
                          final profile = like['profiles'] as Map<String, dynamic>?;
                          final username = profile?['username'] as String? ?? 'unknown';
                          final avatarUrl = profile?['avatar_url'] as String?;
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: RippleColors.surfaceVariant,
                              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(avatarUrl)
                                  : null,
                              child: avatarUrl == null || avatarUrl.isEmpty
                                  ? Text(
                                      username[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: RippleColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              profile?['display_name'] ?? username,
                              style: const TextStyle(color: RippleColors.textPrimary),
                            ),
                            subtitle: Text(
                              '@$username',
                              style: const TextStyle(color: RippleColors.textSecondary),
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              context.go('/user/$username');
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
