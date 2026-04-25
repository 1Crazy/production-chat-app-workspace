import 'package:flutter/material.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies_scope.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/profile/application/profile_controller.dart';
import 'package:production_chat_app/shared/notifications/push_registration_service.dart';
import 'package:production_chat_app/shared/widgets/status_surfaces.dart';

part 'profile_header_widgets.dart';
part 'profile_settings_widgets.dart';
part 'profile_device_widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.onOpenDirectConversation});

  final Future<void> Function(String handle)? onOpenDirectConversation;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  ProfileController? _profileController;
  PushRegistrationService? _pushRegistrationService;
  late final TextEditingController _nicknameController;
  late final TextEditingController _avatarUrlController;
  String _discoveryMode = 'public';
  bool _privacyModeEnabled = false;
  bool _didBootstrap = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    _avatarUrlController = TextEditingController();
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

        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FC),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _SettingsTopBar(canPop: Navigator.of(context).canPop()),
                const SizedBox(height: 8),
                if (currentProfile != null)
                  _ProfileHeaderCard(
                    nickname: currentProfile.nickname,
                    handle: currentProfile.handle,
                    identifier: currentProfile.identifier,
                    avatarUrl: currentProfile.avatarUrl,
                  ),
                if (profileController.errorMessage case final message?) ...[
                  const SizedBox(height: 12),
                  AppInlineNotice(message: message, tone: AppStatusTone.error),
                ],
                const SizedBox(height: 16),
                _SettingsSection(
                  title: '资料编辑',
                  children: [
                    _SettingsFieldTile(
                      label: '昵称',
                      controller: _nicknameController,
                      hintText: '请输入昵称',
                    ),
                    _SettingsFieldTile(
                      label: '头像地址',
                      controller: _avatarUrlController,
                      hintText: '请输入头像地址',
                    ),
                    _SettingsDropdownTile(
                      label: '发现规则',
                      value: _discoveryMode,
                      items: const [
                        DropdownMenuItem(value: 'public', child: Text('允许搜索')),
                        DropdownMenuItem(value: 'private', child: Text('不可搜索')),
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
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: profileController.isBusy ? null : _updateProfile,
                  child: Text(profileController.isBusy ? '保存中...' : '保存资料'),
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: '通知与设备',
                  children: [
                    _SettingsSwitchTile(
                      title: '通知隐私',
                      subtitle: '隐藏消息内容',
                      value: _privacyModeEnabled,
                      onChanged: (value) async {
                        setState(() {
                          _privacyModeEnabled = value;
                        });

                        final accessToken =
                            authController.authSession?.accessToken;
                        await _pushRegistrationService?.updatePrivacyMode(
                          enabled: value,
                          accessToken: accessToken,
                        );
                      },
                    ),
                    _SettingsActionTile(
                      icon: Icons.refresh_rounded,
                      title: '刷新设备列表',
                      subtitle: '重新读取当前账号的设备会话',
                      onTap: authController.isBusy
                          ? null
                          : () async {
                              await authController.loadDeviceSessions();
                            },
                    ),
                    _SettingsActionTile(
                      icon: Icons.key_rounded,
                      title: '刷新登录态',
                      subtitle: '手动刷新当前登录状态',
                      onTap: authController.isBusy
                          ? null
                          : () async {
                              await authController.refreshSession();
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (sessions.isEmpty)
                  const _EmptyDeviceCard()
                else
                  ...sessions.map((session) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DeviceSessionCard(
                        deviceName: session.deviceName,
                        createdAt: session.createdAt,
                        lastSeenAt: session.lastSeenAt,
                        isCurrent: session.isCurrent,
                        onRemove: session.isCurrent
                            ? null
                            : () async {
                                await authController.revokeSession(session.id);
                              },
                      ),
                    );
                  }),
                const SizedBox(height: 22),
                TextButton(
                  onPressed: authController.isBusy
                      ? null
                      : () async {
                          await authController.logout();
                        },
                  child: const Text(
                    '退出当前账号',
                    style: TextStyle(color: Color(0xFFFF4D4F)),
                  ),
                ),
              ],
            ),
          ),
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

  Future<void> _loadPushPrivacyMode() async {
    final pushRegistrationService = _pushRegistrationService;

    if (pushRegistrationService == null) {
      return;
    }

    final privacyModeEnabled = await pushRegistrationService
        .loadPrivacyModeEnabled();

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
