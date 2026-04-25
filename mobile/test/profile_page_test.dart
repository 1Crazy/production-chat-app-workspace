import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies_scope.dart';
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
import 'package:production_chat_app/features/profile/domain/entities/discoverable_user.dart';
import 'package:production_chat_app/features/profile/domain/entities/user_profile.dart';
import 'package:production_chat_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:production_chat_app/features/profile/presentation/pages/profile_page.dart';
import 'package:production_chat_app/shared/notifications/app_badge_service.dart';
import 'package:production_chat_app/shared/network/api_client.dart';
import 'package:production_chat_app/shared/notifications/notification_remote_data_source.dart';
import 'package:production_chat_app/shared/notifications/push_notification_service.dart';
import 'package:production_chat_app/shared/notifications/push_registration_service.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime_event.dart';

void main() {
  testWidgets(
    'profile page can open direct conversation from discovered user',
    (tester) async {
      final authController = AuthController(
        authRepository: _FakeAuthRepository(),
        pushRegistrationService: _FakePushRegistrationService(),
      );
      await authController.bootstrap();

      String? openedHandle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDependenciesScope(
              dependencies: AppDependencies(
                authRepository: _FakeAuthRepository(),
                appBadgeService: const AppBadgeService(),
                chatRepository: _FakeChatRepository(),
                chatRealtime: _FakeChatRealtime(),
                conversationRepository: _FakeConversationRepository(),
                firebaseReady: false,
                notificationRemoteDataSource: NotificationRemoteDataSource(
                  apiClient: ApiClient(baseUrl: 'http://localhost:3000'),
                ),
                profileRepository: _FakeProfileRepository(),
                pushNotificationService: const NoopPushNotificationService(),
                pushRegistrationService: _FakePushRegistrationService(),
              ),
              child: AuthScope(
                controller: authController,
                child: ProfilePage(
                  onOpenDirectConversation: (handle) async {
                    openedHandle = handle;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'peer_user');
      await tester.tap(find.text('查询联系人'));
      await tester.pumpAndSettle();

      expect(find.text('@peer_user'), findsOneWidget);

      await tester.tap(find.text('发起/打开单聊'));
      await tester.pumpAndSettle();

      expect(openedHandle, 'peer_user');
      expect(find.text('已打开单聊'), findsOneWidget);
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
      identifier: 'demo_user',
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
      deviceName: 'flutter-mobile',
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

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<DiscoverableUser> discoverByHandle({
    required String accessToken,
    required String handle,
  }) async {
    return const DiscoverableUser(
      discoverable: true,
      profile: DiscoverableProfile(
        id: 'user-2',
        nickname: 'Peer User',
        handle: 'peer_user',
        avatarUrl: null,
      ),
    );
  }

  @override
  Future<UserProfile> fetchCurrent({required String accessToken}) async {
    return const UserProfile(
      id: 'user-1',
      identifier: 'demo_user',
      nickname: 'Demo User',
      handle: 'demo_user',
      avatarUrl: null,
      discoveryMode: 'public',
    );
  }

  @override
  Future<UserProfile> updateCurrent({
    required String accessToken,
    required String nickname,
    required String? avatarUrl,
    required String discoveryMode,
  }) async {
    return UserProfile(
      id: 'user-1',
      identifier: 'demo_user',
      nickname: nickname,
      handle: 'demo_user',
      avatarUrl: avatarUrl,
      discoveryMode: discoveryMode,
    );
  }
}

class _FakeConversationRepository implements ConversationRepository {
  @override
  Future<String> createOrReuseDirectConversation({
    required String accessToken,
    required String targetHandle,
  }) async {
    return 'conversation-id';
  }

  @override
  Future<String> createGroupConversation({
    required String accessToken,
    required String title,
    required List<String> memberHandles,
  }) async {
    return 'group-conversation-id';
  }

  @override
  Future<List<ConversationSummary>> fetchRecent({
    required String accessToken,
  }) async {
    return const [];
  }

  @override
  Future<ConversationSummary?> findById({
    required String accessToken,
    required String conversationId,
  }) async {
    return null;
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
    return const ChatHistoryPage(
      messages: [],
      latestSequence: 0,
      peerReadSequenceByUserId: {},
      memberDisplayNameByUserId: {},
      memberHandleByUserId: {},
      memberAvatarUrlByUserId: {},
      peerReadUpdatedAtByUserId: {},
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
    return ChatMessage(
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: 'user-1',
      senderName: 'Demo User',
      messageKind: ChatMessageKind.text,
      content: ChatTextMessageContent(text: text),
      deliveryState: ChatMessageDeliveryState.sent,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      sequence: 1,
    );
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
      latestSequence: 0,
      nextAfterSequence: 0,
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
