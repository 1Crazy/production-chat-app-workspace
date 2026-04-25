part of 'chat_page.dart';

class _ReadMemberTile extends StatelessWidget {
  const _ReadMemberTile({required this.member, this.onTap});

  final ChatReadReceiptMember member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: _MemberAvatar(
        displayName: member.displayName,
        avatarUrl: member.avatarUrl,
      ),
      title: Text(member.displayName),
      titleTextStyle: Theme.of(context).textTheme.bodyLarge,
      subtitle: Text(member.hasRead ? '已读这条消息' : '尚未读到这条消息'),
      trailing: Text(member.hasRead ? '已读' : '未读'),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.displayName, required this.avatarUrl});

  final String displayName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return _RoundedMemberAvatarPlaceholder(displayName: displayName);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        avatarUrl!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _RoundedMemberAvatarPlaceholder(displayName: displayName);
        },
      ),
    );
  }
}

class _RoundedMemberAvatarPlaceholder extends StatelessWidget {
  const _RoundedMemberAvatarPlaceholder({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(displayName.characters.first),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.title,
    required this.memberCount,
    required this.onBack,
  });

  final String title;
  final int memberCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            _HeaderIconButton(icon: Icons.chevron_left_rounded, onTap: onBack),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  if (memberCount > 2)
                    Text(
                      '$memberCount人',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF9AA4B2),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const _HeaderIconButton(icon: Icons.more_horiz_rounded),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 24,
        height: 24,
        child: Icon(icon, size: 20, color: const Color(0xFF111827)),
      ),
    );
  }
}

class _ChatDateDivider extends StatelessWidget {
  const _ChatDateDivider({required this.dateTime});

  final DateTime dateTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        formatChatDateLabel(dateTime),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: const Color(0xFF98A2B3)),
      ),
    );
  }
}

bool _shouldShowDateDivider(ChatMessage? previous, ChatMessage current) {
  if (previous == null) {
    return true;
  }

  final left = previous.createdAt;
  final right = current.createdAt;

  return left.year != right.year ||
      left.month != right.month ||
      left.day != right.day;
}

class _CircleActionIcon extends StatelessWidget {
  const _CircleActionIcon({required this.icon, this.onTap});

  final IconData icon;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null
          ? null
          : () async {
              await onTap!();
            },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, size: 17, color: const Color(0xFF3C4658)),
      ),
    );
  }
}

class _ChatQuickPanel extends StatelessWidget {
  const _ChatQuickPanel();

  @override
  Widget build(BuildContext context) {
    const actions = [
      (Icons.image_outlined, '照片'),
      (Icons.camera_alt_outlined, '拍摄'),
      (Icons.videocam_outlined, '视频'),
      (Icons.calendar_today_outlined, '日程'),
      (Icons.star_border_rounded, '收藏'),
      (Icons.folder_open_outlined, '文件'),
      (Icons.description_outlined, '文档'),
      (Icons.bar_chart_rounded, '投票'),
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 16,
        children: [
          for (final action in actions)
            SizedBox(
              width: (MediaQuery.of(context).size.width - 16 * 2 - 8 * 3) / 4,
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F4F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(action.$1, color: const Color(0xFF667085)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action.$2,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: AppEmptyStateCard(
          title: '未选择会话',
          description: '请先从消息列表中选择一个会话。',
          icon: Icons.chat_bubble_outline_rounded,
        ),
      ),
    );
  }
}
