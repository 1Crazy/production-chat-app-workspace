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

part 'chat_controller_message_state.dart';
part 'chat_controller_read_receipts.dart';
part 'chat_controller_realtime.dart';
part 'chat_controller_typing.dart';

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

    final retryClientMessageId = _buildClientMessageId();
    final retryMessage = target.copyWith(
      clientMessageId: retryClientMessageId,
      deliveryState: ChatMessageDeliveryState.sending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      clearServerMessageId: true,
      clearSequence: true,
      clearFailureReason: true,
    );
    _messages = _mergeMessages([..._messages, retryMessage]);
    _isSending = true;
    notifyListeners();

    try {
      final confirmedMessage = await _chatRepository.sendText(
        accessToken: _accessToken,
        conversationId: target.conversationId,
        clientMessageId: retryClientMessageId,
        text: target.textContent?.text ?? '',
      );

      _messages = _mergeMessages([..._messages, confirmedMessage]);
      _latestSequence = max(_latestSequence, confirmedMessage.sequence ?? 0);
      await _markConversationAsRead();
    } catch (error) {
        _messages = _messages
          .map((message) {
            if (message.clientMessageId != retryClientMessageId) {
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

  void _notifyChanged() {
    notifyListeners();
  }
}
