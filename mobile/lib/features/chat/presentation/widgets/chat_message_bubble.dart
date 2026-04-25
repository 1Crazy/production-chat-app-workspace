import 'package:flutter/material.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';

part 'chat_message_bubble_parts.dart';

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
