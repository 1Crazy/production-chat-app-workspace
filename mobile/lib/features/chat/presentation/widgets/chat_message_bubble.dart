import 'package:flutter/material.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.statusCaption,
    this.onShowReadMembers,
    this.onRetry,
  });

  final ChatMessage message;
  final bool isMine;
  final String? statusCaption;
  final VoidCallback? onShowReadMembers;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (message.deliveryState) {
      ChatMessageDeliveryState.sending => '发送中',
      ChatMessageDeliveryState.sent => '已发送',
      ChatMessageDeliveryState.failed => '发送失败',
    };

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isMine
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderName,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                _ChatMessageBody(message: message),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      statusText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (message.deliveryState ==
                            ChatMessageDeliveryState.failed &&
                        onRetry != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          onRetry!();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                    if (statusCaption != null) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onShowReadMembers,
                        child: Text(
                          statusCaption!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMessageBody extends StatelessWidget {
  const _ChatMessageBody({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final textContent = message.textContent;

    if (textContent != null) {
      return Text(textContent.text);
    }

    final mediaContent = message.mediaContent;

    if (mediaContent == null) {
      return const Text('[消息]');
    }

    switch (mediaContent.attachmentKind) {
      case ChatMessageKind.image:
        return _ChatImageMessageCard(content: mediaContent);
      case ChatMessageKind.audio:
        return _ChatAudioMessageCard(content: mediaContent);
      case ChatMessageKind.file:
        return _ChatFileMessageCard(content: mediaContent);
      case ChatMessageKind.text:
        return Text(mediaContent.fileName);
    }
  }
}

class _ChatImageMessageCard extends StatelessWidget {
  const _ChatImageMessageCard({required this.content});

  final ChatMediaMessageContent content;

  @override
  Widget build(BuildContext context) {
    final statusTheme = _AttachmentVisualState.fromStatus(content.attachmentStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD8E8FF), Color(0xFFF5F9FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: statusTheme.borderColor),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        statusTheme.centerIcon,
                        size: 40,
                        color: statusTheme.accentColor,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          content.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: statusTheme.accentColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: _AttachmentStateBadge(theme: statusTheme),
              ),
              if (content.attachmentStatus ==
                  ChatMediaAttachmentStatus.processing)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _AttachmentMeta(content: content),
      ],
    );
  }
}

class _ChatAudioMessageCard extends StatelessWidget {
  const _ChatAudioMessageCard({required this.content});

  final ChatMediaMessageContent content;

  @override
  Widget build(BuildContext context) {
    final statusTheme = _AttachmentVisualState.fromStatus(content.attachmentStatus);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: statusTheme.backgroundColor,
        border: Border.all(color: statusTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: statusTheme.badgeBackgroundColor,
              child: Icon(
                statusTheme.centerIcon,
                color: statusTheme.accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AttachmentMeta(content: content),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatFileMessageCard extends StatelessWidget {
  const _ChatFileMessageCard({required this.content});

  final ChatMediaMessageContent content;

  @override
  Widget build(BuildContext context) {
    final statusTheme = _AttachmentVisualState.fromStatus(content.attachmentStatus);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: statusTheme.backgroundColor,
        border: Border.all(color: statusTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: statusTheme.badgeBackgroundColor,
              child: Icon(
                statusTheme.centerIcon,
                color: statusTheme.accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AttachmentMeta(content: content),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentMeta extends StatelessWidget {
  const _AttachmentMeta({required this.content});

  final ChatMediaMessageContent content;

  @override
  Widget build(BuildContext context) {
    final statusTheme = _AttachmentVisualState.fromStatus(content.attachmentStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          content.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '${content.mimeType} · ${_formatBytes(content.sizeBytes)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        _AttachmentStatusChip(status: content.attachmentStatus),
        if (statusTheme.helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            statusTheme.helperText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: statusTheme.accentColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _AttachmentStatusChip extends StatelessWidget {
  const _AttachmentStatusChip({required this.status});

  final ChatMediaAttachmentStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = _AttachmentVisualState.fromStatus(status);
    final label = switch (status) {
      ChatMediaAttachmentStatus.pendingUpload => '待上传',
      ChatMediaAttachmentStatus.processing => '处理中',
      ChatMediaAttachmentStatus.ready => '可用',
      ChatMediaAttachmentStatus.failed => '处理失败',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.badgeBackgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: theme.accentColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AttachmentStateBadge extends StatelessWidget {
  const _AttachmentStateBadge({required this.theme});

  final _AttachmentVisualState theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.badgeBackgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(theme.badgeIcon, size: 16, color: theme.accentColor),
      ),
    );
  }
}

class _AttachmentVisualState {
  const _AttachmentVisualState({
    required this.accentColor,
    required this.backgroundColor,
    required this.badgeBackgroundColor,
    required this.borderColor,
    required this.centerIcon,
    required this.badgeIcon,
    this.helperText,
  });

  final Color accentColor;
  final Color backgroundColor;
  final Color badgeBackgroundColor;
  final Color borderColor;
  final IconData centerIcon;
  final IconData badgeIcon;
  final String? helperText;

  static _AttachmentVisualState fromStatus(ChatMediaAttachmentStatus status) {
    switch (status) {
      case ChatMediaAttachmentStatus.pendingUpload:
        return const _AttachmentVisualState(
          accentColor: Color(0xFF7A5C00),
          backgroundColor: Color(0xFFFFF8D8),
          badgeBackgroundColor: Color(0xFFFFF0B3),
          borderColor: Color(0xFFE7D38A),
          centerIcon: Icons.schedule_send_outlined,
          badgeIcon: Icons.schedule_outlined,
          helperText: '附件还在等待上传完成',
        );
      case ChatMediaAttachmentStatus.processing:
        return const _AttachmentVisualState(
          accentColor: Color(0xFF0B63B6),
          backgroundColor: Color(0xFFE8F2FF),
          badgeBackgroundColor: Color(0xFFD6E8FF),
          borderColor: Color(0xFFB7D1F4),
          centerIcon: Icons.hourglass_top_rounded,
          badgeIcon: Icons.autorenew_rounded,
          helperText: '附件处理中，稍后可用',
        );
      case ChatMediaAttachmentStatus.ready:
        return const _AttachmentVisualState(
          accentColor: Color(0xFF1E7A34),
          backgroundColor: Color(0xFFE9F8EE),
          badgeBackgroundColor: Color(0xFFD7F0E0),
          borderColor: Color(0xFFB7DFBF),
          centerIcon: Icons.task_alt_rounded,
          badgeIcon: Icons.check_circle,
          helperText: '附件已处理完成',
        );
      case ChatMediaAttachmentStatus.failed:
        return const _AttachmentVisualState(
          accentColor: Color(0xFFB3261E),
          backgroundColor: Color(0xFFFFECE9),
          badgeBackgroundColor: Color(0xFFFFDAD6),
          borderColor: Color(0xFFF0B6B0),
          centerIcon: Icons.error_outline_rounded,
          badgeIcon: Icons.error,
          helperText: '附件处理失败，请稍后重试',
        );
    }
  }
}

String _formatBytes(int value) {
  if (value < 1024) {
    return '$value B';
  }

  if (value < 1024 * 1024) {
    return '${(value / 1024).toStringAsFixed(1)} KB';
  }

  return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
}
