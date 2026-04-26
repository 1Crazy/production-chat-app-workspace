import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/shared/network/api_client.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime_event.dart';

class ChatRealtimeService implements ChatRealtime {
  ChatRealtimeService({required String baseUrl}) : _baseUrl = baseUrl;

  final String _baseUrl;
  final StreamController<ChatRealtimeConnectionState>
  _connectionStateController =
      StreamController<ChatRealtimeConnectionState>.broadcast();
  final StreamController<ChatConnectionReadyEvent> _connectionReadyController =
      StreamController<ChatConnectionReadyEvent>.broadcast();
  final StreamController<ChatConversationCreatedEvent>
  _conversationCreatedController =
      StreamController<ChatConversationCreatedEvent>.broadcast();
  final StreamController<ChatMessage> _messageCreatedController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<ChatReadCursorUpdatedEvent>
  _readCursorUpdatedController =
      StreamController<ChatReadCursorUpdatedEvent>.broadcast();
  final StreamController<ChatTypingUpdatedEvent> _typingUpdatedController =
      StreamController<ChatTypingUpdatedEvent>.broadcast();
  final StreamController<ChatSessionRevokedEvent> _sessionRevokedController =
      StreamController<ChatSessionRevokedEvent>.broadcast();
  final StreamController<String> _connectionErrorController =
      StreamController<String>.broadcast();

  io.Socket? _socket;
  String? _currentAccessToken;

  @override
  Stream<ChatRealtimeConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  @override
  Stream<ChatConnectionReadyEvent> get connectionReadyStream =>
      _connectionReadyController.stream;
  @override
  Stream<ChatConversationCreatedEvent> get conversationCreatedStream =>
      _conversationCreatedController.stream;
  @override
  Stream<ChatMessage> get messageCreatedStream =>
      _messageCreatedController.stream;
  @override
  Stream<ChatReadCursorUpdatedEvent> get readCursorUpdatedStream =>
      _readCursorUpdatedController.stream;
  @override
  Stream<ChatTypingUpdatedEvent> get typingUpdatedStream =>
      _typingUpdatedController.stream;
  @override
  Stream<ChatSessionRevokedEvent> get sessionRevokedStream =>
      _sessionRevokedController.stream;
  @override
  Stream<String> get connectionErrorStream => _connectionErrorController.stream;
  @override
  bool get isConnected => _socket?.connected ?? false;

  // Flutter 端使用 websocket transport，并在 access token 变化时整条连接重建，
  // 这样鉴权头和 namespace 状态都能和当前登录态保持一致。
  @override
  void connect({required String accessToken}) {
    if (_currentAccessToken == accessToken && isConnected) {
      return;
    }

    _currentAccessToken = accessToken;
    _disposeSocket();
    _connectionStateController.add(ChatRealtimeConnectionState.connecting);

    final socket = io.io(
      _buildNamespaceUrl(_baseUrl),
      _buildSocketOptions(accessToken),
    );

    _registerSocketListeners(socket);
    _socket = socket;
    socket.connect();
  }

  @override
  void disconnect() {
    _currentAccessToken = null;
    _disposeSocket();
    _connectionStateController.add(ChatRealtimeConnectionState.disconnected);
  }

  @override
  void emitTyping({required String conversationId, required bool isTyping}) {
    _socket?.emit('typing.set', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  Future<void> dispose() async {
    _disposeSocket();
    await Future.wait([
      _connectionStateController.close(),
      _connectionReadyController.close(),
      _conversationCreatedController.close(),
      _messageCreatedController.close(),
      _readCursorUpdatedController.close(),
      _typingUpdatedController.close(),
      _sessionRevokedController.close(),
      _connectionErrorController.close(),
    ]);
  }

  void _registerSocketListeners(io.Socket socket) {
    socket.onConnect((_) {});
    socket.onDisconnect((_) {
      _connectionStateController.add(ChatRealtimeConnectionState.disconnected);
    });
    socket.onConnectError((error) {
      _connectionStateController.add(ChatRealtimeConnectionState.disconnected);
      _connectionErrorController.add(formatDisplayError(error));
    });
    socket.onError((error) {
      _connectionStateController.add(ChatRealtimeConnectionState.disconnected);
      _connectionErrorController.add(formatDisplayError(error));
    });
    socket.on('connection.ready', (payload) {
      _connectionStateController.add(ChatRealtimeConnectionState.connected);
      _connectionReadyController.add(
        ChatConnectionReadyEvent.fromJson(_asMap(payload)),
      );
    });
    socket.on('conversation.created', (payload) {
      _conversationCreatedController.add(
        ChatConversationCreatedEvent.fromJson(_asMap(payload)),
      );
    });
    socket.on('message.created', (payload) {
      final event = ChatMessageCreatedEvent.fromJson(_asMap(payload));
      _messageCreatedController.add(event.message);
    });
    socket.on('read-cursor.updated', (payload) {
      _readCursorUpdatedController.add(
        ChatReadCursorUpdatedEvent.fromJson(_asMap(payload)),
      );
    });
    socket.on('typing.updated', (payload) {
      _typingUpdatedController.add(
        ChatTypingUpdatedEvent.fromJson(_asMap(payload)),
      );
    });
    socket.on('session.revoked', (payload) {
      _sessionRevokedController.add(
        ChatSessionRevokedEvent.fromJson(_asMap(payload)),
      );
    });
    socket.on('connection.error', (payload) {
      final map = _asMap(payload);
      _connectionStateController.add(ChatRealtimeConnectionState.disconnected);
      _connectionErrorController.add(map['message']?.toString() ?? '实时连接失败');
    });
  }

  void _disposeSocket() {
    final socket = _socket;

    if (socket == null) {
      return;
    }

    socket.dispose();
    socket.disconnect();
    _socket = null;
  }

  Map<String, dynamic> _asMap(dynamic payload) {
    if (payload is List && payload.isNotEmpty) {
      return _asMap(payload.first);
    }

    if (payload is Map<String, dynamic>) {
      return payload;
    }

    if (payload is Map) {
      return payload.map((key, value) {
        return MapEntry(key.toString(), value);
      });
    }

    throw StateError('实时事件格式不正确: $payload');
  }

  String _buildNamespaceUrl(String baseUrl) {
    final uri = Uri.parse(baseUrl);
    final pathSegments = [
      ...uri.pathSegments.where((segment) => segment.isNotEmpty),
      'chat',
    ];

    return uri.replace(pathSegments: pathSegments).toString();
  }

  @visibleForTesting
  Map<String, dynamic> buildSocketOptionsForTest({
    required String accessToken,
  }) {
    return _buildSocketOptions(accessToken);
  }

  Map<String, dynamic> _buildSocketOptions(String accessToken) {
    return io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        // 浏览器 websocket 不会可靠携带自定义 Authorization 头，
        // 因此 realtime 握手必须显式通过 auth.token 传 access token。
        .setAuth({'token': accessToken})
        // 原生平台继续保留 Authorization 头，兼容现有后端提取逻辑。
        .setExtraHeaders({'Authorization': 'Bearer $accessToken'})
        .build();
  }
}
