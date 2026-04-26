part of 'chat_controller.dart';

extension _ChatControllerMessageState on ChatController {
  void _applyHistoryPage(ChatHistoryPage page) {
    _messages = _mergeMessages([...page.messages, ..._messages]);
    _latestSequence = max(_latestSequence, page.latestSequence);
    _peerReadSequenceByUserId = page.peerReadSequenceByUserId;
    _memberDisplayNameByUserId = page.memberDisplayNameByUserId;
    _memberHandleByUserId = page.memberHandleByUserId;
    _memberAvatarUrlByUserId = page.memberAvatarUrlByUserId;
    _peerReadUpdatedAtByUserId = page.peerReadUpdatedAtByUserId;
    _nextBeforeSequence = page.nextBeforeSequence;
  }

  void _applySyncResult(ChatSyncResult result) {
    _messages = _mergeMessages([..._messages, ...result.messages]);
    _latestSequence = max(_latestSequence, result.latestSequence);
  }

  // 服务端会在重发成功时复用同一个 clientMessageId，因此这里优先用它做去重与本地状态替换。
  List<ChatMessage> _mergeMessages(List<ChatMessage> rawMessages) {
    final messageByClientId = <String, ChatMessage>{};

    for (final message in rawMessages) {
      final existing = messageByClientId[message.clientMessageId];

      if (existing == null) {
        messageByClientId[message.clientMessageId] = message;
        continue;
      }

      final existingScore = _deliveryScore(existing.deliveryState);
      final nextScore = _deliveryScore(message.deliveryState);
      messageByClientId[message.clientMessageId] = nextScore >= existingScore
          ? message
          : existing;
    }

    final mergedMessages = messageByClientId.values.toList(growable: false);
    mergedMessages.sort((left, right) {
      final leftSequence = left.sequence;
      final rightSequence = right.sequence;

      if (leftSequence != null && rightSequence != null) {
        return leftSequence.compareTo(rightSequence);
      }

      if (leftSequence != null) {
        return -1;
      }

      if (rightSequence != null) {
        return 1;
      }

      return left.createdAt.compareTo(right.createdAt);
    });

    return mergedMessages;
  }

  int _deliveryScore(ChatMessageDeliveryState state) {
    switch (state) {
      case ChatMessageDeliveryState.failed:
        return 3;
      case ChatMessageDeliveryState.sending:
        return 1;
      case ChatMessageDeliveryState.sent:
        return 2;
    }
  }

  Future<void> _markConversationAsRead() async {
    final conversation = _activeConversation;

    if (conversation == null || _latestSequence <= 0) {
      return;
    }

    try {
      await _chatRepository.updateReadCursor(
        accessToken: _accessToken,
        conversationId: conversation.id,
        lastReadSequence: _latestSequence,
      );
    } catch (_) {
      // 已读同步失败不阻塞主流程，下次打开会话或下拉刷新时会再次追平。
    }
  }

  String _buildClientMessageId() {
    final epochMicros = DateTime.now().microsecondsSinceEpoch;
    final randomSuffix = _random.nextInt(0x7fffffff).toRadixString(16);
    return 'local_$epochMicros$randomSuffix';
  }
}
