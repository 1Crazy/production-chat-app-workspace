import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';

class ChatMessageDto {
  const ChatMessageDto({
    required this.serverMessageId,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.clientMessageId,
    required this.messageKind,
    required this.deliveryState,
    required this.sequence,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.failureReason,
  });

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>;
    final content = json['content'] as Map<String, dynamic>;
    final messageKind = _messageKindFromWire(json['type'] as String);

    return ChatMessageDto(
      serverMessageId: json['serverMessageId'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      senderName: sender['nickname'] as String,
      clientMessageId: json['clientMessageId'] as String,
      messageKind: messageKind,
      deliveryState: _deliveryStateFromWire(
        json['status']?.toString() ?? 'sent',
      ),
      sequence: json['sequence'] as int,
      content: _contentFromJson(messageKind: messageKind, json: content),
      createdAt: _parseToLocal(json['createdAt'] as String),
      updatedAt: _parseToLocal(json['updatedAt'] as String),
      failureReason: json['failureReason']?.toString(),
    );
  }

  final String serverMessageId;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String clientMessageId;
  final ChatMessageKind messageKind;
  final ChatMessageDeliveryState deliveryState;
  final int sequence;
  final ChatMessageContent content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? failureReason;

  ChatMessage toEntity() {
    return ChatMessage(
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      messageKind: messageKind,
      content: content,
      deliveryState: deliveryState,
      createdAt: createdAt,
      updatedAt: updatedAt,
      serverMessageId: serverMessageId,
      sequence: sequence,
      failureReason: failureReason,
    );
  }

  static ChatMessageDeliveryState _deliveryStateFromWire(String status) {
    switch (status) {
      case 'failed':
        return ChatMessageDeliveryState.failed;
      case 'processing':
        return ChatMessageDeliveryState.sending;
      case 'sent':
      default:
        return ChatMessageDeliveryState.sent;
    }
  }

  static ChatMessageKind _messageKindFromWire(String type) {
    switch (type) {
      case 'text':
        return ChatMessageKind.text;
      case 'image':
        return ChatMessageKind.image;
      case 'audio':
        return ChatMessageKind.audio;
      case 'file':
        return ChatMessageKind.file;
      default:
        return ChatMessageKind.text;
    }
  }

  static ChatMessageContent _contentFromJson({
    required ChatMessageKind messageKind,
    required Map<String, dynamic> json,
  }) {
    if (messageKind == ChatMessageKind.text) {
      return ChatTextMessageContent(text: (json['text'] ?? '').toString());
    }

    final attachmentKind = _messageKindFromWire(
      (json['attachmentKind'] ?? _messageKindToWire(messageKind)).toString(),
    );

    return ChatMediaMessageContent(
      attachmentId: (json['attachmentId'] ?? '').toString(),
      attachmentKind: attachmentKind,
      attachmentStatus: _attachmentStatusFromWire(
        (json['attachmentStatus'] ?? 'ready').toString(),
      ),
      fileName: (json['fileName'] ?? '附件').toString(),
      mimeType: (json['mimeType'] ?? 'application/octet-stream').toString(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      previewObjectKey: json['previewObjectKey'] as String?,
    );
  }

  static String _messageKindToWire(ChatMessageKind kind) {
    switch (kind) {
      case ChatMessageKind.text:
        return 'text';
      case ChatMessageKind.image:
        return 'image';
      case ChatMessageKind.audio:
        return 'audio';
      case ChatMessageKind.file:
        return 'file';
    }
  }

  static ChatMediaAttachmentStatus _attachmentStatusFromWire(String status) {
    switch (status) {
      case 'pending_upload':
        return ChatMediaAttachmentStatus.pendingUpload;
      case 'processing':
        return ChatMediaAttachmentStatus.processing;
      case 'failed':
        return ChatMediaAttachmentStatus.failed;
      case 'ready':
      default:
        return ChatMediaAttachmentStatus.ready;
    }
  }

  static DateTime _parseToLocal(String rawValue) {
    return DateTime.parse(rawValue).toLocal();
  }
}
