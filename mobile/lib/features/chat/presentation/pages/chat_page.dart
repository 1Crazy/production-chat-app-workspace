import 'package:flutter/material.dart';
import 'package:production_chat_app/features/chat/application/chat_controller.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_read_receipt_member.dart';
import 'package:production_chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:production_chat_app/features/chat/presentation/chat_time_format.dart';
import 'package:production_chat_app/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/features/friendship/presentation/pages/relationship_profile_page.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/widgets/status_surfaces.dart';

part 'chat_page_widgets.dart';

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
  late ScrollController _messageScrollController;
  late ScrollController _composerScrollController;
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
    _messageScrollController = ScrollController();
    _composerScrollController = ScrollController();
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
    _composerScrollController.dispose();
    _messageScrollController.dispose();
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
    _scrollToLatestAfterBuild();
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
    final sendFuture = _controller.sendText(text);
    _scrollToLatestAfterBuild(animated: true);
    await sendFuture;
    _scrollToLatestAfterBuild(animated: true);
    widget.onConversationChanged();
  }

  Future<void> _refreshActiveConversation() async {
    await _controller.refreshGapSync();
    _scrollToLatestAfterBuild(animated: true);
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
                        controller: _messageScrollController,
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
                                constraints: const BoxConstraints(
                                  minHeight: 40,
                                  maxHeight: 224,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F6FA),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: TextField(
                                  controller: _composerController,
                                  scrollController: _composerScrollController,
                                  minLines: 1,
                                  maxLines: 11,
                                  keyboardType: TextInputType.multiline,
                                  textAlignVertical: TextAlignVertical.center,
                                  textInputAction: TextInputAction.send,
                                  style: const TextStyle(height: 1.2),
                                  strutStyle: const StrutStyle(
                                    height: 1.2,
                                    forceStrutHeight: true,
                                  ),
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
                                    hintStyle: TextStyle(height: 1.2),
                                    isDense: true,
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
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
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (context) {
          return RelationshipProfilePage(
            handle: member.handle,
            displayName: member.displayName,
            avatarUrl: member.avatarUrl,
          );
        },
      ),
    );

    if (!mounted || result == null || result == true) {
      return;
    }

    if (result is! String) {
      return;
    }

    await widget.onOpenDirectConversation(result);
  }

  void _scrollToLatestAfterBuild({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messageScrollController.hasClients) {
        return;
      }

      final targetOffset = _messageScrollController.position.maxScrollExtent;

      if (animated) {
        _messageScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
        return;
      }

      _messageScrollController.jumpTo(targetOffset);
    });
  }
}
