import 'package:flutter/material.dart';
import 'package:production_chat_app/features/conversation/application/conversation_list_controller.dart';
import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';

class ConversationListPage extends StatefulWidget {
  const ConversationListPage({
    super.key,
    required this.accessToken,
    required this.conversationRepository,
    required this.chatRealtime,
    required this.currentUserId,
    required this.onConversationSelected,
    required this.isVisible,
    required this.reloadToken,
    this.selectedConversationId,
  });

  final String accessToken;
  final ConversationRepository conversationRepository;
  final ChatRealtime chatRealtime;
  final String currentUserId;
  final ValueChanged<ConversationSummary> onConversationSelected;
  final String? selectedConversationId;
  final bool isVisible;
  final int reloadToken;

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  late ConversationListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConversationListController(
      conversationRepository: widget.conversationRepository,
      chatRealtime: widget.chatRealtime,
      accessToken: widget.accessToken,
      currentUserId: widget.currentUserId,
      activeConversationId: widget.selectedConversationId,
    );
    _controller.load();
  }

  @override
  void didUpdateWidget(covariant ConversationListPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.conversationRepository != widget.conversationRepository ||
        oldWidget.chatRealtime != widget.chatRealtime ||
        oldWidget.currentUserId != widget.currentUserId) {
      _controller.dispose();
      _controller = ConversationListController(
        conversationRepository: widget.conversationRepository,
        chatRealtime: widget.chatRealtime,
        accessToken: widget.accessToken,
        currentUserId: widget.currentUserId,
        activeConversationId: widget.selectedConversationId,
      );
      _controller.load();
      return;
    }

    if (oldWidget.accessToken != widget.accessToken) {
      _controller.updateAccessToken(widget.accessToken);
    }

    if (oldWidget.selectedConversationId != widget.selectedConversationId) {
      _controller.updateActiveConversationId(widget.selectedConversationId);
    }

    if (widget.reloadToken != oldWidget.reloadToken ||
        (widget.isVisible && !oldWidget.isVisible)) {
      _controller.load(silent: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.isLoading && _controller.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.errorMessage != null && _controller.items.isEmpty) {
          return _ConversationListErrorState(
            message: _controller.errorMessage!,
            onRetry: () {
              _controller.load();
            },
          );
        }

        return RefreshIndicator(
          onRefresh: () => _controller.load(silent: true),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _controller.items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _controller.items[index];
              final isSelected = item.id == widget.selectedConversationId;

              return ListTile(
                tileColor: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(item.title),
                subtitle: Text(
                  item.lastMessagePreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: item.unreadCount > 0
                    ? CircleAvatar(
                        radius: 12,
                        child: Text(
                          '${item.unreadCount}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: () {
                  widget.onConversationSelected(item);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _ConversationListErrorState extends StatelessWidget {
  const _ConversationListErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ),
      ),
    );
  }
}
