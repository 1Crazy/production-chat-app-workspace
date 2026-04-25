import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:production_chat_app/shared/network/api_client.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime_event.dart';

class ConversationListController extends ChangeNotifier {
  ConversationListController({
    required ConversationRepository conversationRepository,
    required ChatRealtime chatRealtime,
    required String accessToken,
    required String currentUserId,
    String? activeConversationId,
    ValueChanged<List<ConversationSummary>>? onItemsChanged,
  }) : _conversationRepository = conversationRepository,
       _chatRealtime = chatRealtime,
       _accessToken = accessToken,
       _currentUserId = currentUserId,
       _activeConversationId = activeConversationId,
       _onItemsChanged = onItemsChanged {
    _subscriptions = [
      _chatRealtime.connectionReadyStream.listen((_) {
        load(silent: true);
      }),
      _chatRealtime.conversationCreatedStream.listen((_) {
        load(silent: true);
      }),
      _chatRealtime.messageCreatedStream.listen((message) {
        _applyMessageCreated(message);
      }),
      _chatRealtime.readCursorUpdatedStream.listen((event) {
        _applyReadCursorUpdated(event);
      }),
    ];
  }

  final ConversationRepository _conversationRepository;
  final ChatRealtime _chatRealtime;
  final String _currentUserId;
  final ValueChanged<List<ConversationSummary>>? _onItemsChanged;
  String _accessToken;
  String? _activeConversationId;
  late final List<StreamSubscription<dynamic>> _subscriptions;

  List<ConversationSummary> _items = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ConversationSummary> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _errorMessage = null;
      _items = await _conversationRepository.fetchRecent(
        accessToken: _accessToken,
      );
      _publishItemsChanged();
    } catch (error) {
      _errorMessage = formatDisplayError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateAccessToken(String accessToken) async {
    if (_accessToken == accessToken) {
      return;
    }

    _accessToken = accessToken;
    await load(silent: true);
  }

  void updateActiveConversationId(String? conversationId) {
    _activeConversationId = conversationId;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }

    super.dispose();
  }

  void _applyMessageCreated(ChatMessage message) {
    final targetIndex = _items.indexWhere(
      (item) => item.id == message.conversationId,
    );

    if (targetIndex < 0) {
      // 只有新会话或本地缓存缺口时才退回整表拉取，常规消息事件走本地增量更新。
      load(silent: true);
      return;
    }

    final currentItem = _items[targetIndex];
    final nextUnreadCount =
        message.senderId != _currentUserId &&
            message.conversationId != _activeConversationId
        ? currentItem.unreadCount + 1
        : currentItem.unreadCount;
    final updatedItem = currentItem.copyWith(
      lastMessagePreview: _buildMessagePreview(message),
      latestSequence: message.sequence ?? currentItem.latestSequence,
      unreadCount: nextUnreadCount,
      updatedAt: message.updatedAt,
      lastMessageAt: message.createdAt,
    );
    final nextItems = [..._items]..removeAt(targetIndex);
    nextItems.insert(0, updatedItem);
    _items = nextItems;
    _publishItemsChanged();
    notifyListeners();
  }

  void _applyReadCursorUpdated(ChatReadCursorUpdatedEvent event) {
    if (event.userId != _currentUserId) {
      return;
    }

    final targetIndex = _items.indexWhere(
      (item) => item.id == event.conversationId,
    );

    if (targetIndex < 0) {
      return;
    }

    final currentItem = _items[targetIndex];
    final nextItems = [..._items];
    nextItems[targetIndex] = currentItem.copyWith(
      unreadCount: event.unreadCount,
    );
    _items = nextItems;
    _publishItemsChanged();
    notifyListeners();
  }

  String _buildMessagePreview(ChatMessage message) {
    final preview = message.previewText.trim();
    return preview.isEmpty ? '[消息]' : preview;
  }

  void _publishItemsChanged() {
    _onItemsChanged?.call(List.unmodifiable(_items));
  }
}
