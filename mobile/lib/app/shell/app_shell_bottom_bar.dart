part of 'app_shell.dart';

class _ShellBottomBar extends StatelessWidget {
  const _ShellBottomBar({
    required this.currentIndex,
    required this.messageUnreadCount,
    required this.contactBadgeCount,
    required this.onSelected,
  });

  final int currentIndex;
  final int messageUnreadCount;
  final int contactBadgeCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('消息', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
      (
        '联系人',
        Icons.perm_contact_calendar_outlined,
        Icons.perm_contact_calendar_rounded,
      ),
      ('发现', Icons.explore_outlined, Icons.explore_rounded),
      ('动态', Icons.dynamic_feed_outlined, Icons.dynamic_feed_rounded),
      ('我的', Icons.person_outline_rounded, Icons.person_rounded),
    ];

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEFF2F7))),
        ),
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++)
              Expanded(
                child: _BottomTabItem(
                  label: items[index].$1,
                  icon: items[index].$2,
                  selectedIcon: items[index].$3,
                  selected: currentIndex == index,
                  badgeCount: switch (index) {
                    0 => messageUnreadCount,
                    1 => contactBadgeCount,
                    _ => 0,
                  },
                  onTap: () {
                    onSelected(index);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomTabItem extends StatelessWidget {
  const _BottomTabItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF2F6BFF) : const Color(0xFF9CA3AF);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? selectedIcon : icon, color: color, size: 23),
                if (badgeCount > 0)
                  Positioned(
                    right: -10,
                    top: -6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF4D4F),
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
