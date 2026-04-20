import 'dart:async';

import 'package:flutter/material.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies_scope.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/chat/presentation/pages/chat_page.dart';
import 'package:production_chat_app/features/conversation/presentation/pages/conversation_list_page.dart';
import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/features/media/presentation/pages/media_center_page.dart';
import 'package:production_chat_app/features/profile/presentation/pages/profile_page.dart';
import 'package:production_chat_app/shared/config/app_environment.dart';
import 'package:production_chat_app/shared/constants/app_constants.dart';
import 'package:production_chat_app/shared/notifications/push_notification_service.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime_event.dart';

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
  ChatRealtime? _chatRealtime;
  PushNotificationService? _pushNotificationService;
  String? _activeRealtimeToken;
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

      await AuthScope.of(context).logout();
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

    if (accessToken == null || currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _ensureRealtimeConnected(accessToken);

    final pages = <Widget>[
      ConversationListPage(
        accessToken: accessToken,
        conversationRepository: dependencies.conversationRepository,
        chatRealtime: dependencies.chatRealtime,
        currentUserId: currentUserId,
        selectedConversationId: _selectedConversation?.id,
        isVisible: _currentIndex == 0,
        reloadToken: _conversationReloadToken,
        onConversationSelected: (conversation) {
          setState(() {
            _selectedConversation = conversation;
            _currentIndex = 1;
          });
        },
      ),
      ChatPage(
        accessToken: accessToken,
        currentUserId: currentUserId,
        chatRepository: dependencies.chatRepository,
        chatRealtime: dependencies.chatRealtime,
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
      const MediaCenterPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.environment.appName)),
      body: Column(
        children: [
          if (!dependencies.firebaseReady) const _FirebaseConfigurationBanner(),
          if (_realtimeConnectionState !=
                  ChatRealtimeConnectionState.connected ||
              _lastRealtimeErrorMessage != null)
            _RealtimeStatusBanner(
              state: _realtimeConnectionState,
              message: _lastRealtimeErrorMessage,
            ),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: '会话',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '消息',
          ),
          NavigationDestination(
            icon: Icon(Icons.perm_media_outlined),
            selectedIcon: Icon(Icons.perm_media),
            label: '媒体',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    authController.authSession?.user.nickname ??
                        widget.environment.appName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authController.authSession?.user.identifier ??
                        '环境: ${widget.environment.flavor}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const ListTile(
              title: Text('当前阶段'),
              subtitle: Text(AppConstants.phaseOneGoal),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('退出登录'),
              onTap: () async {
                Navigator.of(context).pop();
                await authController.logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sessionRevokedSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _connectionErrorSubscription?.cancel();
    _pushForegroundMessageSubscription?.cancel();
    _pushTapSubscription?.cancel();
    _chatRealtime?.disconnect();
    super.dispose();
  }

  void _ensureRealtimeConnected(String accessToken) {
    if (_activeRealtimeToken == accessToken) {
      return;
    }

    _activeRealtimeToken = accessToken;
    _chatRealtime?.connect(accessToken: accessToken);
  }

  Future<void> _openDirectConversation({
    required String handle,
    required String accessToken,
  }) async {
    final dependencies = AppDependenciesScope.of(context);
    final conversationId = await dependencies.conversationRepository
        .createOrReuseDirectConversation(
          accessToken: accessToken,
          targetHandle: handle,
        );
    final recentConversations = await dependencies.conversationRepository
        .fetchRecent(accessToken: accessToken);
    ConversationSummary? conversation;

    for (final item in recentConversations) {
      if (item.id == conversationId) {
        conversation = item;
        break;
      }
    }

    if (!mounted || conversation == null) {
      return;
    }

    setState(() {
      _selectedConversation = conversation;
      _currentIndex = 1;
      _conversationReloadToken += 1;
      _chatReloadToken += 1;
    });
  }

  void _bindPushNotificationService(
    PushNotificationService pushNotificationService,
  ) {
    if (_pushNotificationService == pushNotificationService) {
      return;
    }

    _pushForegroundMessageSubscription?.cancel();
    _pushTapSubscription?.cancel();
    _pushNotificationService = pushNotificationService;
    _pushForegroundMessageSubscription = pushNotificationService
        .foregroundMessageStream
        .listen(_handleForegroundPushMessage);
    _pushTapSubscription = pushNotificationService.notificationTapStream.listen(
      (intent) {
        unawaited(_openConversationFromPushIntent(intent));
      },
    );

    final initialIntent = pushNotificationService
        .takeInitialNotificationIntent();

    if (initialIntent != null) {
      unawaited(_openConversationFromPushIntent(initialIntent));
    }
  }

  void _handleForegroundPushMessage(PushNotificationForegroundEvent event) {
    if (!mounted) {
      return;
    }

    setState(() {
      _conversationReloadToken += 1;
      if (event.intent.conversationId == _selectedConversation?.id) {
        _chatReloadToken += 1;
      }
    });

    final title = event.intent.title ?? '收到新消息';
    final body = event.intent.body ?? '点击查看最新会话动态';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.maybeOf(context);

      if (messenger == null) {
        return;
      }

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('$title\n$body'),
          duration: const Duration(seconds: 4),
          action: event.intent.hasConversationTarget
              ? SnackBarAction(
                  label: '查看',
                  onPressed: () {
                    unawaited(_openConversationFromPushIntent(event.intent));
                  },
                )
              : null,
        ),
      );
    });
  }

  Future<void> _openConversationFromPushIntent(
    PushNotificationIntent intent,
  ) async {
    if (!mounted) {
      return;
    }

    final authController = AuthScope.of(context);
    final accessToken = authController.authSession?.accessToken;
    final conversationId = intent.conversationId;

    if (accessToken == null) {
      return;
    }

    if (conversationId == null || conversationId.isEmpty) {
      setState(() {
        _currentIndex = 0;
        _conversationReloadToken += 1;
      });
      return;
    }

    final dependencies = AppDependenciesScope.of(context);
    final conversation = await dependencies.conversationRepository.findById(
      accessToken: accessToken,
      conversationId: conversationId,
    );

    if (!mounted) {
      return;
    }

    if (conversation == null) {
      setState(() {
        _currentIndex = 0;
        _conversationReloadToken += 1;
      });

      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(const SnackBar(content: Text('未找到目标会话，已刷新会话列表')));
      return;
    }

    setState(() {
      _selectedConversation = conversation;
      _currentIndex = 1;
      _conversationReloadToken += 1;
      _chatReloadToken += 1;
    });
  }
}

class _RealtimeStatusBanner extends StatelessWidget {
  const _RealtimeStatusBanner({required this.state, required this.message});

  final ChatRealtimeConnectionState state;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bannerColor = switch (state) {
      ChatRealtimeConnectionState.connected => colorScheme.primaryContainer,
      ChatRealtimeConnectionState.connecting => colorScheme.secondaryContainer,
      ChatRealtimeConnectionState.disconnected => colorScheme.errorContainer,
    };
    final statusText = switch (state) {
      ChatRealtimeConnectionState.connected => '实时已连接',
      ChatRealtimeConnectionState.connecting => '实时连接中...',
      ChatRealtimeConnectionState.disconnected => '实时连接已断开',
    };

    return Container(
      width: double.infinity,
      color: bannerColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        message == null ? statusText : '$statusText: $message',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _FirebaseConfigurationBanner extends StatelessWidget {
  const _FirebaseConfigurationBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: colorScheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        '推送未完成配置：请执行 flutterfire configure，并放置 Android/iOS Firebase 平台配置文件。',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
