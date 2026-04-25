part of 'member_profile_page.dart';

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
      return _MemberAvatarPlaceholder(displayName: displayName, size: size);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.32),
      child: Image.network(
        avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _MemberAvatarPlaceholder(displayName: displayName, size: size);
        },
      ),
    );
  }
}

class _MemberAvatarPlaceholder extends StatelessWidget {
  const _MemberAvatarPlaceholder({
    required this.displayName,
    required this.size,
  });

  final String displayName;
  final double size;

  @override
  Widget build(BuildContext context) {
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
}
