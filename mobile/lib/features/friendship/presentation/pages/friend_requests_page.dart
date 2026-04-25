import 'package:flutter/material.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies_scope.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/friendship/application/friend_requests_controller.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friendship_status.dart';
import 'package:production_chat_app/features/friendship/presentation/pages/relationship_profile_page.dart';
import 'package:production_chat_app/features/profile/application/profile_controller.dart';
import 'package:production_chat_app/shared/widgets/status_surfaces.dart';

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({super.key});

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  FriendRequestsController? _requestsController;
  ProfileController? _profileController;
  late final TextEditingController _handleController;
  bool _didBootstrap = false;

  @override
  void initState() {
    super.initState();
    _handleController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_requestsController != null && _profileController != null) {
      return;
    }

    final dependencies = AppDependenciesScope.of(context);
    _requestsController = FriendRequestsController(
      friendshipRepository: dependencies.friendshipRepository,
    );
    _profileController = ProfileController(
      profileRepository: dependencies.profileRepository,
    );

    if (!_didBootstrap) {
      _didBootstrap = true;
      _load();
    }
  }

  @override
  void dispose() {
    _handleController.dispose();
    _requestsController?.dispose();
    _profileController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requestsController = _requestsController;
    final profileController = _profileController;

    if (requestsController == null || profileController == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([requestsController, profileController]),
      builder: (context, child) {
        final searchResult = profileController.discoveredUser;
        final accessToken = AuthScope.of(context).authSession?.accessToken;

        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text('新的朋友'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _SearchCard(
                controller: _handleController,
                onSearch: accessToken == null || profileController.isBusy
                    ? null
                    : () async {
                        await profileController.discoverByHandle(
                          accessToken: accessToken,
                          handle: _handleController.text.trim(),
                        );
                      },
              ),
              if (profileController.errorMessage case final message?) ...[
                const SizedBox(height: 12),
                AppInlineNotice(message: message, tone: AppStatusTone.error),
              ],
              if (searchResult?.profile case final profile?) ...[
                const SizedBox(height: 14),
                _SearchResultCard(
                  nickname: profile.nickname,
                  handle: profile.handle,
                  relationshipLabel: _relationshipLabel(
                    searchResult!.relationship.status,
                  ),
                  primaryActionLabel: _primaryActionLabel(
                    searchResult.relationship.status,
                  ),
                  onPrimaryAction:
                      accessToken == null ||
                          requestsController.isLoading ||
                          searchResult.relationship.status !=
                              FriendshipStatus.none
                      ? null
                      : () async {
                          await requestsController.createFriendRequest(
                            accessToken: accessToken,
                            targetHandle: profile.handle,
                          );
                          await profileController.discoverByHandle(
                            accessToken: accessToken,
                            handle: profile.handle,
                          );
                          await requestsController.load(
                            accessToken: accessToken,
                            silent: true,
                          );
                        },
                ),
              ],
              const SizedBox(height: 18),
              Text('收到的申请', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              if (requestsController.incomingRequests.isEmpty)
                const _EmptyPanel(message: '暂时没有新的好友申请')
              else
                ...requestsController.incomingRequests.map((request) {
                  final isPending = request.status == 'pending';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _IncomingRequestCard(
                      nickname: request.counterparty.nickname,
                      handle: request.counterparty.handle,
                      message: request.message,
                      status: request.status,
                      respondedAt: request.respondedAt,
                      onOpenProfile: () async {
                        await _openProfile(
                          handle: request.counterparty.handle,
                          displayName: request.counterparty.nickname,
                          avatarUrl: request.counterparty.avatarUrl,
                        );
                      },
                      onIgnore:
                          accessToken == null ||
                              requestsController.isLoading ||
                              !isPending
                          ? null
                          : () async {
                              await requestsController.ignoreRequest(
                                accessToken: accessToken,
                                requestId: request.id,
                              );
                            },
                      onAccept:
                          accessToken == null ||
                              requestsController.isLoading ||
                              !isPending
                          ? null
                          : () async {
                              await requestsController.acceptRequest(
                                accessToken: accessToken,
                                requestId: request.id,
                              );
                            },
                      onReject:
                          accessToken == null ||
                              requestsController.isLoading ||
                              !isPending
                          ? null
                          : () async {
                              await requestsController.rejectRequest(
                                accessToken: accessToken,
                                requestId: request.id,
                              );
                            },
                    ),
                  );
                }),
              const SizedBox(height: 18),
              Text('我的申请', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              if (requestsController.outgoingRequests.isEmpty)
                const _EmptyPanel(message: '暂时没有发出的好友申请')
              else
                ...requestsController.outgoingRequests.map((request) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OutgoingRequestCard(
                      nickname: request.counterparty.nickname,
                      handle: request.counterparty.handle,
                      status: request.status,
                      respondedAt: request.respondedAt,
                      onOpenProfile: () async {
                        await _openProfile(
                          handle: request.counterparty.handle,
                          displayName: request.counterparty.nickname,
                          avatarUrl: request.counterparty.avatarUrl,
                        );
                      },
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _load() async {
    final accessToken = AuthScope.of(context).authSession?.accessToken;
    final dependencies = AppDependenciesScope.of(context);

    if (accessToken == null || _requestsController == null) {
      return;
    }

    await _requestsController!.load(accessToken: accessToken);
    await dependencies.friendshipRepository.markIncomingRequestsViewed(
      accessToken: accessToken,
    );
  }

  Future<void> _openProfile({
    required String handle,
    required String displayName,
    required String? avatarUrl,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return RelationshipProfilePage(
            handle: handle,
            displayName: displayName,
            avatarUrl: avatarUrl,
          );
        },
      ),
    );
    await _load();
  }

  String _relationshipLabel(FriendshipStatus status) {
    switch (status) {
      case FriendshipStatus.none:
        return '尚未建立好友关系';
      case FriendshipStatus.outgoingPending:
        return '申请已发送';
      case FriendshipStatus.incomingPending:
        return '对方已向你发起申请';
      case FriendshipStatus.friends:
        return '已是好友';
      case FriendshipStatus.self:
        return '这是你自己';
    }
  }

  String _primaryActionLabel(FriendshipStatus status) {
    switch (status) {
      case FriendshipStatus.none:
        return '添加';
      case FriendshipStatus.outgoingPending:
        return '等待验证';
      case FriendshipStatus.incomingPending:
        return '待处理';
      case FriendshipStatus.friends:
        return '已添加';
      case FriendshipStatus.self:
        return '本人';
    }
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({required this.controller, required this.onSearch});

  final TextEditingController controller;
  final Future<void> Function()? onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F2F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('添加好友', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '输入对方聊天号/账号',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onSearch, child: const Text('搜索')),
          ),
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.nickname,
    required this.handle,
    required this.relationshipLabel,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
  });

  final String nickname;
  final String handle;
  final String relationshipLabel;
  final String primaryActionLabel;
  final Future<void> Function()? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      tileColor: Colors.white,
      title: Text(nickname),
      subtitle: Text('$handle\n$relationshipLabel'),
      isThreeLine: true,
      trailing: FilledButton(
        onPressed: onPrimaryAction,
        child: Text(primaryActionLabel),
      ),
    );
  }
}

class _IncomingRequestCard extends StatelessWidget {
  const _IncomingRequestCard({
    required this.nickname,
    required this.handle,
    required this.message,
    required this.status,
    required this.respondedAt,
    this.onOpenProfile,
    required this.onIgnore,
    required this.onAccept,
    required this.onReject,
  });

  final String nickname;
  final String handle;
  final String? message;
  final String status;
  final DateTime? respondedAt;
  final Future<void> Function()? onOpenProfile;
  final Future<void> Function()? onIgnore;
  final Future<void> Function()? onAccept;
  final Future<void> Function()? onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F2F7)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpenProfile == null
            ? null
            : () async {
                await onOpenProfile!();
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nickname, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('@$handle', style: Theme.of(context).textTheme.bodySmall),
            if (message != null && message!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message!),
            ],
            if (status != 'pending') ...[
              const SizedBox(height: 8),
              Text(
                _historyLabel(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF98A2B3)),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onIgnore == null
                        ? null
                        : () async {
                            await onIgnore!();
                          },
                    child: const Text('忽略'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject == null
                        ? null
                        : () async {
                            await onReject!();
                          },
                    child: const Text('拒绝'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept == null
                        ? null
                        : () async {
                            await onAccept!();
                          },
                    child: const Text('接受'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _historyLabel() {
    final timeLabel = respondedAt == null
        ? ''
        : ' ${respondedAt!.hour.toString().padLeft(2, '0')}:${respondedAt!.minute.toString().padLeft(2, '0')}';

    switch (status) {
      case 'accepted':
        return '你已通过该好友申请$timeLabel';
      case 'rejected':
        return '你已拒绝该好友申请$timeLabel';
      case 'ignored':
        return '你已忽略该好友申请';
      case 'pending':
      default:
        return '等待你处理';
    }
  }
}

class _OutgoingRequestCard extends StatelessWidget {
  const _OutgoingRequestCard({
    required this.nickname,
    required this.handle,
    required this.status,
    required this.respondedAt,
    this.onOpenProfile,
  });

  final String nickname;
  final String handle;
  final String status;
  final DateTime? respondedAt;
  final Future<void> Function()? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      tileColor: Colors.white,
      onTap: onOpenProfile == null
          ? null
          : () async {
              await onOpenProfile!();
            },
      title: Text(nickname),
      subtitle: Text('@$handle\n${_statusLabel()}'),
      isThreeLine: true,
      trailing: Text(
        _shortStatusLabel(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: _statusColor(),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _statusLabel() {
    final timeLabel = respondedAt == null
        ? ''
        : ' ${respondedAt!.hour.toString().padLeft(2, '0')}:${respondedAt!.minute.toString().padLeft(2, '0')}';

    switch (status) {
      case 'accepted':
        return '对方已通过你的好友申请$timeLabel';
      case 'rejected':
        return '对方已拒绝你的好友申请$timeLabel';
      case 'pending':
      default:
        return '等待对方处理';
    }
  }

  String _shortStatusLabel() {
    switch (status) {
      case 'accepted':
        return '已通过';
      case 'rejected':
        return '已拒绝';
      case 'pending':
      default:
        return '等待中';
    }
  }

  Color _statusColor() {
    switch (status) {
      case 'accepted':
        return const Color(0xFF12B76A);
      case 'rejected':
        return const Color(0xFF98A2B3);
      case 'pending':
      default:
        return const Color(0xFF2F6BFF);
    }
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F2F7)),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
