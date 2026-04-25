part of 'chat_controller.dart';

extension ChatControllerReadReceipts on ChatController {
  String? readReceiptCaptionFor(ChatMessage message) {
    final sequence = message.sequence;

    if (message.senderId != _currentUserId || sequence == null) {
      return null;
    }

    final readUserCount = _peerReadSequenceByUserId.values.where((
      lastReadSequence,
    ) {
      return lastReadSequence >= sequence;
    }).length;

    if (readUserCount <= 0) {
      return null;
    }

    return '已读';
  }

  List<String> readReceiptMembersFor(ChatMessage message) {
    final sequence = message.sequence;

    if (sequence == null || message.senderId != _currentUserId) {
      return const [];
    }

    return _peerReadSequenceByUserId.entries
        .where((entry) => entry.value >= sequence)
        .map((entry) => _memberDisplayNameByUserId[entry.key] ?? '成员')
        .toList(growable: false);
  }

  List<ChatReadReceiptMember> readReceiptPanelMembersFor(ChatMessage message) {
    final conversation = _activeConversation;
    final sequence = message.sequence;

    if (conversation == null ||
        sequence == null ||
        message.senderId != _currentUserId) {
      return const [];
    }

    final members = _memberDisplayNameByUserId.entries
        .map((entry) {
          final lastReadSequence = _peerReadSequenceByUserId[entry.key];
          final hasRead =
              lastReadSequence != null && lastReadSequence >= sequence;

          return ChatReadReceiptMember(
            userId: entry.key,
            displayName: entry.value,
            handle: _memberHandleByUserId[entry.key] ?? entry.key,
            hasRead: hasRead,
            avatarUrl: _memberAvatarUrlByUserId[entry.key],
            readAt: hasRead ? _peerReadUpdatedAtByUserId[entry.key] : null,
          );
        })
        .toList(growable: false);

    members.sort((left, right) {
      if (left.hasRead != right.hasRead) {
        return left.hasRead ? -1 : 1;
      }

      final leftReadAt = left.readAt;
      final rightReadAt = right.readAt;

      if (leftReadAt != null && rightReadAt != null) {
        return rightReadAt.compareTo(leftReadAt);
      }

      if (leftReadAt != null) {
        return -1;
      }

      if (rightReadAt != null) {
        return 1;
      }

      return left.displayName.compareTo(right.displayName);
    });

    return members;
  }

  ChatReadReceiptMember? memberForMessage(ChatMessage message) {
    final senderId = message.senderId;
    final displayName =
        _memberDisplayNameByUserId[senderId] ?? message.senderName;
    final handle = _memberHandleByUserId[senderId] ?? senderId;

    if (displayName.isEmpty || handle.isEmpty) {
      return null;
    }

    final lastReadSequence = _peerReadSequenceByUserId[senderId];
    final sequence = message.sequence;
    final hasRead =
        sequence != null &&
        lastReadSequence != null &&
        lastReadSequence >= sequence;

    return ChatReadReceiptMember(
      userId: senderId,
      displayName: displayName,
      handle: handle,
      hasRead: hasRead,
      avatarUrl: _memberAvatarUrlByUserId[senderId],
      readAt: hasRead ? _peerReadUpdatedAtByUserId[senderId] : null,
    );
  }
}
