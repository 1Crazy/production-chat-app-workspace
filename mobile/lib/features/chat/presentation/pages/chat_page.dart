import 'package:flutter/material.dart';
import 'package:production_chat_app/features/chat/application/chat_controller.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_read_receipt_member.dart';
import 'package:production_chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:production_chat_app/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/features/profile/presentation/pages/member_profile_page.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/widgets/status_surfaces.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.accessToken,
    required this.currentUserId,
    required this.chatRepository,
    required this.chatRealtime,
    this.topBanner,
    required this.onBackToConversationList,
    required this.onConversationChanged,
    required this.onOpenDirectConversation,
    required this.reloadToken,
    this.selectedConversation,
  });

  final String accessToken;
  final String currentUserId;
  final ChatRepository chatRepository;
  final ChatRealtime chatRealtime;
  final Widget? topBanner;
  final VoidCallback onBackToConversationList;
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
  bool _showQuickPanel = false;

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
    setState(() {
      _showQuickPanel = false;
    });
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
        return DecoratedBox(
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            children: [
              _ChatHeader(
                title: selectedConversation.title,
                memberCount: selectedConversation.memberCount,
                onBack: widget.onBackToConversationList,
              ),
              if (widget.topBanner != null) widget.topBanner!,
              Expanded(
                child: _controller.isInitialLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
                        itemCount: _controller.messages.length,
                        itemBuilder: (context, index) {
                          final message = _controller.messages[index];
                          final previousMessage = index > 0
                              ? _controller.messages[index - 1]
                              : null;

                          return Column(
                            children: [
                              if (_shouldShowDateDivider(
                                previousMessage,
                                message,
                              ))
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 12,
                                  ),
                                  child: _ChatDateDivider(
                                    dateTime: message.createdAt,
                                  ),
                                ),
                              ChatMessageBubble(
                                message: message,
                                isMine: message.belongsTo(widget.currentUserId),
                                statusCaption: _controller
                                    .readReceiptCaptionFor(message),
                                onAvatarTap: () {
                                  final member = _controller.memberForMessage(
                                    message,
                                  );

                                  if (member == null) {
                                    return;
                                  }

                                  _openMemberProfile(context, member);
                                },
                                onShowReadMembers:
                                    _controller
                                        .readReceiptPanelMembersFor(message)
                                        .isNotEmpty
                                    ? () {
                                        _showReadMembersSheet(
                                          context,
                                          _controller
                                              .readReceiptPanelMembersFor(
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
                            ],
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                        padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const _CircleActionIcon(
                              icon: Icons.multitrack_audio_rounded,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F6FA),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: TextField(
                                  controller: _composerController,
                                  minLines: 1,
                                  maxLines: 3,
                                  textInputAction: TextInputAction.send,
                                  onChanged: (value) {
                                    if (_showQuickPanel && value.isNotEmpty) {
                                      setState(() {
                                        _showQuickPanel = false;
                                      });
                                    }
                                    _controller.updateTypingDraft(value);
                                  },
                                  onSubmitted: (_) {
                                    _handleSend();
                                  },
                                  decoration: const InputDecoration(
                                    hintText: '输入消息...',
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const _CircleActionIcon(
                              icon: Icons.emoji_emotions_outlined,
                            ),
                            const SizedBox(width: 6),
                            _CircleActionIcon(
                              icon: _showQuickPanel
                                  ? Icons.close_rounded
                                  : Icons.add_rounded,
                              onTap: () async {
                                setState(() {
                                  _showQuickPanel = !_showQuickPanel;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: const _ChatQuickPanel(),
                        crossFadeState: _showQuickPanel
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 180),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
      subtitle: Text(member.hasRead ? '已读这条消息' : '尚未读到这条消息'),
      trailing: Text(member.hasRead ? '已读' : '未读'),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.displayName, required this.avatarUrl});

  final String displayName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return _RoundedMemberAvatarPlaceholder(displayName: displayName);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        avatarUrl!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _RoundedMemberAvatarPlaceholder(displayName: displayName);
        },
      ),
    );
  }
}

class _RoundedMemberAvatarPlaceholder extends StatelessWidget {
  const _RoundedMemberAvatarPlaceholder({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(displayName.characters.first),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.title,
    required this.memberCount,
    required this.onBack,
  });

  final String title;
  final int memberCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            _HeaderIconButton(icon: Icons.chevron_left_rounded, onTap: onBack),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  if (memberCount > 2)
                    Text(
                      '$memberCount人',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF9AA4B2),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const _HeaderIconButton(icon: Icons.more_horiz_rounded),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 24,
        height: 24,
        child: Icon(icon, size: 20, color: const Color(0xFF111827)),
      ),
    );
  }
}

class _ChatDateDivider extends StatelessWidget {
  const _ChatDateDivider({required this.dateTime});

  final DateTime dateTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _formatChatDate(dateTime),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: const Color(0xFF98A2B3)),
      ),
    );
  }
}

bool _shouldShowDateDivider(ChatMessage? previous, ChatMessage current) {
  if (previous == null) {
    return true;
  }

  final left = previous.createdAt;
  final right = current.createdAt;

  return left.year != right.year ||
      left.month != right.month ||
      left.day != right.day;
}

String _formatChatDate(DateTime dateTime) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final difference = today.difference(target).inDays;

  if (difference == 0) {
    return '今天';
  }

  if (difference == 1) {
    return '昨天';
  }

  return '${dateTime.month}/${dateTime.day}';
}

class _CircleActionIcon extends StatelessWidget {
  const _CircleActionIcon({required this.icon, this.onTap});

  final IconData icon;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null
          ? null
          : () async {
              await onTap!();
            },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, size: 17, color: const Color(0xFF3C4658)),
      ),
    );
  }
}

class _ChatQuickPanel extends StatelessWidget {
  const _ChatQuickPanel();

  @override
  Widget build(BuildContext context) {
    const actions = [
      (Icons.image_outlined, '照片'),
      (Icons.camera_alt_outlined, '拍摄'),
      (Icons.videocam_outlined, '视频'),
      (Icons.calendar_today_outlined, '日程'),
      (Icons.star_border_rounded, '收藏'),
      (Icons.folder_open_outlined, '文件'),
      (Icons.description_outlined, '文档'),
      (Icons.bar_chart_rounded, '投票'),
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 16,
        children: [
          for (final action in actions)
            SizedBox(
              width: (MediaQuery.of(context).size.width - 16 * 2 - 8 * 3) / 4,
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F4F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(action.$1, color: const Color(0xFF667085)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action.$2,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: AppEmptyStateCard(
          title: '未选择会话',
          description: '请先从消息列表中选择一个会话。',
          icon: Icons.chat_bubble_outline_rounded,
        ),
      ),
    );
  }
}
