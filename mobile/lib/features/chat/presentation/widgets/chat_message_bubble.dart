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
    this.onAvatarTap,
  });

  final ChatMessage message;
  final bool isMine;
  final String? statusCaption;
  final VoidCallback? onShowReadMembers;
  final Future<void> Function()? onRetry;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (message.deliveryState) {
      ChatMessageDeliveryState.sending => '发送中',
      ChatMessageDeliveryState.sent => '已发送',
      ChatMessageDeliveryState.failed => '发送失败',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            _ChatAvatar(
              label: message.senderName,
              isMine: false,
              onTap: onAvatarTap,
            ),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.66,
              ),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMine) ...[
                    Text(
                      message.senderName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF98A2B3),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: isMine
                          ? const Color(0xFF3478F6)
                          : const Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(17),
                        topRight: const Radius.circular(17),
                        bottomLeft: Radius.circular(isMine ? 17 : 6),
                        bottomRight: Radius.circular(isMine ? 6 : 17),
                      ),
                      border: isMine
                          ? null
                          : Border.all(color: const Color(0xFFF0F2F7)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      child: DefaultTextStyle(
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: isMine
                              ? Colors.white
                              : const Color(0xFF101828),
                          height: 1.3,
                          fontSize: 15,
                        ),
                        child: _ChatMessageBody(
                          message: message,
                          isMine: isMine,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Padding(
                    padding: EdgeInsets.only(
                      left: isMine ? 0 : 4,
                      right: isMine ? 4 : 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (statusCaption != null) ...[
                          GestureDetector(
                            onTap: onShowReadMembers,
                            child: Text(
                              statusCaption!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFF98A2B3),
                                    fontSize: 11,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          statusText,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isMine
                                    ? const Color(0xFFAFC7FF)
                                    : const Color(0xFF98A2B3),
                                fontSize: 11,
                              ),
                        ),
                        if (message.deliveryState ==
                                ChatMessageDeliveryState.failed &&
                            onRetry != null) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () async {
                              await onRetry!();
                            },
                            child: Text(
                              '重试',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFF2D8CFF),
                                    fontSize: 11,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 7),
            _ChatAvatar(
              label: message.senderName,
              isMine: true,
              onTap: onAvatarTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.label, required this.isMine, this.onTap});

  final String label;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFFEAF1FF) : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Center(
          child: Text(
            label.characters.first,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isMine ? const Color(0xFF2F6BFF) : const Color(0xFF344054),
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMessageBody extends StatelessWidget {
  const _ChatMessageBody({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

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
        return _AttachmentLine(
          icon: Icons.multitrack_audio_rounded,
          label: mediaContent.fileName,
          status: mediaContent.attachmentStatus,
          subtitle:
              '${mediaContent.mimeType} · ${_formatBytes(mediaContent.sizeBytes)}',
        );
      case ChatMessageKind.file:
        return _AttachmentLine(
          icon: Icons.insert_drive_file_outlined,
          label: mediaContent.fileName,
          status: mediaContent.attachmentStatus,
          subtitle:
              '${mediaContent.mimeType} · ${_formatBytes(mediaContent.sizeBytes)}',
        );
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
    final theme = _AttachmentVisualState.fromStatus(content.attachmentStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 180,
            height: 180,
            color: const Color(0xFFF1F4F8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _attachmentStatusLabel(content.attachmentStatus),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: theme.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Center(child: Icon(theme.icon, size: 42, color: theme.color)),
                if (content.attachmentStatus ==
                    ChatMediaAttachmentStatus.processing)
                  const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xFF98A2B3)),
        ),
        const SizedBox(height: 4),
        Text(
          _attachmentHelperText(content.attachmentStatus),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: theme.color),
        ),
      ],
    );
  }
}

class _AttachmentLine extends StatelessWidget {
  const _AttachmentLine({
    required this.icon,
    required this.label,
    required this.status,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final ChatMediaAttachmentStatus status;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = _AttachmentVisualState.fromStatus(status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF667085)),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF98A2B3),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4F8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _attachmentStatusLabel(status),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: theme.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _attachmentHelperText(status),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: theme.color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttachmentVisualState {
  const _AttachmentVisualState({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  static _AttachmentVisualState fromStatus(ChatMediaAttachmentStatus status) {
    switch (status) {
      case ChatMediaAttachmentStatus.pendingUpload:
        return const _AttachmentVisualState(
          color: Color(0xFFC27B00),
          icon: Icons.schedule_send_outlined,
        );
      case ChatMediaAttachmentStatus.processing:
        return const _AttachmentVisualState(
          color: Color(0xFF2D8CFF),
          icon: Icons.image_outlined,
        );
      case ChatMediaAttachmentStatus.ready:
        return const _AttachmentVisualState(
          color: Color(0xFF12B76A),
          icon: Icons.image_outlined,
        );
      case ChatMediaAttachmentStatus.failed:
        return const _AttachmentVisualState(
          color: Color(0xFFF04438),
          icon: Icons.error_outline_rounded,
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

String _attachmentStatusLabel(ChatMediaAttachmentStatus status) {
  return switch (status) {
    ChatMediaAttachmentStatus.pendingUpload => '待上传',
    ChatMediaAttachmentStatus.processing => '处理中',
    ChatMediaAttachmentStatus.ready => '可用',
    ChatMediaAttachmentStatus.failed => '处理失败',
  };
}

String _attachmentHelperText(ChatMediaAttachmentStatus status) {
  return switch (status) {
    ChatMediaAttachmentStatus.pendingUpload => '附件还在等待上传完成',
    ChatMediaAttachmentStatus.processing => '附件处理中，稍后可用',
    ChatMediaAttachmentStatus.ready => '附件已处理完成',
    ChatMediaAttachmentStatus.failed => '附件处理失败，请稍后重试',
  };
}
