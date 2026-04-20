import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime_event.dart';

abstract class ChatRealtime {
  Stream<ChatRealtimeConnectionState> get connectionStateStream;
  Stream<ChatConnectionReadyEvent> get connectionReadyStream;
  Stream<ChatConversationCreatedEvent> get conversationCreatedStream;
  Stream<ChatMessage> get messageCreatedStream;
  Stream<ChatReadCursorUpdatedEvent> get readCursorUpdatedStream;
  Stream<ChatTypingUpdatedEvent> get typingUpdatedStream;
  Stream<ChatSessionRevokedEvent> get sessionRevokedStream;
  Stream<String> get connectionErrorStream;
  bool get isConnected;

  void connect({required String accessToken});
  void disconnect();
  void emitTyping({required String conversationId, required bool isTyping});
}
