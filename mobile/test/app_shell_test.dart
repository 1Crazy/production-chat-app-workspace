import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies_scope.dart';
import 'package:production_chat_app/app/shell/app_shell.dart';
import 'package:production_chat_app/features/auth/application/auth_controller.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_code_purpose.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_code_receipt.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_session.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_user.dart';
import 'package:production_chat_app/features/auth/domain/entities/device_session.dart';
import 'package:production_chat_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_history_page.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_sync_result.dart';
import 'package:production_chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_request_summary.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_summary.dart';
import 'package:production_chat_app/features/friendship/domain/repositories/friendship_repository.dart';
import 'package:production_chat_app/features/profile/domain/entities/discoverable_user.dart';
import 'package:production_chat_app/features/profile/domain/entities/user_profile.dart';
import 'package:production_chat_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:production_chat_app/shared/config/app_environment.dart';
import 'package:production_chat_app/shared/network/api_client.dart';
import 'package:production_chat_app/shared/notifications/app_badge_service.dart';
import 'package:production_chat_app/shared/notifications/device_push_token.dart';
import 'package:production_chat_app/shared/notifications/notification_remote_data_source.dart';
import 'package:production_chat_app/shared/notifications/notification_sync_state.dart';
import 'package:production_chat_app/shared/notifications/push_notification_service.dart';
import 'package:production_chat_app/shared/notifications/push_registration_service.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime_event.dart';

void main() {
  testWidgets(
    'app shell clears message badge when opening an unread conversation',
    (tester) async {
      final authController = AuthController(
        authRepository: _FakeAuthRepository(),
        pushRegistrationService: _FakePushRegistrationService(),
      );
      await authController.bootstrap();

      await tester.pumpWidget(
        AppDependenciesScope(
          dependencies: AppDependencies(
            authRepository: _FakeAuthRepository(),
            appBadgeService: const AppBadgeService(),
            chatRepository: _FakeChatRepository(),
            chatRealtime: _FakeChatRealtime(),
            conversationRepository: _FakeConversationRepository(),
            firebaseReady: true,
            friendshipRepository: _FakeFriendshipRepository(),
            notificationRemoteDataSource: _FakeNotificationRemoteDataSource(),
            profileRepository: _FakeProfileRepository(),
            pushNotificationService: const NoopPushNotificationService(),
            pushRegistrationService: _FakePushRegistrationService(),
          ),
          child: AuthScope(
            controller: authController,
            child: const MaterialApp(
              home: AppShell(
                environment: AppEnvironment(
                  appName: 'Production Chat',
                  flavor: 'test',
                  apiBaseUrl: 'http://localhost:3000',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('77'), findsNWidgets(2));

      await tester.tap(find.text('Unread Peer'));
      await tester.pumpAndSettle();

      expect(find.text('77'), findsNothing);
      expect(find.text('联系人'), findsNothing);
      expect(find.text('发现'), findsNothing);
    },
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
    String? deviceName,
  }) async {
    return _session;
  }

  @override
  Future<List<DeviceSession>> listSessions({
    required String accessToken,
  }) async {
    return [_session.currentSession];
  }

  @override
  Future<void> logout({required String accessToken}) async {}

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    return _session;
  }

  @override
  Future<AuthSession> register({
    required String identifier,
    required String code,
    required String password,
    required String nickname,
    String? deviceName,
  }) async {
    return _session;
  }

  @override
  Future<AuthCodeReceipt> requestCode({
    required String identifier,
    required AuthCodePurpose purpose,
  }) async {
    return AuthCodeReceipt(
      identifier: identifier,
      purpose: purpose,
      debugCode: '246810',
      expiresInSeconds: 600,
    );
  }

  @override
  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String password,
  }) async {}

  @override
  Future<void> revokeSession({
    required String accessToken,
    required String sessionId,
  }) async {}

  @override
  Future<AuthSession?> restore() async {
    return _session;
  }

  static final AuthSession _session = AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    user: const AuthUser(
      id: 'user-1',
      identifier: 'demo_user',
      nickname: 'Demo User',
      handle: 'demo_user',
      avatarUrl: null,
      discoveryMode: 'public',
    ),
    currentSession: DeviceSession(
      id: 'session-1',
      deviceName: 'flutter-web',
      createdAt: DateTime(2026, 1, 1),
      lastSeenAt: DateTime(2026, 1, 1),
      isCurrent: true,
    ),
  );
}

class _FakePushRegistrationService implements PushRegistrationService {
  final StreamController<void> _streamController =
      StreamController<void>.broadcast();

  @override
  Future<bool> loadPrivacyModeEnabled() async => false;

  @override
  Future<void> syncPushRegistration({required String accessToken}) async {}

  @override
  Stream<void> get tokenRefreshStream => _streamController.stream;

  @override
  Future<void> updatePrivacyMode({
    required bool enabled,
    String? accessToken,
  }) async {}
}

class _FakeConversationRepository implements ConversationRepository {
  static final ConversationSummary _conversation = ConversationSummary(
    id: 'conversation-1',
    type: 'direct',
    title: 'Unread Peer',
    memberCount: 2,
    lastMessagePreview: '有一条未读消息',
    latestSequence: 12,
    unreadCount: 77,
    updatedAt: DateTime(2026, 1, 1, 12, 0),
    lastMessageAt: DateTime(2026, 1, 1, 12, 0),
  );

  @override
  Future<String> createGroupConversation({
    required String accessToken,
    required String title,
    required List<String> memberHandles,
  }) async {
    return _conversation.id;
  }

  @override
  Future<String> createOrReuseDirectConversation({
    required String accessToken,
    required String targetHandle,
  }) async {
    return _conversation.id;
  }

  @override
  Future<List<ConversationSummary>> fetchRecent({
    required String accessToken,
  }) async {
    return [_conversation];
  }

  @override
  Future<ConversationSummary?> findById({
    required String accessToken,
    required String conversationId,
  }) async {
    return conversationId == _conversation.id ? _conversation : null;
  }
}

class _FakeChatRepository implements ChatRepository {
  @override
  Future<ChatHistoryPage> fetchHistory({
    required String accessToken,
    required String conversationId,
    required String currentUserId,
    int? beforeSequence,
    int limit = 20,
  }) async {
    return ChatHistoryPage(
      messages: [
        ChatMessage(
          clientMessageId: 'message-1',
          conversationId: conversationId,
          senderId: 'user-2',
          senderName: 'Unread Peer',
          messageKind: ChatMessageKind.text,
          content: const ChatTextMessageContent(text: '你好'),
          deliveryState: ChatMessageDeliveryState.sent,
          sequence: 12,
          createdAt: DateTime(2026, 1, 1, 12, 0),
          updatedAt: DateTime(2026, 1, 1, 12, 0),
        ),
      ],
      latestSequence: 12,
      peerReadSequenceByUserId: const {},
      memberDisplayNameByUserId: const {
        'user-1': 'Demo User',
        'user-2': 'Unread Peer',
      },
      memberHandleByUserId: const {
        'user-1': 'demo_user',
        'user-2': 'unread_peer',
      },
      memberAvatarUrlByUserId: const {'user-1': null, 'user-2': null},
      peerReadUpdatedAtByUserId: const {},
      nextBeforeSequence: null,
    );
  }

  @override
  Future<ChatMessage> sendText({
    required String accessToken,
    required String conversationId,
    required String clientMessageId,
    required String text,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ChatSyncResult> syncAfter({
    required String accessToken,
    required String conversationId,
    required int afterSequence,
    int limit = 100,
  }) async {
    return const ChatSyncResult(
      messages: [],
      latestSequence: 12,
      nextAfterSequence: 12,
      hasMore: false,
    );
  }

  @override
  Future<void> updateReadCursor({
    required String accessToken,
    required String conversationId,
    required int lastReadSequence,
  }) async {}
}

class _FakeFriendshipRepository implements FriendshipRepository {
  @override
  Future<void> acceptFriendRequest({
    required String accessToken,
    required String requestId,
  }) async {}

  @override
  Future<void> createFriendRequest({
    required String accessToken,
    required String targetHandle,
    String? message,
  }) async {}

  @override
  Future<List<FriendRequestSummary>> fetchIncomingRequests({
    required String accessToken,
  }) async {
    return const [];
  }

  @override
  Future<List<FriendRequestSummary>> fetchOutgoingRequests({
    required String accessToken,
  }) async {
    return const [];
  }

  @override
  Future<List<FriendSummary>> fetchFriends({
    required String accessToken,
  }) async {
    return const [];
  }

  @override
  Future<int> fetchUnreadIncomingRequestCount({
    required String accessToken,
  }) async {
    return 0;
  }

  @override
  Future<void> ignoreFriendRequest({
    required String accessToken,
    required String requestId,
  }) async {}

  @override
  Future<void> markIncomingRequestsViewed({
    required String accessToken,
  }) async {}

  @override
  Future<void> rejectFriendRequest({
    required String accessToken,
    required String requestId,
    String? rejectReason,
  }) async {}

  @override
  Future<void> deleteFriendRequestRecord({
    required String accessToken,
    required String requestId,
  }) async {}

  @override
  Future<void> removeFriend({
    required String accessToken,
    required String friendUserId,
  }) async {}
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<DiscoverableUser> discoverByHandle({
    required String accessToken,
    required String handle,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<UserProfile> fetchCurrent({required String accessToken}) async {
    throw UnimplementedError();
  }

  @override
  Future<UserProfile> updateCurrent({
    required String accessToken,
    required String nickname,
    required String? avatarUrl,
    required String discoveryMode,
  }) async {
    throw UnimplementedError();
  }
}

class _FakeNotificationRemoteDataSource extends NotificationRemoteDataSource {
  _FakeNotificationRemoteDataSource()
    : super(apiClient: ApiClient(baseUrl: 'http://localhost:3000'));

  @override
  Future<void> registerPushToken({
    required String accessToken,
    required DevicePushToken token,
    required bool privacyModeEnabled,
  }) async {}

  @override
  Future<NotificationSyncState> syncState({
    required String accessToken,
    required List<Map<String, Object?>> conversationStates,
    String? pushMessageId,
  }) async {
    return const NotificationSyncState(
      unreadBadgeCount: 0,
      conversationStates: [],
      recoveredPushMessageId: null,
    );
  }
}

class _FakeChatRealtime implements ChatRealtime {
  @override
  final Stream<ChatRealtimeConnectionState> connectionStateStream =
      const Stream<ChatRealtimeConnectionState>.empty();

  @override
  final Stream<ChatConnectionReadyEvent> connectionReadyStream =
      const Stream<ChatConnectionReadyEvent>.empty();

  @override
  final Stream<String> connectionErrorStream = const Stream<String>.empty();

  @override
  final Stream<ChatConversationCreatedEvent> conversationCreatedStream =
      const Stream<ChatConversationCreatedEvent>.empty();

  @override
  final Stream<ChatMessage> messageCreatedStream =
      const Stream<ChatMessage>.empty();

  @override
  final Stream<ChatReadCursorUpdatedEvent> readCursorUpdatedStream =
      const Stream<ChatReadCursorUpdatedEvent>.empty();

  @override
  final Stream<ChatSessionRevokedEvent> sessionRevokedStream =
      const Stream<ChatSessionRevokedEvent>.empty();

  @override
  final Stream<ChatTypingUpdatedEvent> typingUpdatedStream =
      const Stream<ChatTypingUpdatedEvent>.empty();

  @override
  bool get isConnected => false;

  @override
  void connect({required String accessToken}) {}

  @override
  void disconnect() {}

  @override
  void emitTyping({required String conversationId, required bool isTyping}) {}
}
