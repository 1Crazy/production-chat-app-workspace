import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies_scope.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_read_receipt_member.dart';
import 'package:production_chat_app/features/profile/domain/entities/discoverable_user.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('成员资料')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: _MemberAvatar(
              displayName: displayName,
              avatarUrl: avatarUrl,
              size: 96,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              displayName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '@$handle',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 24),
          if (_errorMessage case final message?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(message),
                ),
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('消息状态'),
            subtitle: Text(
              widget.member.readAt == null
                  ? '尚未读到这条消息'
                  : _formatRelativeReadAt(widget.member.readAt!),
            ),
            trailing: Text(widget.member.hasRead ? '已读' : '未读'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('发现状态'),
            subtitle: Text(
              _discoveredUser == null
                  ? (_isLoading ? '加载中...' : '尚未查询')
                  : (_discoveredUser!.discoverable ? '可发现' : '当前不可发现'),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: _isLoading ? null : _loadProfile,
            child: Text(_isLoading ? '刷新中...' : '刷新资料'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _handleOpenDirectConversation,
            child: const Text('发起/打开单聊'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _handleCopyHandle,
            child: const Text('复制 handle'),
          ),
        ],
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
        _errorMessage = error.toString();
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制 handle')));
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
      return CircleAvatar(
        radius: size / 2,
        child: Text(displayName.characters.first),
      );
    }

    return ClipOval(
      child: Image.network(
        avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return CircleAvatar(
            radius: size / 2,
            child: Text(displayName.characters.first),
          );
        },
      ),
    );
  }
}

String _formatRelativeReadAt(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inSeconds < 60) {
    return '刚刚已读';
  }

  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} 分钟前已读';
  }

  if (difference.inHours < 24) {
    return '${difference.inHours} 小时前已读';
  }

  if (difference.inDays < 7) {
    return '${difference.inDays} 天前已读';
  }

  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute 已读';
}
