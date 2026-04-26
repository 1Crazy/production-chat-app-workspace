import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies_scope.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/friendship/application/relationship_profile_controller.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_request_summary.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friendship_status.dart';
import 'package:production_chat_app/shared/widgets/status_surfaces.dart';

class RelationshipProfilePage extends StatefulWidget {
  const RelationshipProfilePage({
    super.key,
    required this.handle,
    required this.displayName,
    this.avatarUrl,
    this.initialRequest,
  });

  final String handle;
  final String displayName;
  final String? avatarUrl;
  final FriendRequestSummary? initialRequest;

  @override
  State<RelationshipProfilePage> createState() =>
      _RelationshipProfilePageState();
}

class _RelationshipProfilePageState extends State<RelationshipProfilePage> {
  RelationshipProfileController? _controller;
  bool _didBootstrap = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controller != null) {
      return;
    }

    final dependencies = AppDependenciesScope.of(context);
    _controller = RelationshipProfileController(
      profileRepository: dependencies.profileRepository,
      friendshipRepository: dependencies.friendshipRepository,
    );

    if (!_didBootstrap) {
      _didBootstrap = true;
      _load();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final discoveredUser = controller.user;
        final profile = discoveredUser?.profile;
        final relationship = discoveredUser?.relationship;
        final displayName = profile?.nickname ?? widget.displayName;
        final handle = profile?.handle ?? widget.handle;
        final avatarUrl = profile?.avatarUrl ?? widget.avatarUrl;
        final status = relationship?.status ?? FriendshipStatus.none;
        final activeRequest = widget.initialRequest;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '用户资料',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _ProfileAvatar(
                      displayName: displayName,
                      avatarUrl: avatarUrl,
                      size: 78,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '账号：$handle',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF98A2B3)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _relationshipLabel(status),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF98A2B3)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (controller.errorMessage case final message?) ...[
                  const SizedBox(height: 14),
                  AppInlineNotice(message: message, tone: AppStatusTone.error),
                ],
                const SizedBox(height: 20),
                _InfoTile(
                  icon: Icons.info_outline_rounded,
                  title: '资料状态',
                  subtitle: discoveredUser?.discoverable == true
                      ? '可被搜索'
                      : '不可被搜索',
                ),
                if (activeRequest != null) ...[
                  const SizedBox(height: 14),
                  _RequestHistoryCard(request: activeRequest),
                ],
                const SizedBox(height: 18),
                ..._buildActionSection(
                  controller: controller,
                  status: status,
                  handle: handle,
                  friendUserId: profile?.id,
                  pendingRequestId:
                      relationship?.pendingRequestId ?? activeRequest?.id,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _load() async {
    final accessToken = AuthScope.of(context).authSession?.accessToken;

    if (accessToken == null || _controller == null) {
      return;
    }

    await _controller!.load(accessToken: accessToken, handle: widget.handle);
  }

  List<Widget> _buildActionSection({
    required RelationshipProfileController controller,
    required FriendshipStatus status,
    required String handle,
    required String? friendUserId,
    required String? pendingRequestId,
  }) {
    final accessToken = AuthScope.of(context).authSession?.accessToken;

    if (accessToken == null) {
      return const [];
    }

    switch (status) {
      case FriendshipStatus.friends:
        return [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: controller.isLoading
                      ? null
                      : () {
                          Navigator.of(context).pop(handle);
                        },
                  child: const Text('发消息'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: handle));

                    if (!mounted) {
                      return;
                    }

                    showAppStatusSnackBar(
                      context,
                      message: '账号已复制',
                      tone: AppStatusTone.success,
                    );
                  },
                  child: const Text('复制账号'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: controller.isLoading || friendUserId == null
                ? null
                : () async {
                    await controller.removeFriend(
                      accessToken: accessToken,
                      friendUserId: friendUserId,
                    );

                    if (!mounted || controller.errorMessage != null) {
                      return;
                    }

                    Navigator.of(context).pop(true);
                  },
            child: const Text(
              '删除好友',
              style: TextStyle(color: Color(0xFFFF4D4F)),
            ),
          ),
        ];
      case FriendshipStatus.none:
        return [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: controller.isLoading
                  ? null
                  : () async {
                      final requestMessage =
                          await _showFriendRequestMessageComposer();

                      if (requestMessage == null) {
                        return;
                      }

                      await controller.sendFriendRequest(
                        accessToken: accessToken,
                        handle: handle,
                        message: requestMessage,
                      );
                    },
              child: const Text('添加好友'),
            ),
          ),
        ];
      case FriendshipStatus.outgoingPending:
        return [
          const SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: null, child: Text('等待验证')),
          ),
        ];
      case FriendshipStatus.incomingPending:
        return [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: controller.isLoading || pendingRequestId == null
                      ? null
                      : () async {
                          await controller.acceptRequest(
                            accessToken: accessToken,
                            handle: handle,
                            requestId: pendingRequestId,
                          );
                        },
                  child: const Text('通过'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.isLoading || pendingRequestId == null
                      ? null
                      : () async {
                          final rejectReason =
                              await _showRejectReasonComposer();

                          if (rejectReason == null) {
                            return;
                          }

                          await controller.rejectRequest(
                            accessToken: accessToken,
                            handle: handle,
                            requestId: pendingRequestId,
                            rejectReason: rejectReason,
                          );
                        },
                  child: const Text('拒绝'),
                ),
              ),
            ],
          ),
        ];
      case FriendshipStatus.self:
        return const [];
    }
  }

  String _relationshipLabel(FriendshipStatus status) {
    switch (status) {
      case FriendshipStatus.self:
        return '这是你自己';
      case FriendshipStatus.none:
        return '尚未建立好友关系';
      case FriendshipStatus.outgoingPending:
        return '好友申请已发送';
      case FriendshipStatus.incomingPending:
        return '对方向你发来了好友申请';
      case FriendshipStatus.friends:
        return '已是好友';
    }
  }

  Future<String?> _showFriendRequestMessageComposer() async {
    final controller = TextEditingController();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('申请备注', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '可以简单介绍一下自己，选填',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(controller.text.trim());
                      },
                      child: const Text('发送申请'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return result;
  }

  Future<String?> _showRejectReasonComposer() async {
    final controller = TextEditingController();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('拒绝理由', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '可以给对方留一句说明，选填',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(controller.text.trim());
                      },
                      child: const Text('确认拒绝'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return result;
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.displayName,
    required this.avatarUrl,
    required this.size,
  });

  final String displayName;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().characters.first;

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFE8EEF9),
      backgroundImage: avatarUrl == null || avatarUrl!.trim().isEmpty
          ? null
          : NetworkImage(avatarUrl!),
      child: avatarUrl == null || avatarUrl!.trim().isEmpty
          ? Text(
              label,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF2F6BFF),
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      tileColor: const Color(0xFFF8F9FC),
      leading: Icon(icon, color: const Color(0xFF2F6BFF)),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _RequestHistoryCard extends StatelessWidget {
  const _RequestHistoryCard({required this.request});

  final FriendRequestSummary request;

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
          Text('申请记录', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            _statusLabel(request),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF98A2B3)),
          ),
          if (request.message != null &&
              request.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('备注', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(request.message!),
          ],
          if (request.rejectReason != null &&
              request.rejectReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('拒绝理由', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(request.rejectReason!),
          ],
        ],
      ),
    );
  }

  String _statusLabel(FriendRequestSummary request) {
    switch (request.status) {
      case 'accepted':
        return request.direction == FriendRequestDirection.outgoing
            ? '对方已通过你的申请'
            : '你已通过这条申请';
      case 'rejected':
        return request.direction == FriendRequestDirection.outgoing
            ? '对方已拒绝你的申请'
            : '你已拒绝这条申请';
      case 'ignored':
        return '这条申请已忽略';
      case 'pending':
      default:
        return request.direction == FriendRequestDirection.outgoing
            ? '等待对方处理'
            : '等待你处理';
    }
  }
}
