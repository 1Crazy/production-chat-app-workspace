import 'dart:math';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_history_page.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_read_receipt_member.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_sync_result.dart';
import 'package:production_chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/shared/network/api_client.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime_event.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required ChatRepository chatRepository,
    required ChatRealtime chatRealtime,
    required String accessToken,
    required String currentUserId,
  }) : _chatRepository = chatRepository,
       _chatRealtime = chatRealtime,
       _accessToken = accessToken,
       _currentUserId = currentUserId {
    _subscriptions = [
      _chatRealtime.connectionStateStream.listen(_handleConnectionStateChanged),
      _chatRealtime.connectionErrorStream.listen(_handleConnectionError),
      _chatRealtime.connectionReadyStream.listen(_handleConnectionReady),
      _chatRealtime.messageCreatedStream.listen(_handleMessageCreated),
      _chatRealtime.readCursorUpdatedStream.listen(_handleReadCursorUpdated),
      _chatRealtime.typingUpdatedStream.listen(_handleTypingUpdated),
    ];
  }

  final ChatRepository _chatRepository;
  final ChatRealtime _chatRealtime;
  final String _currentUserId;
  final Random _random = Random();
  String _accessToken;
  late final List<StreamSubscription<dynamic>> _subscriptions;
  Timer? _typingHeartbeatTimer;
  bool _isLocalTyping = false;

  ConversationSummary? _activeConversation;
  List<ChatMessage> _messages = const [];
  bool _isInitialLoading = false;
  bool _isLoadingOlder = false;
  bool _isRefreshing = false;
  bool _isSending = false;
  String? _errorMessage;
  ChatRealtimeConnectionState _connectionState =
      ChatRealtimeConnectionState.disconnected;
  int _latestSequence = 0;
  int? _nextBeforeSequence;
  Map<String, int> _peerReadSequenceByUserId = const {};
  Map<String, String> _memberDisplayNameByUserId = const {};
  Map<String, String> _memberHandleByUserId = const {};
  Map<String, String?> _memberAvatarUrlByUserId = const {};
  Map<String, DateTime> _peerReadUpdatedAtByUserId = const {};
  final Set<String> _remoteTypingUserIds = <String>{};

  ConversationSummary? get activeConversation => _activeConversation;
  List<ChatMessage> get messages => _messages;
  bool get isInitialLoading => _isInitialLoading;
  bool get isLoadingOlder => _isLoadingOlder;
  bool get isRefreshing => _isRefreshing;
  bool get isSending => _isSending;
  bool get hasOlder => _nextBeforeSequence != null;
  String? get errorMessage => _errorMessage;
  ChatRealtimeConnectionState get connectionState => _connectionState;
  String get currentUserId => _currentUserId;
  bool get isPeerTyping => _remoteTypingUserIds.isNotEmpty;
  Future<void> updateAccessToken(String accessToken) async {
    _accessToken = accessToken;
  }

  // 切换会话时直接重建消息状态，避免把上一个会话的分页游标和发送状态串到当前会话。
  Future<void> openConversation(ConversationSummary conversation) async {
    final previousConversation = _activeConversation;

    if (previousConversation != null && _isLocalTyping) {
      _chatRealtime.emitTyping(
        conversationId: previousConversation.id,
        isTyping: false,
      );
      _isLocalTyping = false;
    }

    _activeConversation = conversation;
    _messages = const [];
    _latestSequence = 0;
    _nextBeforeSequence = null;
    _peerReadSequenceByUserId = const {};
    _memberDisplayNameByUserId = const {};
    _memberHandleByUserId = const {};
    _memberAvatarUrlByUserId = const {};
    _peerReadUpdatedAtByUserId = const {};
    _remoteTypingUserIds.clear();
    _stopTypingHeartbeat();
    _errorMessage = null;
    _isInitialLoading = true;
    notifyListeners();

    try {
      final page = await _chatRepository.fetchHistory(
        accessToken: _accessToken,
        conversationId: conversation.id,
        currentUserId: _currentUserId,
      );

      _applyHistoryPage(page);
      await _markConversationAsRead();
    } catch (error) {
      _errorMessage = formatDisplayError(error);
    } finally {
      _isInitialLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOlder() async {
    final conversation = _activeConversation;
    final beforeSequence = _nextBeforeSequence;

    if (conversation == null || beforeSequence == null || _isLoadingOlder) {
      return;
    }

    _isLoadingOlder = true;
    notifyListeners();

    try {
      final page = await _chatRepository.fetchHistory(
        accessToken: _accessToken,
        conversationId: conversation.id,
        currentUserId: _currentUserId,
        beforeSequence: beforeSequence,
      );

      _applyHistoryPage(page);
    } catch (error) {
      _errorMessage = formatDisplayError(error);
    } finally {
      _isLoadingOlder = false;
      notifyListeners();
    }
  }

  Future<void> refreshGapSync() async {
    final conversation = _activeConversation;

    if (conversation == null || _isRefreshing) {
      return;
    }

    _isRefreshing = true;
    notifyListeners();

    try {
      var hasMore = true;
      var afterSequence = _latestSequence;

      while (hasMore) {
        final syncResult = await _chatRepository.syncAfter(
          accessToken: _accessToken,
          conversationId: conversation.id,
          afterSequence: afterSequence,
        );

        _applySyncResult(syncResult);
        afterSequence = syncResult.nextAfterSequence;
        hasMore = syncResult.hasMore;
      }

      await _markConversationAsRead();
    } catch (error) {
      _errorMessage = formatDisplayError(error);
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> sendText(String rawText) async {
    final conversation = _activeConversation;
    final text = rawText.trim();

    if (conversation == null || text.isEmpty) {
      return;
    }

    final optimisticMessage = ChatMessage(
      clientMessageId: _buildClientMessageId(),
      conversationId: conversation.id,
      senderId: _currentUserId,
      senderName: '我',
      messageKind: ChatMessageKind.text,
      content: ChatTextMessageContent(text: text),
      deliveryState: ChatMessageDeliveryState.sending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _messages = _mergeMessages([..._messages, optimisticMessage]);
    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final confirmedMessage = await _chatRepository.sendText(
        accessToken: _accessToken,
        conversationId: conversation.id,
        clientMessageId: optimisticMessage.clientMessageId,
        text: text,
      );

      _messages = _mergeMessages([..._messages, confirmedMessage]);
      _latestSequence = max(_latestSequence, confirmedMessage.sequence ?? 0);
      await _markConversationAsRead();
      await updateTypingDraft('');
    } catch (error) {
      _messages = _messages
          .map((message) {
            if (message.clientMessageId != optimisticMessage.clientMessageId) {
              return message;
            }

            return message.copyWith(
              deliveryState: ChatMessageDeliveryState.failed,
              failureReason: formatDisplayError(error),
            );
          })
          .toList(growable: false);
      _errorMessage = formatDisplayError(error);
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> retryMessage(String clientMessageId) async {
    ChatMessage? target;

    for (final message in _messages) {
      if (message.clientMessageId == clientMessageId) {
        target = message;
        break;
      }
    }

    if (target == null ||
        target.deliveryState != ChatMessageDeliveryState.failed) {
      return;
    }

    _messages = _messages
        .map((message) {
          if (message.clientMessageId != clientMessageId) {
            return message;
          }

          return message.copyWith(
            deliveryState: ChatMessageDeliveryState.sending,
            clearFailureReason: true,
          );
        })
        .toList(growable: false);
    _isSending = true;
    notifyListeners();

    try {
      final confirmedMessage = await _chatRepository.sendText(
        accessToken: _accessToken,
        conversationId: target.conversationId,
        clientMessageId: target.clientMessageId,
        text: target.textContent?.text ?? '',
      );

      _messages = _mergeMessages([..._messages, confirmedMessage]);
      _latestSequence = max(_latestSequence, confirmedMessage.sequence ?? 0);
      await _markConversationAsRead();
    } catch (error) {
      _messages = _messages
          .map((message) {
            if (message.clientMessageId != clientMessageId) {
              return message;
            }

            return message.copyWith(
              deliveryState: ChatMessageDeliveryState.failed,
              failureReason: formatDisplayError(error),
            );
          })
          .toList(growable: false);
      _errorMessage = formatDisplayError(error);
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

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
        return 1;
      case ChatMessageDeliveryState.sending:
        return 2;
      case ChatMessageDeliveryState.sent:
        return 3;
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
    notifyListeners();
  }

  void _handleConnectionError(String errorMessage) {
    _errorMessage = errorMessage;
    notifyListeners();
  }

  void _handleMessageCreated(ChatMessage message) {
    final conversation = _activeConversation;

    if (conversation == null || message.conversationId != conversation.id) {
      return;
    }

    _messages = _mergeMessages([..._messages, message]);
    _latestSequence = max(_latestSequence, message.sequence ?? 0);
    notifyListeners();

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
    notifyListeners();
  }

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

    notifyListeners();
  }

  void _stopTypingHeartbeat() {
    _typingHeartbeatTimer?.cancel();
    _typingHeartbeatTimer = null;
  }

  @override
  void dispose() {
    final activeConversation = _activeConversation;

    if (activeConversation != null && _isLocalTyping) {
      _chatRealtime.emitTyping(
        conversationId: activeConversation.id,
        isTyping: false,
      );
    }

    _stopTypingHeartbeat();

    for (final subscription in _subscriptions) {
      subscription.cancel();
    }

    super.dispose();
  }
}
