part of 'app_shell.dart';

extension _AppShellConversationActions on _AppShellState {
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

      _updateShellState(() {
        _pendingFriendRequestCount = unseenCount;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _updateShellState(() {
        _pendingFriendRequestCount = 0;
      });
    }
  }

  Future<void> _openDirectConversation({
    required String handle,
    required String accessToken,
  }) async {
    final conversation = await _createOrFindConversation(
      accessToken: accessToken,
      createConversation: () {
        return AppDependenciesScope.of(
          context,
        ).conversationRepository.createOrReuseDirectConversation(
          accessToken: accessToken,
          targetHandle: handle,
        );
      },
    );

    _activateConversation(conversation);
  }

  Future<void> _createGroupConversation({
    required String title,
    required List<String> memberHandles,
    required String accessToken,
  }) async {
    final conversation = await _createOrFindConversation(
      accessToken: accessToken,
      createConversation: () {
        return AppDependenciesScope.of(
          context,
        ).conversationRepository.createGroupConversation(
          accessToken: accessToken,
          title: title,
          memberHandles: memberHandles,
        );
      },
    );

    _activateConversation(conversation);
  }

  Future<ConversationSummary?> _createOrFindConversation({
    required String accessToken,
    required Future<String> Function() createConversation,
  }) async {
    final dependencies = AppDependenciesScope.of(context);
    final conversationId = await createConversation();
    final recentConversations = await dependencies.conversationRepository
        .fetchRecent(accessToken: accessToken);

    for (final item in recentConversations) {
      if (item.id == conversationId) {
        return item;
      }
    }

    return null;
  }

  void _activateConversation(ConversationSummary? conversation) {
    if (!mounted || conversation == null) {
      return;
    }

    final clearedUnreadCount = conversation.unreadCount > _totalUnreadCount
        ? _totalUnreadCount
        : conversation.unreadCount;
    final nextConversation = conversation.copyWith(unreadCount: 0);

    _updateShellState(() {
      _selectedConversation = nextConversation;
      _currentIndex = 0;
      _totalUnreadCount -= clearedUnreadCount;
      _knownConversationLatestSequenceById = {
        ..._knownConversationLatestSequenceById,
        nextConversation.id: nextConversation.latestSequence,
      };
      _conversationReloadToken += 1;
      _chatReloadToken += 1;
    });
    _syncAppBadgeCount(_totalUnreadCount);
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
}
