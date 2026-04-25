part of 'chat_controller.dart';

extension ChatControllerTyping on ChatController {
  // 输入中状态不是一次性事件，客户端在内容非空期间需要定期续约，避免服务端 TTL 到期后对方过早消失。
  Future<void> updateTypingDraft(String text) async {
    final conversation = _activeConversation;

    if (conversation == null) {
      return;
    }

    final shouldType = text.trim().isNotEmpty;

    if (!shouldType) {
      _stopTypingHeartbeat();

      if (_isLocalTyping) {
        _isLocalTyping = false;
        _chatRealtime.emitTyping(
          conversationId: conversation.id,
          isTyping: false,
        );
      }

      return;
    }

    if (!_isLocalTyping) {
      _isLocalTyping = true;
      _chatRealtime.emitTyping(conversationId: conversation.id, isTyping: true);
    }

    _typingHeartbeatTimer?.cancel();
    _typingHeartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final activeConversation = _activeConversation;

      if (!_isLocalTyping || activeConversation == null) {
        return;
      }

      _chatRealtime.emitTyping(
        conversationId: activeConversation.id,
        isTyping: true,
      );
    });
  }
}

extension _ChatControllerTypingEvents on ChatController {
  void _handleTypingUpdated(ChatTypingUpdatedEvent event) {
    final conversation = _activeConversation;

    if (conversation == null ||
        event.conversationId != conversation.id ||
        event.userId == _currentUserId) {
      return;
    }

    if (event.isTyping) {
      _remoteTypingUserIds.add(event.userId);
    } else {
      _remoteTypingUserIds.remove(event.userId);
    }

    _notifyChanged();
  }

  void _stopTypingHeartbeat() {
    _typingHeartbeatTimer?.cancel();
    _typingHeartbeatTimer = null;
  }
}
