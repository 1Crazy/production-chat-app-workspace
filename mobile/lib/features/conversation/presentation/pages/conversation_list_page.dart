import 'package:flutter/material.dart';
import 'package:production_chat_app/features/conversation/application/conversation_list_controller.dart';
import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/widgets/status_surfaces.dart';

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
    this.topBanner,
    this.onComposeTap,
    this.onItemsChanged,
    this.selectedConversationId,
  });

  final String accessToken;
  final ConversationRepository conversationRepository;
  final ChatRealtime chatRealtime;
  final String currentUserId;
  final ValueChanged<ConversationSummary> onConversationSelected;
  final Widget? topBanner;
  final Future<void> Function()? onComposeTap;
  final ValueChanged<List<ConversationSummary>>? onItemsChanged;
  final String? selectedConversationId;
  final bool isVisible;
  final int reloadToken;

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  late ConversationListController _controller;
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _controller = ConversationListController(
      conversationRepository: widget.conversationRepository,
      chatRealtime: widget.chatRealtime,
      accessToken: widget.accessToken,
      currentUserId: widget.currentUserId,
      activeConversationId: widget.selectedConversationId,
      onItemsChanged: widget.onItemsChanged,
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
        onItemsChanged: widget.onItemsChanged,
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
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final filteredItems = _controller.items
            .where((item) {
              final query = _searchQuery.trim().toLowerCase();

              if (query.isEmpty) {
                return true;
              }

              return item.title.toLowerCase().contains(query) ||
                  item.lastMessagePreview.toLowerCase().contains(query);
            })
            .toList(growable: false);

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

        return DecoratedBox(
          decoration: const BoxDecoration(color: Colors.white),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '消息',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(fontSize: 28),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _HeaderActionButton(
                        icon: Icons.add_rounded,
                        onTap: widget.onComposeTap,
                      ),
                    ],
                  ),
                ),
                if (widget.topBanner != null) widget.topBanner!,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: _ConversationSearchBar(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _controller.load(silent: true),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
                      itemCount: filteredItems.isEmpty
                          ? 1
                          : filteredItems.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        indent: 84,
                        color: Color(0xFFF1F3F7),
                      ),
                      itemBuilder: (context, index) {
                        if (filteredItems.isEmpty) {
                          return const _ConversationListEmptyState();
                        }

                        final item = filteredItems[index];
                        final isSelected =
                            item.id == widget.selectedConversationId;

                        return _ConversationListItem(
                          item: item,
                          isSelected: isSelected,
                          onTap: () {
                            widget.onConversationSelected(item);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
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
            AppInlineNotice(message: message, tone: AppStatusTone.error),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ),
      ),
    );
  }
}

class _ConversationSearchBar extends StatelessWidget {
  const _ConversationSearchBar({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF9AA4B2)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: '搜索',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationListItem extends StatelessWidget {
  const _ConversationListItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final ConversationSummary item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.zero,
      child: Ink(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF7F9FD) : Colors.white,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                _ConversationAvatar(item: item),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatConversationTimestamp(item),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.lastMessagePreview.isEmpty
                                  ? '暂无消息，开始聊点什么吧'
                                  : item.lastMessagePreview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF9CA3AF)),
                            ),
                          ),
                          if (item.unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              constraints: const BoxConstraints(minWidth: 20),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF4D4F),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(999),
                                ),
                              ),
                              child: Text(
                                '${item.unreadCount}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.item});

  final ConversationSummary item;

  @override
  Widget build(BuildContext context) {
    final visual = _ConversationAvatarVisual.fromItem(item);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: visual.background,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: visual.icon != null
          ? Icon(visual.icon, color: visual.foreground, size: 24)
          : Text(
              item.title.characters.first,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: visual.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _ConversationAvatarVisual {
  const _ConversationAvatarVisual({
    required this.background,
    required this.foreground,
    this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData? icon;

  static _ConversationAvatarVisual fromItem(ConversationSummary item) {
    final title = item.title;

    if (title.contains('文件')) {
      return const _ConversationAvatarVisual(
        background: Color(0xFFE9FFF6),
        foreground: Color(0xFF12B76A),
        icon: Icons.description_outlined,
      );
    }

    if (title.contains('系统') || title.contains('通知')) {
      return const _ConversationAvatarVisual(
        background: Color(0xFFEAF1FF),
        foreground: Color(0xFF2F6BFF),
        icon: Icons.notifications_none_rounded,
      );
    }

    if (item.type == 'group') {
      return const _ConversationAvatarVisual(
        background: Color(0xFFFFF1D8),
        foreground: Color(0xFFE59B00),
        icon: Icons.groups_2_rounded,
      );
    }

    return const _ConversationAvatarVisual(
      background: Color(0xFFEAF1FF),
      foreground: Color(0xFF2F6BFF),
    );
  }
}

class _ConversationListEmptyState extends StatelessWidget {
  const _ConversationListEmptyState();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyStateCard(
      title: '暂无会话',
      description: '点击右上角 + 添加好友，或创建群聊。',
      icon: Icons.forum_outlined,
    );
  }
}

String _formatConversationTimestamp(ConversationSummary summary) {
  final value = summary.lastMessageAt ?? summary.updatedAt;
  final now = DateTime.now();

  if (now.year == value.year &&
      now.month == value.month &&
      now.day == value.day) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  final difference = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(value.year, value.month, value.day)).inDays;

  if (difference == 1) {
    return '昨天';
  }

  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  if (difference > 1 && difference < 7) {
    return '星期${weekdays[value.weekday - 1]}';
  }

  return '${value.month}/${value.day}';
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({required this.icon, this.onTap});

  final IconData icon;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap == null
          ? null
          : () async {
              await onTap!();
            },
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(icon, color: const Color(0xFF111827)),
      ),
    );
  }
}
