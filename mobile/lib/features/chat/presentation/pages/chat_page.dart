import 'package:flutter/material.dart';
import 'package:production_chat_app/features/chat/application/chat_controller.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_read_receipt_member.dart';
import 'package:production_chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:production_chat_app/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/features/profile/presentation/pages/member_profile_page.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime_event.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.accessToken,
    required this.currentUserId,
    required this.chatRepository,
    required this.chatRealtime,
    required this.onConversationChanged,
    required this.onOpenDirectConversation,
    required this.reloadToken,
    this.selectedConversation,
  });

  final String accessToken;
  final String currentUserId;
  final ChatRepository chatRepository;
  final ChatRealtime chatRealtime;
  final ConversationSummary? selectedConversation;
  final VoidCallback onConversationChanged;
  final Future<void> Function(String handle) onOpenDirectConversation;
  final int reloadToken;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late ChatController _controller;
  late TextEditingController _composerController;

  @override
  void initState() {
    super.initState();
    _controller = ChatController(
      chatRepository: widget.chatRepository,
      chatRealtime: widget.chatRealtime,
      accessToken: widget.accessToken,
      currentUserId: widget.currentUserId,
    );
    _composerController = TextEditingController();
    _syncSelectedConversation(initial: true);
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.chatRepository != widget.chatRepository ||
        oldWidget.chatRealtime != widget.chatRealtime ||
        oldWidget.currentUserId != widget.currentUserId) {
      _controller.dispose();
      _controller = ChatController(
        chatRepository: widget.chatRepository,
        chatRealtime: widget.chatRealtime,
        accessToken: widget.accessToken,
        currentUserId: widget.currentUserId,
      );
      _syncSelectedConversation(initial: true);
      return;
    }

    if (oldWidget.accessToken != widget.accessToken) {
      _controller.updateAccessToken(widget.accessToken);
    }

    if (oldWidget.selectedConversation?.id != widget.selectedConversation?.id) {
      _composerController.clear();
      _syncSelectedConversation();
      return;
    }

    if (oldWidget.reloadToken != widget.reloadToken &&
        widget.selectedConversation != null) {
      _refreshActiveConversation();
    }
  }

  @override
  void dispose() {
    _composerController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _syncSelectedConversation({bool initial = false}) async {
    final conversation = widget.selectedConversation;

    if (conversation == null) {
      if (!initial) {
        setState(() {});
      }
      return;
    }

    await _controller.openConversation(conversation);
    widget.onConversationChanged();
  }

  Future<void> _handleSend() async {
    final text = _composerController.text;

    if (text.trim().isEmpty) {
      return;
    }

    _composerController.clear();
    await _controller.updateTypingDraft('');
    await _controller.sendText(text);
    widget.onConversationChanged();
  }

  Future<void> _refreshActiveConversation() async {
    await _controller.refreshGapSync();
    widget.onConversationChanged();
  }

  @override
  Widget build(BuildContext context) {
    final selectedConversation = widget.selectedConversation;

    if (selectedConversation == null) {
      return const _ChatEmptyState();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          children: [
            _ChatHeader(
              title: selectedConversation.title,
              connectionState: _controller.connectionState,
              onRefresh: () async {
                await _refreshActiveConversation();
              },
            ),
            if (_controller.isPeerTyping)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '对方正在输入...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            if (_controller.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_controller.errorMessage!),
                  ),
                ),
              ),
            Expanded(
              child: _controller.isInitialLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _refreshActiveConversation();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _controller.messages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Center(
                                child: _controller.hasOlder
                                    ? TextButton(
                                        onPressed: _controller.isLoadingOlder
                                            ? null
                                            : () async {
                                                await _controller.loadOlder();
                                              },
                                        child: Text(
                                          _controller.isLoadingOlder
                                              ? '加载中...'
                                              : '加载更早消息',
                                        ),
                                      )
                                    : const Text('没有更早的消息了'),
                              ),
                            );
                          }

                          final message = _controller.messages[index - 1];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ChatMessageBubble(
                              message: message,
                              isMine: message.belongsTo(widget.currentUserId),
                              statusCaption: _controller.readReceiptCaptionFor(
                                message,
                              ),
                              onShowReadMembers:
                                  _controller
                                      .readReceiptPanelMembersFor(message)
                                      .isNotEmpty
                                  ? () {
                                      _showReadMembersSheet(
                                        context,
                                        _controller.readReceiptPanelMembersFor(
                                          message,
                                        ),
                                      );
                                    }
                                  : null,
                              onRetry:
                                  message.deliveryState ==
                                      ChatMessageDeliveryState.failed
                                  ? () async {
                                      await _controller.retryMessage(
                                        message.clientMessageId,
                                      );
                                      widget.onConversationChanged();
                                    }
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _composerController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onChanged: (value) {
                          _controller.updateTypingDraft(value);
                        },
                        onSubmitted: (_) {
                          _handleSend();
                        },
                        decoration: const InputDecoration(
                          hintText: '输入消息',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _controller.isSending ? null : _handleSend,
                      child: Text(_controller.isSending ? '发送中' : '发送'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showReadMembersSheet(
    BuildContext context,
    List<ChatReadReceiptMember> members,
  ) {
    final readMembers = members.where((member) => member.hasRead).toList();

    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('已读成员', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (readMembers.isNotEmpty) ...[
                  Text('已读 (${readMembers.length})'),
                  const SizedBox(height: 8),
                  for (final member in readMembers)
                    _ReadMemberTile(
                      member: member,
                      onTap: () {
                        Navigator.of(context).pop();
                        _openMemberProfile(context, member);
                      },
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMemberProfile(
    BuildContext context,
    ChatReadReceiptMember member,
  ) async {
    final handle = await Navigator.of(context).push<String?>(
      MaterialPageRoute<String?>(
        builder: (context) {
          return MemberProfilePage(member: member);
        },
      ),
    );

    if (!mounted || handle == null) {
      return;
    }

    await widget.onOpenDirectConversation(handle);
  }
}

class _ReadMemberTile extends StatelessWidget {
  const _ReadMemberTile({required this.member, this.onTap});

  final ChatReadReceiptMember member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: _MemberAvatar(
        displayName: member.displayName,
        avatarUrl: member.avatarUrl,
      ),
      title: Text(member.displayName),
      titleTextStyle: Theme.of(context).textTheme.bodyLarge,
      subtitle: Text(
        member.readAt == null
            ? '尚未读到这条消息'
            : _formatRelativeReadAt(member.readAt!),
      ),
      trailing: Text(member.hasRead ? '已读' : '未读'),
    );
  }
}

String _formatRelativeReadAt(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inSeconds < 60) {
    return '刚刚已读';
  }

  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} 分钟前已读';
  }

  if (difference.inHours < 24) {
    return '${difference.inHours} 小时前已读';
  }

  if (difference.inDays < 7) {
    return '${difference.inDays} 天前已读';
  }

  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute 已读';
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.displayName, required this.avatarUrl});

  final String displayName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return CircleAvatar(child: Text(displayName.characters.first));
    }

    return ClipOval(
      child: Image.network(
        avatarUrl!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return CircleAvatar(child: Text(displayName.characters.first));
        },
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.title,
    required this.connectionState,
    required this.onRefresh,
  });

  final String title;
  final ChatRealtimeConnectionState connectionState;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(switch (connectionState) {
                  ChatRealtimeConnectionState.connected => '实时在线',
                  ChatRealtimeConnectionState.connecting => '实时连接中',
                  ChatRealtimeConnectionState.disconnected => '实时已断开',
                }, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              onRefresh();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('先从会话列表选择一个会话'));
  }
}
