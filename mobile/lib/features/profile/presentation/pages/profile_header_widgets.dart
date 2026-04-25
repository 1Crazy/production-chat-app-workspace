part of 'profile_page.dart';

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
      return _ProfileAvatarPlaceholder(nickname: nickname, size: size);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.network(
        avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _ProfileAvatarPlaceholder(nickname: nickname, size: size);
        },
      ),
    );
  }
}

class _ProfileAvatarPlaceholder extends StatelessWidget {
  const _ProfileAvatarPlaceholder({required this.nickname, required this.size});

  final String nickname;
  final double size;

  @override
  Widget build(BuildContext context) {
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
}
