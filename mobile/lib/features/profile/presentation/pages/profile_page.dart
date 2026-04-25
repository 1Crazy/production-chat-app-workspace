import 'package:flutter/material.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies_scope.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/profile/application/profile_controller.dart';
import 'package:production_chat_app/shared/notifications/push_registration_service.dart';
import 'package:production_chat_app/shared/widgets/status_surfaces.dart';

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

class _SettingsTopBar extends StatelessWidget {
  const _SettingsTopBar({required this.canPop});

  final bool canPop;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: canPop
              ? IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                )
              : null,
        ),
        Expanded(
          child: Text(
            '设置',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.nickname,
    required this.handle,
    required this.identifier,
    required this.avatarUrl,
  });

  final String nickname;
  final String handle;
  final String identifier;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0F2F7)),
      ),
      child: Row(
        children: [
          _ProfileAvatar(nickname: nickname, avatarUrl: avatarUrl, size: 72),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '账号：$identifier',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF98A2B3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '聊天号：$handle',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              color: Color(0xFF111827),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.nickname,
    required this.avatarUrl,
    required this.size,
  });

  final String nickname;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FF),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          nickname.characters.first,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF2F6BFF),
            fontSize: 24,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.network(
        avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              nickname.characters.first,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF2F6BFF),
                fontSize: 24,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF0F2F7)),
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsFieldTile extends StatelessWidget {
  const _SettingsFieldTile({
    required this.label,
    required this.controller,
    required this.hintText,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF111827)),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF111827)),
              decoration: InputDecoration(
                hintText: hintText,
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsDropdownTile extends StatelessWidget {
  const _SettingsDropdownTile({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                alignment: Alignment.centerRight,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFC3C9D4),
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 58,
      visualDensity: const VisualDensity(vertical: -2),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF2F6BFF)),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFFC3C9D4),
      ),
      onTap: onTap == null
          ? null
          : () async {
              await onTap!();
            },
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      visualDensity: const VisualDensity(vertical: -2),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _EmptyDeviceCard extends StatelessWidget {
  const _EmptyDeviceCard();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyStateCard(
      title: '暂无设备',
      description: '登录后会在这里显示当前账号的设备列表。',
      icon: Icons.devices_other_rounded,
    );
  }
}

class _DeviceSessionCard extends StatelessWidget {
  const _DeviceSessionCard({
    required this.deviceName,
    required this.createdAt,
    required this.lastSeenAt,
    required this.isCurrent,
    required this.onRemove,
  });

  final String deviceName;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final bool isCurrent;
  final Future<void> Function()? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0F2F7)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.smartphone_rounded,
              color: Color(0xFF2F6BFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '创建于 ${_formatDate(createdAt)}\n最近活跃 ${_formatDate(lastSeenAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          isCurrent
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '当前设备',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF2F6BFF),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: () async {
                    await onRemove?.call();
                  },
                  child: const Text('移除此设备'),
                ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
