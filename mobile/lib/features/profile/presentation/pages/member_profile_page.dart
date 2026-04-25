import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies_scope.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_read_receipt_member.dart';
import 'package:production_chat_app/features/profile/domain/entities/discoverable_user.dart';
import 'package:production_chat_app/shared/network/api_client.dart';
import 'package:production_chat_app/shared/widgets/status_surfaces.dart';

class MemberProfilePage extends StatefulWidget {
  const MemberProfilePage({super.key, required this.member});

  final ChatReadReceiptMember member;

  @override
  State<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends State<MemberProfilePage> {
  DiscoverableUser? _discoveredUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _didBootstrap = false;
  bool _muteEnabled = false;
  bool _pinEnabled = false;
  bool _blockEnabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didBootstrap) {
      return;
    }

    _didBootstrap = true;
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _discoveredUser?.profile;
    final displayName = profile?.nickname ?? widget.member.displayName;
    final handle = profile?.handle ?? widget.member.handle;
    final avatarUrl = profile?.avatarUrl ?? widget.member.avatarUrl;
    final discoverableLabel = _discoveredUser == null
        ? (_isLoading ? '加载中' : '待查询')
        : (_discoveredUser!.discoverable ? '可被搜索' : '不可被搜索');

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
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
                Expanded(
                  child: Text(
                    '用户资料',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _MemberAvatar(
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF98A2B3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.member.hasRead ? '已读' : '未读',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: widget.member.hasRead
                              ? const Color(0xFF12B76A)
                              : const Color(0xFF98A2B3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_errorMessage case final message?) ...[
              const SizedBox(height: 14),
              AppInlineNotice(message: message, tone: AppStatusTone.error),
            ],
            const SizedBox(height: 18),
            _ProfileActionSection(
              children: [
                _ProfileActionTile(
                  icon: Icons.edit_note_rounded,
                  title: '设置备注和标签',
                  subtitle: '为联系人补充备注信息',
                  onTap: () {},
                ),
                _ProfileActionTile(
                  icon: Icons.photo_library_outlined,
                  title: '朋友圈',
                  subtitle: '暂未开放',
                  onTap: () {},
                ),
                _ProfileActionTile(
                  icon: Icons.info_outline_rounded,
                  title: '更多信息',
                  subtitle: '发现状态：$discoverableLabel',
                  onTap: _isLoading ? null : _loadProfile,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ProfileActionSection(
              children: [
                _ProfileSwitchTile(
                  icon: Icons.notifications_off_outlined,
                  title: '消息免打扰',
                  value: _muteEnabled,
                  onChanged: (value) {
                    setState(() {
                      _muteEnabled = value;
                    });
                  },
                ),
                _ProfileSwitchTile(
                  icon: Icons.push_pin_outlined,
                  title: '置顶聊天',
                  value: _pinEnabled,
                  onChanged: (value) {
                    setState(() {
                      _pinEnabled = value;
                    });
                  },
                ),
                _ProfileSwitchTile(
                  icon: Icons.block_outlined,
                  title: '加入黑名单',
                  value: _blockEnabled,
                  onChanged: (value) {
                    setState(() {
                      _blockEnabled = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _handleOpenDirectConversation,
                    child: const Text('发起单聊'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleCopyHandle,
                    child: const Text('复制账号'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                '移除联系人',
                style: TextStyle(color: Color(0xFFFF4D4F)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadProfile() async {
    final authSession = AuthScope.of(context).authSession;

    if (authSession == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dependencies = AppDependenciesScope.of(context);
      final discoveredUser = await dependencies.profileRepository
          .discoverByHandle(
            accessToken: authSession.accessToken,
            handle: widget.member.handle,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _discoveredUser = discoveredUser;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = formatDisplayError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleOpenDirectConversation() {
    Navigator.of(context).pop(widget.member.handle);
  }

  Future<void> _handleCopyHandle() async {
    await Clipboard.setData(ClipboardData(text: widget.member.handle));

    if (!mounted) {
      return;
    }

    showAppStatusSnackBar(
      context,
      message: '已复制账号',
      tone: AppStatusTone.success,
    );
  }
}

class _ProfileActionSection extends StatelessWidget {
  const _ProfileActionSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0F2F7)),
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
    );
  }
}

class _ProfileSwitchTile extends StatelessWidget {
  const _ProfileSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF2F6BFF)),
      ),
      title: Text(title),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.displayName,
    required this.avatarUrl,
    this.size = 40,
  });

  final String displayName;
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
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Center(
          child: Text(
            displayName.characters.first,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF2F6BFF),
              fontSize: size * 0.32,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.32),
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
              borderRadius: BorderRadius.circular(size * 0.32),
            ),
            child: Center(
              child: Text(
                displayName.characters.first,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF2F6BFF),
                  fontSize: size * 0.32,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
