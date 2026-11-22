import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';

/// Finds or creates a 1:1 conversation between the signed-in user and a
/// target user. Returns the conversation id (or null on failure).
class ConversationService {
  /// Start (or resume) a conversation with `targetUserId`.
  ///
  /// Uses the `conversations` + `conversation_participants` tables:
  /// a 1:1 thread is a conversation that contains the two user ids.
  static Future<String?> startConversation(String targetUserId) async {
    final currentUserId = SupabaseService().currentUser?.id;
    if (currentUserId == null || currentUserId == targetUserId) return null;

    try {
      final client = SupabaseService().client;

      // Already have a 1:1 thread with this user? Reuse it.
      final existing = await client
          .from(RippleConstants.tableConversations)
          .select('id, participants:conversation_participants!inner (user_id)')
          .eq('conversation_participants.user_id', currentUserId);

      for (final row in existing as List) {
        final participants = (row['participants'] as List?) ?? [];
        final userIds = participants
            .map((p) => (p as Map<String, dynamic>)['user_id'] as String?)
            .toSet();
        if (userIds.length == 2 && userIds.contains(targetUserId)) {
          return row['id'] as String;
        }
      }

      // Otherwise, create the thread and attach both participants.
      final created = await client
          .from(RippleConstants.tableConversations)
          .insert({'created_at': DateTime.now().toIso8601String()})
          .select('id')
          .single();

      final conversationId = created['id'] as String;

      await client.from(RippleConstants.tableConversationParticipants).insert([
        {
          'conversation_id': conversationId,
          'user_id': currentUserId,
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'conversation_id': conversationId,
          'user_id': targetUserId,
          'created_at': DateTime.now().toIso8601String(),
        },
      ]);

      return conversationId;
    } catch (e) {
      return null;
    }
  }
}
