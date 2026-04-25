part of 'chat_controller.dart';

extension _ChatControllerRealtime on ChatController {
  void _handleConnectionReady(ChatConnectionReadyEvent event) {
    final conversation = _activeConversation;

    if (conversation == null) {
      return;
    }

    final latestSequenceOnServer =
        event.conversationLatestSequenceById[conversation.id];

    if (latestSequenceOnServer == null ||
        latestSequenceOnServer <= _latestSequence) {
      return;
    }

    refreshGapSync();
  }

  void _handleConnectionStateChanged(ChatRealtimeConnectionState state) {
    _connectionState = state;
    _notifyChanged();
  }

  void _handleConnectionError(String errorMessage) {
    _errorMessage = errorMessage;
    _notifyChanged();
  }

  void _handleMessageCreated(ChatMessage message) {
    final conversation = _activeConversation;

    if (conversation == null || message.conversationId != conversation.id) {
      return;
    }

    _messages = _mergeMessages([..._messages, message]);
    _latestSequence = max(_latestSequence, message.sequence ?? 0);
    _notifyChanged();

    if (message.senderId != _currentUserId) {
      _markConversationAsRead();
    }
  }

  void _handleReadCursorUpdated(ChatReadCursorUpdatedEvent event) {
    final conversation = _activeConversation;

    if (conversation == null ||
        event.conversationId != conversation.id ||
        event.userId == _currentUserId) {
      return;
    }

    _peerReadSequenceByUserId = {
      ..._peerReadSequenceByUserId,
      event.userId: event.lastReadSequence,
    };
    _peerReadUpdatedAtByUserId = {
      ..._peerReadUpdatedAtByUserId,
      event.userId: event.updatedAt,
    };
    _notifyChanged();
  }
}
