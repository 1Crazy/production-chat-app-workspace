import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies_scope.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/friendship/application/relationship_profile_controller.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friendship_status.dart';
import 'package:production_chat_app/shared/widgets/status_surfaces.dart';

class RelationshipProfilePage extends StatefulWidget {
  const RelationshipProfilePage({
    super.key,
    required this.handle,
    required this.displayName,
    this.avatarUrl,
  });

  final String handle;
  final String displayName;
  final String? avatarUrl;

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
                const SizedBox(height: 18),
                ..._buildActionSection(
                  controller: controller,
                  status: status,
                  handle: handle,
                  friendUserId: profile?.id,
                  pendingRequestId: relationship?.pendingRequestId,
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
                      handle: handle,
                      friendUserId: friendUserId,
                    );
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
                      await controller.sendFriendRequest(
                        accessToken: accessToken,
                        handle: handle,
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
                          await controller.rejectRequest(
                            accessToken: accessToken,
                            handle: handle,
                            requestId: pendingRequestId,
                          );
                        },
                  child: const Text('忽略'),
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
