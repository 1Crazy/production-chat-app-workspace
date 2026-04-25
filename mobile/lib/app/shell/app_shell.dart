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
                setState(() {
                  _selectedConversation = conversation;
                  _currentIndex = 0;
                });
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
      bottomNavigationBar: _ShellBottomBar(
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

  void _ensureRealtimeConnected(String accessToken) {
    if (_activeRealtimeToken == accessToken) {
      return;
    }

    _activeRealtimeToken = accessToken;
    _chatRealtime?.connect(accessToken: accessToken);
  }

  void _ensureFriendRequestCountLoaded(String accessToken) {
    if (_activeFriendshipToken == accessToken) {
      return;
    }

    _activeFriendshipToken = accessToken;
    unawaited(_refreshFriendRequestCount(accessToken));
  }

  Future<void> _refreshFriendRequestCount(String accessToken) async {
    final dependencies = AppDependenciesScope.of(context);

    try {
      final unseenCount = await dependencies.friendshipRepository
          .fetchUnreadIncomingRequestCount(accessToken: accessToken);

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingFriendRequestCount = unseenCount;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _pendingFriendRequestCount = 0;
      });
    }
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
      _currentIndex = 0;
      _conversationReloadToken += 1;
      _chatReloadToken += 1;
    });
  }

  Future<void> _createGroupConversation({
    required String title,
    required List<String> memberHandles,
    required String accessToken,
  }) async {
    final dependencies = AppDependenciesScope.of(context);
    final conversationId = await dependencies.conversationRepository
        .createGroupConversation(
          accessToken: accessToken,
          title: title,
          memberHandles: memberHandles,
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
      _currentIndex = 0;
      _conversationReloadToken += 1;
      _chatReloadToken += 1;
    });
  }

  Future<void> _showConversationComposerSheet(String accessToken) async {
    final action = await showModalBottomSheet<_ConversationComposerAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ConversationComposerTile(
                  icon: Icons.person_add_alt_1_rounded,
                  title: '添加好友',
                  subtitle: '搜索账号并发送好友申请',
                  onTap: () {
                    Navigator.of(
                      context,
                    ).pop(_ConversationComposerAction.addFriend);
                  },
                ),
                const SizedBox(height: 12),
                _ConversationComposerTile(
                  icon: Icons.groups_2_rounded,
                  title: '新群聊',
                  subtitle: '输入群名和多个账号，创建群聊',
                  onTap: () {
                    Navigator.of(
                      context,
                    ).pop(_ConversationComposerAction.group);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _ConversationComposerAction.addFriend:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) {
              return const FriendRequestsPage();
            },
          ),
        );
        if (!mounted) {
          return;
        }
        await _refreshFriendRequestCount(accessToken);
        break;
      case _ConversationComposerAction.group:
        await _showCreateGroupConversationDialog(accessToken);
        break;
    }
  }

  Future<void> _showCreateGroupConversationDialog(String accessToken) async {
    final payload = await showDialog<_CreateGroupConversationPayload>(
      context: context,
      builder: (context) {
        return const _CreateGroupConversationDialog();
      },
    );

    if (payload == null || !mounted) {
      return;
    }

    if (payload.title.isEmpty) {
      _showFeedback('请输入群聊名称');
      return;
    }

    if (payload.memberHandles.length < 2) {
      _showFeedback('群聊至少需要 2 名其他成员');
      return;
    }

    try {
      await _createGroupConversation(
        title: payload.title,
        memberHandles: payload.memberHandles,
        accessToken: accessToken,
      );
      _showFeedback('群聊已创建');
    } catch (error) {
      _showFeedback(formatDisplayError(error));
    }
  }

  void _showFeedback(String message) {
    showAppStatusSnackBar(
      context,
      message: message,
      tone: AppStatusTone.success,
    );
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

    if (event.intent.badgeCount != null) {
      setState(() {
        _totalUnreadCount = event.intent.badgeCount!;
      });
    }

    final conversationId = event.intent.conversationId;
    final latestSequence = event.intent.latestSequence;

    if (conversationId != null &&
        conversationId.isNotEmpty &&
        latestSequence != null) {
      _knownConversationLatestSequenceById = {
        ..._knownConversationLatestSequenceById,
        conversationId: latestSequence,
      };
    }

    unawaited(_synchronizeNotificationState(event.intent));

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

      showAppStatusSnackBar(
        context,
        message: '$title\n$body',
        tone: AppStatusTone.info,
        actionLabel: event.intent.hasConversationTarget ? '查看' : null,
        onAction: event.intent.hasConversationTarget
            ? () {
                unawaited(_openConversationFromPushIntent(event.intent));
              }
            : null,
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
    final dependencies = AppDependenciesScope.of(context);

    if (accessToken == null) {
      return;
    }

    await _synchronizeNotificationState(
      intent,
      accessTokenOverride: accessToken,
    );

    if (conversationId == null || conversationId.isEmpty) {
      setState(() {
        _currentIndex = 0;
        _conversationReloadToken += 1;
      });
      return;
    }

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

      showAppStatusSnackBar(
        context,
        message: '未找到目标会话，已刷新会话列表',
        tone: AppStatusTone.warning,
      );
      return;
    }

    setState(() {
      _selectedConversation = conversation;
      _currentIndex = 0;
      _conversationReloadToken += 1;
      _chatReloadToken += 1;
    });
  }

  Future<void> _synchronizeNotificationState(
    PushNotificationIntent intent, {
    String? accessTokenOverride,
  }) async {
    if (!mounted) {
      return;
    }

    final authController = AuthScope.of(context);
    final accessToken =
        accessTokenOverride ?? authController.authSession?.accessToken;

    if (accessToken == null) {
      return;
    }

    final conversationId = intent.conversationId;
    final dependencies = AppDependenciesScope.of(context);
    final conversationStates =
        conversationId != null && conversationId.isNotEmpty
        ? [
            {
              'conversationId': conversationId,
              'afterSequence':
                  _knownConversationLatestSequenceById[conversationId] ?? 0,
            },
          ]
        : const <Map<String, Object?>>[];

    try {
      final syncState = await dependencies.notificationRemoteDataSource
          .syncState(
            accessToken: accessToken,
            conversationStates: conversationStates,
            pushMessageId: intent.messageId,
          );

      if (!mounted) {
        return;
      }

      _applyNotificationSyncState(syncState);
    } catch (_) {
      // 推送恢复失败不阻断用户继续使用，后续页面刷新和 realtime 重连会继续追平。
    }
  }

  void _applyNotificationSyncState(NotificationSyncState syncState) {
    setState(() {
      _totalUnreadCount = syncState.unreadBadgeCount;
      _knownConversationLatestSequenceById = {
        ..._knownConversationLatestSequenceById,
        for (final item in syncState.conversationStates)
          item.conversationId: item.latestSequence,
      };
      _conversationReloadToken += 1;
      if (_selectedConversation != null) {
        _chatReloadToken += 1;
      }
    });
    _syncAppBadgeCount(syncState.unreadBadgeCount);
  }

  void _handleConversationItemsChanged(List<ConversationSummary> items) {
    if (!mounted) {
      return;
    }

    setState(() {
      _totalUnreadCount = items.fold(0, (sum, item) => sum + item.unreadCount);
      _knownConversationLatestSequenceById = {
        for (final item in items) item.id: item.latestSequence,
      };
    });
    _syncAppBadgeCount(_totalUnreadCount);
  }

  void _syncAppBadgeCount(int count) {
    unawaited(
      _appBadgeService?.updateBadgeCount(count) ?? Future<void>.value(),
    );
  }

  Widget? _buildMessageTopBanner({required bool firebaseReady}) {
    if (firebaseReady &&
        _realtimeConnectionState == ChatRealtimeConnectionState.connected &&
        _lastRealtimeErrorMessage == null) {
      return null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!firebaseReady) const _FirebaseConfigurationBanner(),
        if (_realtimeConnectionState != ChatRealtimeConnectionState.connected ||
            _lastRealtimeErrorMessage != null)
          _RealtimeStatusBanner(
            state: _realtimeConnectionState,
            message: _lastRealtimeErrorMessage,
          ),
      ],
    );
  }
}

class _ShellBottomBar extends StatelessWidget {
  const _ShellBottomBar({
    required this.currentIndex,
    required this.messageUnreadCount,
    required this.contactBadgeCount,
    required this.onSelected,
  });

  final int currentIndex;
  final int messageUnreadCount;
  final int contactBadgeCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('消息', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
      (
        '联系人',
        Icons.perm_contact_calendar_outlined,
        Icons.perm_contact_calendar_rounded,
      ),
      ('发现', Icons.explore_outlined, Icons.explore_rounded),
      ('动态', Icons.dynamic_feed_outlined, Icons.dynamic_feed_rounded),
      ('我的', Icons.person_outline_rounded, Icons.person_rounded),
    ];

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEFF2F7))),
        ),
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++)
              Expanded(
                child: _BottomTabItem(
                  label: items[index].$1,
                  icon: items[index].$2,
                  selectedIcon: items[index].$3,
                  selected: currentIndex == index,
                  badgeCount: switch (index) {
                    0 => messageUnreadCount,
                    1 => contactBadgeCount,
                    _ => 0,
                  },
                  onTap: () {
                    onSelected(index);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomTabItem extends StatelessWidget {
  const _BottomTabItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF2F6BFF) : const Color(0xFF9CA3AF);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? selectedIcon : icon, color: color, size: 23),
                if (badgeCount > 0)
                  Positioned(
                    right: -10,
                    top: -6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF4D4F),
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RealtimeStatusBanner extends StatelessWidget {
  const _RealtimeStatusBanner({required this.state, required this.message});

  final ChatRealtimeConnectionState state;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (state) {
      ChatRealtimeConnectionState.connected => '实时连接正常',
      ChatRealtimeConnectionState.connecting => '实时连接中...',
      ChatRealtimeConnectionState.disconnected => '实时连接已断开',
    };

    return AppInlineNotice(
      message: message == null ? statusText : '$statusText：$message',
      tone: switch (state) {
        ChatRealtimeConnectionState.connected => AppStatusTone.success,
        ChatRealtimeConnectionState.connecting => AppStatusTone.info,
        ChatRealtimeConnectionState.disconnected => AppStatusTone.error,
      },
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    );
  }
}

class _FirebaseConfigurationBanner extends StatelessWidget {
  const _FirebaseConfigurationBanner();

  @override
  Widget build(BuildContext context) {
    return const AppInlineNotice(
      message: '推送配置未完成：请执行 flutterfire configure，并补齐移动端推送配置文件。',
      tone: AppStatusTone.warning,
      margin: EdgeInsets.fromLTRB(16, 8, 16, 0),
    );
  }
}

enum _ConversationComposerAction { addFriend, group }

class _ConversationComposerTile extends StatelessWidget {
  const _ConversationComposerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF6FAF9),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFD6F2EB),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF0F766E)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateGroupConversationPayload {
  const _CreateGroupConversationPayload({
    required this.title,
    required this.memberHandles,
  });

  final String title;
  final List<String> memberHandles;
}

class _CreateDirectConversationDialog extends StatefulWidget {
  const _CreateDirectConversationDialog();

  @override
  State<_CreateDirectConversationDialog> createState() =>
      _CreateDirectConversationDialogState();
}

class _CreateDirectConversationDialogState
    extends State<_CreateDirectConversationDialog> {
  late final TextEditingController _handleController;

  @override
  void initState() {
    super.initState();
    _handleController = TextEditingController();
  }

  @override
  void dispose() {
    _handleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建单聊'),
      content: TextField(
        controller: _handleController,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '对方账号',
          hintText: '例如 测试用户1',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_handleController.text.trim());
          },
          child: const Text('进入聊天'),
        ),
      ],
    );
  }
}

class _CreateGroupConversationDialog extends StatefulWidget {
  const _CreateGroupConversationDialog();

  @override
  State<_CreateGroupConversationDialog> createState() =>
      _CreateGroupConversationDialogState();
}

class _CreateGroupConversationDialogState
    extends State<_CreateGroupConversationDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _handlesController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _handlesController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _handlesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建群聊'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '群聊名称',
                hintText: '例如 设计评审群',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _handlesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '成员账号',
                hintText: '用逗号、空格或换行分隔，例如 测试用户1,测试用户2',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final memberHandles = _handlesController.text
                .split(RegExp(r'[\s,，]+'))
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false);
            Navigator.of(context).pop(
              _CreateGroupConversationPayload(
                title: _titleController.text.trim(),
                memberHandles: memberHandles,
              ),
            );
          },
          child: const Text('确认创建'),
        ),
      ],
    );
  }
}
