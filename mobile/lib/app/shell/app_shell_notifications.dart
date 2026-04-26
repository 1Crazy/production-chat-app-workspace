part of 'app_shell.dart';

extension _AppShellNotifications on _AppShellState {
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
      _updateShellState(() {
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

    _updateShellState(() {
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
      _updateShellState(() {
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
      _updateShellState(() {
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

    _activateConversation(conversation);
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
    _updateShellState(() {
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

    _updateShellState(() {
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
