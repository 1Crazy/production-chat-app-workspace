import 'package:flutter/material.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies_scope.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/profile/application/profile_controller.dart';
import 'package:production_chat_app/shared/notifications/push_registration_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  ProfileController? _profileController;
  PushRegistrationService? _pushRegistrationService;
  late final TextEditingController _nicknameController;
  late final TextEditingController _avatarUrlController;
  late final TextEditingController _searchHandleController;
  String _discoveryMode = 'public';
  bool _privacyModeEnabled = false;
  bool _didBootstrap = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    _avatarUrlController = TextEditingController();
    _searchHandleController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_profileController != null) {
      return;
    }

    final dependencies = AppDependenciesScope.of(context);
    _pushRegistrationService ??= dependencies.pushRegistrationService;
    _profileController = ProfileController(
      profileRepository: dependencies.profileRepository,
    )..addListener(_syncFormFields);

    if (!_didBootstrap) {
      _didBootstrap = true;
      _loadPushPrivacyMode();
      _loadCurrentProfile();
    }
  }

  @override
  void dispose() {
    _profileController?.removeListener(_syncFormFields);
    _profileController?.dispose();
    _nicknameController.dispose();
    _avatarUrlController.dispose();
    _searchHandleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileController = _profileController;

    if (profileController == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([AuthScope.of(context), profileController]),
      builder: (context, child) {
        final authController = AuthScope.of(context);
        final sessions = authController.deviceSessions;
        final currentProfile = profileController.currentProfile;
        final discoveredUser = profileController.discoveredUser;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('个人资料', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            if (profileController.errorMessage case final message?)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (currentProfile != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentProfile.nickname,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text('@${currentProfile.handle}'),
                      const SizedBox(height: 4),
                      Text('账号标识：${currentProfile.identifier}'),
                      const SizedBox(height: 4),
                      Text('发现规则：${currentProfile.discoveryMode}'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(labelText: '昵称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _avatarUrlController,
              decoration: const InputDecoration(labelText: '头像 URL'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _discoveryMode,
              decoration: const InputDecoration(labelText: '联系人发现规则'),
              items: const [
                DropdownMenuItem(value: 'public', child: Text('public')),
                DropdownMenuItem(value: 'private', child: Text('private')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _discoveryMode = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: profileController.isBusy
                      ? null
                      : _loadCurrentProfile,
                  child: const Text('刷新资料'),
                ),
                FilledButton.tonal(
                  onPressed: profileController.isBusy ? null : _updateProfile,
                  child: const Text('保存资料'),
                ),
                FilledButton.tonal(
                  onPressed: authController.isBusy
                      ? null
                      : () async {
                          await authController.refreshSession();
                        },
                  child: const Text('刷新登录态'),
                ),
                FilledButton(
                  onPressed: authController.isBusy
                      ? null
                      : () async {
                          await authController.logout();
                        },
                  child: const Text('退出登录'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('业务标识查询', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _searchHandleController,
              decoration: const InputDecoration(
                labelText: '输入 handle，例如 demo_user',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: profileController.isBusy ? null : _discoverByHandle,
              child: const Text('查询联系人'),
            ),
            const SizedBox(height: 12),
            if (discoveredUser != null)
              Card(
                child: ListTile(
                  title: Text(discoveredUser.profile?.nickname ?? '不可发现'),
                  subtitle: Text(
                    discoveredUser.profile == null
                        ? '该用户当前不允许被发现'
                        : '@${discoveredUser.profile!.handle}',
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text('通知设置', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _privacyModeEnabled,
              title: const Text('通知隐私模式'),
              subtitle: const Text('开启后推送只显示通用提醒，不展示消息正文预览。'),
              onChanged: (value) async {
                setState(() {
                  _privacyModeEnabled = value;
                });

                final accessToken = authController.authSession?.accessToken;
                await _pushRegistrationService?.updatePrivacyMode(
                  enabled: value,
                  accessToken: accessToken,
                );
              },
            ),
            const SizedBox(height: 24),
            Text('设备会话管理', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonal(
                  onPressed: authController.isBusy
                      ? null
                      : () async {
                          await authController.loadDeviceSessions();
                        },
                  child: const Text('刷新设备列表'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sessions.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('暂无设备会话'),
                  subtitle: Text('登录成功后会在这里显示当前账号的设备列表。'),
                ),
              )
            else
              ...sessions.map((session) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      title: Text(session.deviceName),
                      subtitle: Text(
                        '创建于 ${session.createdAt}\n最近活跃 ${session.lastSeenAt}',
                      ),
                      isThreeLine: true,
                      trailing: session.isCurrent
                          ? const Chip(label: Text('当前设备'))
                          : TextButton(
                              onPressed: authController.isBusy
                                  ? null
                                  : () async {
                                      await authController.revokeSession(
                                        session.id,
                                      );
                                    },
                              child: const Text('移除'),
                            ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Future<void> _loadCurrentProfile() async {
    final authSession = AuthScope.of(context).authSession;

    if (authSession == null || _profileController == null) {
      return;
    }

    await _profileController!.loadCurrentProfile(
      accessToken: authSession.accessToken,
    );
  }

  Future<void> _updateProfile() async {
    final authSession = AuthScope.of(context).authSession;

    if (authSession == null || _profileController == null) {
      return;
    }

    await _profileController!.updateCurrentProfile(
      accessToken: authSession.accessToken,
      nickname: _nicknameController.text.trim(),
      avatarUrl: _avatarUrlController.text.trim().isEmpty
          ? null
          : _avatarUrlController.text.trim(),
      discoveryMode: _discoveryMode,
    );
  }

  Future<void> _discoverByHandle() async {
    final authSession = AuthScope.of(context).authSession;

    if (authSession == null || _profileController == null) {
      return;
    }

    await _profileController!.discoverByHandle(
      accessToken: authSession.accessToken,
      handle: _searchHandleController.text.trim(),
    );
  }

  Future<void> _loadPushPrivacyMode() async {
    final pushRegistrationService = _pushRegistrationService;

    if (pushRegistrationService == null) {
      return;
    }

    final privacyModeEnabled =
        await pushRegistrationService.loadPrivacyModeEnabled();

    if (!mounted) {
      return;
    }

    setState(() {
      _privacyModeEnabled = privacyModeEnabled;
    });
  }

  void _syncFormFields() {
    final currentProfile = _profileController?.currentProfile;

    if (currentProfile == null) {
      return;
    }

    _nicknameController.text = currentProfile.nickname;
    _avatarUrlController.text = currentProfile.avatarUrl ?? '';
    _discoveryMode = currentProfile.discoveryMode;
  }
}
