import 'dart:async';

import 'package:flutter/material.dart';
import 'package:production_chat_app/features/activity/presentation/pages/activity_page.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies_scope.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/chat/presentation/pages/chat_page.dart';
import 'package:production_chat_app/features/contacts/presentation/pages/contacts_page.dart';
import 'package:production_chat_app/features/conversation/presentation/pages/conversation_list_page.dart';
import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/features/discover/presentation/pages/discover_page.dart';
import 'package:production_chat_app/features/friendship/presentation/pages/friend_requests_page.dart';
import 'package:production_chat_app/features/me/presentation/pages/me_home_page.dart';
import 'package:production_chat_app/features/profile/presentation/pages/profile_page.dart';
import 'package:production_chat_app/shared/config/app_environment.dart';
import 'package:production_chat_app/shared/network/api_client.dart';
import 'package:production_chat_app/shared/notifications/app_badge_service.dart';
import 'package:production_chat_app/shared/notifications/notification_sync_state.dart';
import 'package:production_chat_app/shared/notifications/push_notification_service.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime_event.dart';
import 'package:production_chat_app/shared/widgets/status_surfaces.dart';

part 'app_shell_bottom_bar.dart';
part 'app_shell_banners.dart';
part 'app_shell_composer_widgets.dart';
part 'app_shell_conversation_actions.dart';
part 'app_shell_notifications.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.environment});

  final AppEnvironment environment;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  ConversationSummary? _selectedConversation;
  int _conversationReloadToken = 0;
  int _chatReloadToken = 0;
  int _totalUnreadCount = 0;
  int _pendingFriendRequestCount = 0;
  AppBadgeService? _appBadgeService;
  ChatRealtime? _chatRealtime;
  PushNotificationService? _pushNotificationService;
  String? _activeRealtimeToken;
  String? _activeFriendshipToken;
  Map<String, int> _knownConversationLatestSequenceById = const {};
  StreamSubscription<dynamic>? _sessionRevokedSubscription;
  StreamSubscription<ChatRealtimeConnectionState>? _connectionStateSubscription;
  StreamSubscription<String>? _connectionErrorSubscription;
  StreamSubscription<PushNotificationForegroundEvent>?
  _pushForegroundMessageSubscription;
  StreamSubscription<PushNotificationIntent>? _pushTapSubscription;
  ChatRealtimeConnectionState _realtimeConnectionState =
      ChatRealtimeConnectionState.disconnected;
  String? _lastRealtimeErrorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dependencies = AppDependenciesScope.of(context);
    _appBadgeService = dependencies.appBadgeService;

    if (_chatRealtime == dependencies.chatRealtime) {
      return;
    }

    _sessionRevokedSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _connectionErrorSubscription?.cancel();
    _chatRealtime = dependencies.chatRealtime;
    _bindPushNotificationService(dependencies.pushNotificationService);
    _sessionRevokedSubscription = _chatRealtime?.sessionRevokedStream.listen((
      _,
    ) async {
      if (!mounted) {
        return;
      }

      await AuthScope.of(context).handleSessionRevoked();
    });
    _connectionStateSubscription = _chatRealtime?.connectionStateStream.listen((
      state,
    ) {
      if (!mounted) {
        return;
      }

      setState(() {
        _realtimeConnectionState = state;
        if (state == ChatRealtimeConnectionState.connected) {
          _lastRealtimeErrorMessage = null;
        }
      });
    });
    _connectionErrorSubscription = _chatRealtime?.connectionErrorStream.listen((
      errorMessage,
    ) {
      if (!mounted) {
        return;
      }

      setState(() {
        _lastRealtimeErrorMessage = errorMessage;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authController = AuthScope.of(context);
    final dependencies = AppDependenciesScope.of(context);
    final accessToken = authController.authSession?.accessToken;
    final currentUserId = authController.authSession?.user.id;
    final currentUser = authController.authSession?.user;

    if (accessToken == null || currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _ensureRealtimeConnected(accessToken);
    _ensureFriendRequestCountLoaded(accessToken);
    final messageTopBanner = _buildMessageTopBanner(
      firebaseReady: dependencies.firebaseReady,
    );

    final pages = <Widget>[
      _selectedConversation == null
          ? ConversationListPage(
              accessToken: accessToken,
              conversationRepository: dependencies.conversationRepository,
              chatRealtime: dependencies.chatRealtime,
              currentUserId: currentUserId,
              onItemsChanged: _handleConversationItemsChanged,
              selectedConversationId: _selectedConversation?.id,
              isVisible: _currentIndex == 0,
              reloadToken: _conversationReloadToken,
              topBanner: messageTopBanner,
              onComposeTap: () async {
                await _showConversationComposerSheet(accessToken);
              },
              onConversationSelected: (conversation) {
                _activateConversation(conversation);
              },
            )
          : ChatPage(
              accessToken: accessToken,
              currentUserId: currentUserId,
              chatRepository: dependencies.chatRepository,
              chatRealtime: dependencies.chatRealtime,
              topBanner: messageTopBanner,
              onBackToConversationList: () {
                setState(() {
                  _selectedConversation = null;
                  _currentIndex = 0;
                });
              },
              selectedConversation: _selectedConversation,
              reloadToken: _chatReloadToken,
              onConversationChanged: () {
                setState(() {
                  _conversationReloadToken += 1;
                });
              },
              onOpenDirectConversation: (handle) async {
                await _openDirectConversation(
                  handle: handle,
                  accessToken: accessToken,
                );
              },
            ),
      ContactsPage(
        pendingRequestCount: _pendingFriendRequestCount,
        onOpenDirectConversation: (handle) async {
          await _openDirectConversation(
            handle: handle,
            accessToken: accessToken,
          );
        },
        onFriendshipStateChanged: () async {
          await _refreshFriendRequestCount(accessToken);
        },
      ),
      const DiscoverPage(),
      const ActivityPage(),
      MeHomePage(
        nickname: currentUser?.nickname ?? widget.environment.appName,
        identifier:
            currentUser?.identifier ?? '环境: ${widget.environment.flavor}',
        onOpenSettings: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) {
                return ProfilePage(
                  onOpenDirectConversation: (handle) async {
                    await _openDirectConversation(
                      handle: handle,
                      accessToken: accessToken,
                    );
                  },
                );
              },
            ),
          );
        },
        onLogout: () async {
          await authController.logout();
        },
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _selectedConversation != null
          ? null
          : _ShellBottomBar(
              currentIndex: _currentIndex,
              messageUnreadCount: _totalUnreadCount,
              contactBadgeCount: _pendingFriendRequestCount,
              onSelected: (index) {
                setState(() {
                  _currentIndex = index;
                  if (index != 0) {
                    _selectedConversation = null;
                  }
                });
                unawaited(_refreshFriendRequestCount(accessToken));
              },
            ),
    );
  }

  @override
  void dispose() {
    unawaited(_appBadgeService?.updateBadgeCount(0) ?? Future<void>.value());
    _sessionRevokedSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _connectionErrorSubscription?.cancel();
    _pushForegroundMessageSubscription?.cancel();
    _pushTapSubscription?.cancel();
    _chatRealtime?.disconnect();
    super.dispose();
  }

  void _updateShellState(VoidCallback callback) {
    setState(callback);
  }
}
