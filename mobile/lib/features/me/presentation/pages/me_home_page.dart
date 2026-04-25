import 'package:flutter/material.dart';

class MeHomePage extends StatelessWidget {
  const MeHomePage({
    super.key,
    required this.nickname,
    required this.identifier,
    required this.onOpenSettings,
    required this.onLogout,
  });

  final String nickname;
  final String identifier;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    const entries = [
      (Icons.verified_user_outlined, '账号与安全'),
      (Icons.lock_outline_rounded, '隐私设置'),
      (Icons.notifications_none_rounded, '通知设置'),
      (Icons.tune_rounded, '通用设置'),
      (Icons.chat_bubble_outline_rounded, '聊天设置'),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FAFF), Color(0xFFF7F8FC)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      nickname.characters.first,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: const Color(0xFF2F6BFF)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '账号：$identifier',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onOpenSettings,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  for (final entry in entries) ...[
                    _MeEntryTile(
                      icon: entry.$1,
                      title: entry.$2,
                      onTap: onOpenSettings,
                    ),
                    if (entry != entries.last)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _MeEntryTile(
                    icon: Icons.settings_outlined,
                    title: '进入设置',
                    onTap: onOpenSettings,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _MeEntryTile(
                    icon: Icons.info_outline_rounded,
                    title: '关于我们',
                    trailingText: 'v1.2.0',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () async {
                await onLogout();
              },
              child: const Text(
                '退出登录',
                style: TextStyle(color: Color(0xFFFF4D4F)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeEntryTile extends StatelessWidget {
  const _MeEntryTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF2F6BFF), size: 20),
      ),
      title: Text(title),
      trailing: trailingText == null
          ? const Icon(Icons.chevron_right_rounded, color: Color(0xFFB6BECF))
          : Text(trailingText!, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
