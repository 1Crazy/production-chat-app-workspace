enum ChatMessageDeliveryState { sending, sent, failed }

enum ChatMessageKind { text, image, audio, file }

enum ChatMediaAttachmentStatus { pendingUpload, processing, ready, failed }

abstract class ChatMessageContent {
  const ChatMessageContent();
}

class ChatTextMessageContent extends ChatMessageContent {
  const ChatTextMessageContent({required this.text});

  final String text;
}

class ChatMediaMessageContent extends ChatMessageContent {
  const ChatMediaMessageContent({
    required this.attachmentId,
    required this.attachmentKind,
    required this.attachmentStatus,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.previewObjectKey,
  });

  final String attachmentId;
  final ChatMessageKind attachmentKind;
  final ChatMediaAttachmentStatus attachmentStatus;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String? previewObjectKey;
}

class ChatMessage {
  const ChatMessage({
    required this.clientMessageId,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.messageKind,
    required this.content,
    required this.deliveryState,
    required this.createdAt,
    required this.updatedAt,
    this.serverMessageId,
    this.sequence,
    this.failureReason,
  });

  final String clientMessageId;
  final String conversationId;
  final String senderId;
  final String senderName;
  final ChatMessageKind messageKind;
  final ChatMessageContent content;
  final ChatMessageDeliveryState deliveryState;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? serverMessageId;
  final int? sequence;
  final String? failureReason;

  bool belongsTo(String userId) => senderId == userId;

  ChatTextMessageContent? get textContent {
    return content is ChatTextMessageContent
        ? content as ChatTextMessageContent
        : null;
  }

  ChatMediaMessageContent? get mediaContent {
    return content is ChatMediaMessageContent
        ? content as ChatMediaMessageContent
        : null;
  }

  String get previewText {
    final textBody = textContent;

    if (textBody != null) {
      return textBody.text.trim();
    }

    final mediaBody = mediaContent;

    if (mediaBody == null) {
      return '[消息]';
    }

    switch (mediaBody.attachmentKind) {
      case ChatMessageKind.image:
        return '[图片] ${mediaBody.fileName}';
      case ChatMessageKind.audio:
        return '[语音] ${mediaBody.fileName}';
      case ChatMessageKind.file:
        return '[文件] ${mediaBody.fileName}';
      case ChatMessageKind.text:
        return mediaBody.fileName;
    }
  }

  ChatMessage copyWith({
    String? clientMessageId,
    String? conversationId,
    String? senderId,
    String? senderName,
    ChatMessageKind? messageKind,
    ChatMessageContent? content,
    ChatMessageDeliveryState? deliveryState,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? serverMessageId,
    int? sequence,
    String? failureReason,
    bool clearFailureReason = false,
  }) {
    return ChatMessage(
      clientMessageId: clientMessageId ?? this.clientMessageId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      messageKind: messageKind ?? this.messageKind,
      content: content ?? this.content,
      deliveryState: deliveryState ?? this.deliveryState,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serverMessageId: serverMessageId ?? this.serverMessageId,
      sequence: sequence ?? this.sequence,
      failureReason: clearFailureReason
          ? null
          : failureReason ?? this.failureReason,
    );
  }
}
