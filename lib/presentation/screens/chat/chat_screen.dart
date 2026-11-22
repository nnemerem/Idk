import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ripple/config/theme.dart';
import 'package:ripple/config/constants.dart';
import 'package:ripple/services/supabase_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _conversation;
  Map<String, dynamic>? _otherParticipant;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadConversation();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    try {
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null) return;

      // Get conversation details
      final convResponse = await SupabaseService().client
          .from(RippleConstants.tableConversations)
          .select('''
            *,
            participants:conversation_participants!inner (
              user_id,
              profiles:user_id (id, username, display_name, avatar_url)
            )
          ''')
          .eq('id', widget.conversationId)
          .single();

      _conversation = convResponse;

      // Find other participant
      final participants = convResponse['participants'] as List<dynamic>;
      final other = participants.firstWhere(
        (p) => p['user_id'] != currentUserId,
        orElse: () => null,
      );
      _otherParticipant = other?['profiles'] as Map<String, dynamic>?;

      // Get messages
      final msgResponse = await SupabaseService().client
          .from(RippleConstants.tableMessages)
          .select()
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true)
          .limit(50);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(msgResponse);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToMessages() {
    SupabaseService().client
        .from(RippleConstants.tableMessages)
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .listen((data) {
      if (mounted) {
        setState(() {
          _messages = data;
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: RippleConstants.animationFast,
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendImage(ImageSource source) async {
    final currentUserId = SupabaseService().currentUser?.id;
    if (currentUserId == null || _isSending) return;

    try {
      final xfile = await _picker.pickImage(source: source);
      if (xfile == null) return;

      setState(() => _isSending = true);

      final bytes = await xfile.readAsBytes();
      final extension = xfile.name.contains('.') ? xfile.name.split('.').last.toLowerCase() : 'jpg';
      final path = 'chat/$currentUserId/${DateTime.now().millisecondsSinceEpoch}.$extension';

      final url = await SupabaseService().uploadFile(
        bucket: RippleConstants.bucketPosts,
        path: path,
        bytes: bytes,
        contentType: xfile.mimeType ?? 'image/jpeg',
      );

      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image'), backgroundColor: RippleColors.error, behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }

      await SupabaseService().client.from(RippleConstants.tableMessages).insert({
        'conversation_id': widget.conversationId,
        'sender_id': currentUserId,
        'content': '',
        'media_url': url,
        'message_type': 'image',
        'created_at': DateTime.now().toIso8601String(),
      });

      await SupabaseService().client
          .from(RippleConstants.tableConversations)
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', widget.conversationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image'), backgroundColor: RippleColors.error, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    final currentUserId = SupabaseService().currentUser?.id;
    if (currentUserId == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await SupabaseService().client.from(RippleConstants.tableMessages).insert({
        'conversation_id': widget.conversationId,
        'sender_id': currentUserId,
        'content': content,
        'message_type': 'text',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update conversation timestamp
      await SupabaseService().client
          .from(RippleConstants.tableConversations)
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', widget.conversationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: RippleColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RippleColors.background,
      appBar: AppBar(
        title: _otherParticipant != null
            ? GestureDetector(
                onTap: () {
                  final username = _otherParticipant!['username'] as String?;
                  if (username != null) {
                    context.go('/user/$username');
                  }
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: RippleColors.surfaceVariant,
                      backgroundImage: _otherParticipant!['avatar_url'] != null
                          ? CachedNetworkImageProvider(_otherParticipant!['avatar_url'])
                          : null,
                      child: _otherParticipant!['avatar_url'] == null
                          ? Text(
                              _otherParticipant!['username']?[0]?.toUpperCase() ?? '?',
                              style: const TextStyle(
                                color: RippleColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _otherParticipant!['display_name'] ??
                          _otherParticipant!['username'] ??
                          'Unknown',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            : const Text('Chat'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: RippleColors.primary))
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isOwn = message['sender_id'] ==
                                SupabaseService().currentUser?.id;
                            return _buildMessageBubble(message, isOwn);
                          },
                        ),
                ),

                // Message input
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isOwn) {
    final content = message['content'] as String?;
    final createdAt = message['created_at'] as String?;
    final messageType = message['message_type'] as String? ?? 'text';

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isOwn
                    ? RippleColors.primary
                    : RippleColors.surfaceVariant,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isOwn ? 16 : 4),
                  bottomRight: Radius.circular(isOwn ? 4 : 16),
                ),
              ),
              child: messageType == 'image'
                  ? _buildImageMessage(message)
                  : Text(
                      content ?? '',
                      style: TextStyle(
                        color: isOwn
                            ? RippleColors.textOnPrimary
                            : RippleColors.textPrimary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (createdAt != null)
                    Text(
                      _formatTime(createdAt),
                      style: TextStyle(
                        color: RippleColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  if (isOwn) ...[
                    const SizedBox(width: 4),
                    SvgPicture.asset(
                      message['is_read'] == true
                          ? 'assets/icons/done_all.svg'
                          : 'assets/icons/check.svg',
                      width: 12,
                      height: 12,
                      colorFilter: ColorFilter.mode(
                        message['is_read'] == true
                            ? RippleColors.primary
                            : RippleColors.textTertiary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageMessage(Map<String, dynamic> message) {
    final mediaUrl = message['media_url'] as String?;
    if (mediaUrl == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: mediaUrl,
        fit: BoxFit.cover,
        width: 200,
        height: 200,
        placeholder: (context, url) => Container(
          width: 200,
          height: 200,
          color: RippleColors.surfaceVariant,
          child: Center(
            child: CircularProgressIndicator(color: RippleColors.primary),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 200,
          height: 200,
          color: RippleColors.surfaceVariant,
          child: SvgPicture.asset(
            'assets/icons/photo_library.svg',
            colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: RippleColors.background,
        border: Border(
          top: BorderSide(color: RippleColors.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: SvgPicture.asset(
                'assets/icons/photo_library.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(RippleColors.textSecondary, BlendMode.srcIn),
              ),
              onPressed: () => _sendImage(ImageSource.gallery),
            ),
            IconButton(
              icon: SvgPicture.asset(
                'assets/icons/camera.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(RippleColors.textSecondary, BlendMode.srcIn),
              ),
              onPressed: () => _sendImage(ImageSource.camera),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: RippleColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(RippleConstants.borderRadiusFull),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: RippleColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(color: RippleColors.textTertiary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: SvgPicture.asset(
                'assets/icons/send.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  _messageController.text.trim().isEmpty
                      ? RippleColors.textTertiary
                      : RippleColors.primary,
                  BlendMode.srcIn,
                ),
              ),
              onPressed: _messageController.text.trim().isEmpty || _isSending
                  ? null
                  : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${dateTime.day}/${dateTime.month}';
      } else if (difference.inHours > 0) {
        return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else {
        return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/chat.svg',
            width: 64,
            height: 64,
            colorFilter: ColorFilter.mode(RippleColors.textTertiary, BlendMode.srcIn),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: RippleColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RippleColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}