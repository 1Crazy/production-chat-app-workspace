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
import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_relationship.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_request_summary.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_summary.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_user_profile.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friendship_status.dart';
import 'package:production_chat_app/features/friendship/domain/repositories/friendship_repository.dart';
import 'package:production_chat_app/features/friendship/presentation/pages/friend_requests_page.dart';
import 'package:production_chat_app/features/friendship/presentation/pages/relationship_profile_page.dart';
import 'package:production_chat_app/features/profile/domain/entities/discoverable_user.dart';
import 'package:production_chat_app/features/profile/domain/entities/user_profile.dart';
import 'package:production_chat_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:production_chat_app/shared/notifications/app_badge_service.dart';
import 'package:production_chat_app/shared/network/api_client.dart';
import 'package:production_chat_app/shared/notifications/notification_remote_data_source.dart';
import 'package:production_chat_app/shared/notifications/push_notification_service.dart';
import 'package:production_chat_app/shared/notifications/push_registration_service.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime_event.dart';

void main() {
  testWidgets('friend requests page can search user and send friend request', (
    tester,
  ) async {
    final friendshipRepository = _FakeFriendshipRepository();
    final authController = _buildAuthController();
    await authController.bootstrap();

    await tester.pumpWidget(
      _buildTestApp(
        authController: authController,
        friendshipRepository: friendshipRepository,
        child: const FriendRequestsPage(),
      ),
    );

    await tester.enterText(find.byType(TextField), 'peer_user');
    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();

    expect(find.text('Peer User'), findsOneWidget);
    expect(find.text('添加'), findsOneWidget);

    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(friendshipRepository.createdTargetHandles, ['peer_user']);
  });

  testWidgets('friend requests page shows outgoing rejected state', (
    tester,
  ) async {
    final authController = _buildAuthController();
    await authController.bootstrap();

    await tester.pumpWidget(
      _buildTestApp(
        authController: authController,
        friendshipRepository: _FakeFriendshipRepository.withOutgoingRejected(),
        child: const FriendRequestsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已拒绝'), findsOneWidget);
    expect(find.textContaining('对方已拒绝你的好友申请'), findsOneWidget);
  });

  testWidgets('ignored incoming request keeps sender side as waiting', (
    tester,
  ) async {
    final authController = _buildAuthController();
    await authController.bootstrap();

    await tester.pumpWidget(
      _buildTestApp(
        authController: authController,
        friendshipRepository: _FakeFriendshipRepository(
          outgoingRequests: [
            FriendRequestSummary(
              id: 'request-3',
              direction: FriendRequestDirection.outgoing,
              status: 'pending',
              message: 'hi',
              createdAt: DateTime(2026, 1, 1, 10, 0),
              respondedAt: null,
              counterparty: const FriendUserProfile(
                id: 'user-2',
                nickname: 'Peer User',
                handle: 'peer_user',
                avatarUrl: null,
              ),
            ),
          ],
        ),
        child: const FriendRequestsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('等待中'), findsOneWidget);
    expect(find.textContaining('等待对方处理'), findsOneWidget);
  });

  testWidgets('incoming request card can open relationship profile', (
    tester,
  ) async {
    final authController = _buildAuthController();
    await authController.bootstrap();

    await tester.pumpWidget(
      _buildTestApp(
        authController: authController,
        friendshipRepository: _FakeFriendshipRepository.withIncomingPending(),
        child: const FriendRequestsPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Incoming User'));
    await tester.pumpAndSettle();

    expect(find.text('用户资料'), findsOneWidget);
    expect(find.textContaining('账号：incoming_user'), findsOneWidget);
  });

  testWidgets(
    'relationship profile page hides message button for non-friends',
    (tester) async {
      final authController = _buildAuthController();
      await authController.bootstrap();

      await tester.pumpWidget(
        _buildTestApp(
          authController: authController,
          friendshipRepository: _FakeFriendshipRepository(),
          profileRepository: _FakeProfileRepository(
            relationshipStatus: FriendshipStatus.none,
          ),
          child: const RelationshipProfilePage(
            handle: 'peer_user',
            displayName: 'Peer User',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('添加好友'), findsOneWidget);
      expect(find.text('发消息'), findsNothing);
    },
  );

  testWidgets('relationship profile page shows message button for friends', (
    tester,
  ) async {
    final authController = _buildAuthController();
    await authController.bootstrap();

    await tester.pumpWidget(
      _buildTestApp(
        authController: authController,
        friendshipRepository: _FakeFriendshipRepository(),
        profileRepository: _FakeProfileRepository(
          relationshipStatus: FriendshipStatus.friends,
        ),
        child: const RelationshipProfilePage(
          handle: 'peer_user',
          displayName: 'Peer User',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发消息'), findsOneWidget);
    expect(find.text('删除好友'), findsOneWidget);
  });
}

Widget _buildTestApp({
  required AuthController authController,
  required FriendshipRepository friendshipRepository,
  ProfileRepository? profileRepository,
  required Widget child,
}) {
  return AppDependenciesScope(
    dependencies: AppDependencies(
      authRepository: _FakeAuthRepository(),
      appBadgeService: const AppBadgeService(),
      chatRepository: const _NoopChatRepository(),
      chatRealtime: const _NoopChatRealtime(),
      conversationRepository: const _NoopConversationRepository(),
      firebaseReady: false,
      friendshipRepository: friendshipRepository,
      notificationRemoteDataSource: NotificationRemoteDataSource(
        apiClient: ApiClient(baseUrl: 'http://localhost:3000'),
      ),
      profileRepository: profileRepository ?? _FakeProfileRepository(),
      pushNotificationService: const NoopPushNotificationService(),
      pushRegistrationService: _FakePushRegistrationService(),
    ),
    child: AuthScope(
      controller: authController,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

AuthController _buildAuthController() {
  return AuthController(
    authRepository: _FakeAuthRepository(),
    pushRegistrationService: _FakePushRegistrationService(),
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
    return const [];
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
  Future<AuthSession?> restore() async => _session;

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

class _FakeFriendshipRepository implements FriendshipRepository {
  _FakeFriendshipRepository({
    List<FriendRequestSummary>? incomingRequests,
    List<FriendRequestSummary>? outgoingRequests,
  }) : _incomingRequests = incomingRequests ?? const [],
       _outgoingRequests = outgoingRequests ?? const [];

  factory _FakeFriendshipRepository.withOutgoingRejected() {
    return _FakeFriendshipRepository(
      outgoingRequests: [
        FriendRequestSummary(
          id: 'request-1',
          direction: FriendRequestDirection.outgoing,
          status: 'rejected',
          message: 'hi',
          createdAt: DateTime(2026, 1, 1, 10, 0),
          respondedAt: DateTime(2026, 1, 1, 10, 30),
          counterparty: const FriendUserProfile(
            id: 'user-2',
            nickname: 'Peer User',
            handle: 'peer_user',
            avatarUrl: null,
          ),
        ),
      ],
    );
  }

  factory _FakeFriendshipRepository.withIncomingPending() {
    return _FakeFriendshipRepository(
      incomingRequests: [
        FriendRequestSummary(
          id: 'request-2',
          direction: FriendRequestDirection.incoming,
          status: 'pending',
          message: '你好',
          createdAt: DateTime(2026, 1, 1, 9, 0),
          respondedAt: null,
          counterparty: const FriendUserProfile(
            id: 'user-3',
            nickname: 'Incoming User',
            handle: 'incoming_user',
            avatarUrl: null,
          ),
        ),
      ],
    );
  }

  final List<String> createdTargetHandles = [];
  final List<FriendRequestSummary> _incomingRequests;
  final List<FriendRequestSummary> _outgoingRequests;

  @override
  Future<void> acceptFriendRequest({
    required String accessToken,
    required String requestId,
  }) async {}

  @override
  Future<void> ignoreFriendRequest({
    required String accessToken,
    required String requestId,
  }) async {}

  @override
  Future<void> createFriendRequest({
    required String accessToken,
    required String targetHandle,
    String? message,
  }) async {
    createdTargetHandles.add(targetHandle);
  }

  @override
  Future<List<FriendSummary>> fetchFriends({
    required String accessToken,
  }) async {
    return const [];
  }

  @override
  Future<List<FriendRequestSummary>> fetchIncomingRequests({
    required String accessToken,
  }) async {
    return _incomingRequests;
  }

  @override
  Future<int> fetchUnreadIncomingRequestCount({
    required String accessToken,
  }) async {
    return _incomingRequests.where((item) => item.status == 'pending').length;
  }

  @override
  Future<List<FriendRequestSummary>> fetchOutgoingRequests({
    required String accessToken,
  }) async {
    return _outgoingRequests;
  }

  @override
  Future<void> rejectFriendRequest({
    required String accessToken,
    required String requestId,
  }) async {}

  @override
  Future<void> markIncomingRequestsViewed({
    required String accessToken,
  }) async {}

  @override
  Future<void> removeFriend({
    required String accessToken,
    required String friendUserId,
  }) async {}
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.relationshipStatus = FriendshipStatus.none});

  final FriendshipStatus relationshipStatus;

  @override
  Future<DiscoverableUser> discoverByHandle({
    required String accessToken,
    required String handle,
  }) async {
    final nickname = switch (handle) {
      'incoming_user' => 'Incoming User',
      _ => 'Peer User',
    };

    return DiscoverableUser(
      discoverable: true,
      profile: DiscoverableProfile(
        id: handle == 'incoming_user' ? 'user-3' : 'user-2',
        nickname: nickname,
        handle: handle,
        avatarUrl: null,
      ),
      relationship: FriendRelationship(
        status: relationshipStatus,
        pendingRequestId: relationshipStatus == FriendshipStatus.incomingPending
            ? 'request-1'
            : null,
        canMessage: relationshipStatus == FriendshipStatus.friends,
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

class _NoopChatRepository implements ChatRepository {
  const _NoopChatRepository();

  @override
  Future<Never> fetchHistory({
    required String accessToken,
    required String conversationId,
    required String currentUserId,
    int? beforeSequence,
    int limit = 20,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Never> sendText({
    required String accessToken,
    required String conversationId,
    required String clientMessageId,
    required String text,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Never> syncAfter({
    required String accessToken,
    required String conversationId,
    required int afterSequence,
    int limit = 100,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateReadCursor({
    required String accessToken,
    required String conversationId,
    required int lastReadSequence,
  }) async {}
}

class _NoopConversationRepository implements ConversationRepository {
  const _NoopConversationRepository();

  @override
  Future<String> createGroupConversation({
    required String accessToken,
    required String title,
    required List<String> memberHandles,
  }) async {
    return 'group-id';
  }

  @override
  Future<String> createOrReuseDirectConversation({
    required String accessToken,
    required String targetHandle,
  }) async {
    return 'conversation-id';
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

class _NoopChatRealtime implements ChatRealtime {
  const _NoopChatRealtime();

  @override
  Stream<ChatRealtimeConnectionState> get connectionStateStream =>
      const Stream<ChatRealtimeConnectionState>.empty();

  @override
  Stream<ChatConnectionReadyEvent> get connectionReadyStream =>
      const Stream<ChatConnectionReadyEvent>.empty();

  @override
  Stream<String> get connectionErrorStream => const Stream<String>.empty();

  @override
  Stream<ChatConversationCreatedEvent> get conversationCreatedStream =>
      const Stream<ChatConversationCreatedEvent>.empty();

  @override
  Stream<ChatMessage> get messageCreatedStream =>
      const Stream<ChatMessage>.empty();

  @override
  Stream<ChatReadCursorUpdatedEvent> get readCursorUpdatedStream =>
      const Stream<ChatReadCursorUpdatedEvent>.empty();

  @override
  Stream<ChatSessionRevokedEvent> get sessionRevokedStream =>
      const Stream<ChatSessionRevokedEvent>.empty();

  @override
  Stream<ChatTypingUpdatedEvent> get typingUpdatedStream =>
      const Stream<ChatTypingUpdatedEvent>.empty();

  @override
  void connect({required String accessToken}) {}

  @override
  void disconnect() {}

  @override
  void emitTyping({required String conversationId, required bool isTyping}) {}

  @override
  bool get isConnected => false;
}
