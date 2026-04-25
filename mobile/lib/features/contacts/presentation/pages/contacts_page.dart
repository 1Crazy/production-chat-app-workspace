import 'package:flutter/material.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const quickActions = [
      _QuickActionData(
        icon: Icons.person_add_alt_1_rounded,
        title: '新的朋友',
        color: Color(0xFF4C8DFF),
      ),
      _QuickActionData(
        icon: Icons.groups_2_rounded,
        title: '群聊',
        color: Color(0xFFFFB547),
      ),
      _QuickActionData(
        icon: Icons.bookmark_rounded,
        title: '标签',
        color: Color(0xFF8B7CFF),
      ),
      _QuickActionData(
        icon: Icons.campaign_rounded,
        title: '公众号',
        color: Color(0xFF4FD3A6),
      ),
    ];

    const sections = [
      _ContactSectionData(
        letter: 'A',
        contacts: [
          _ContactData(name: 'Alex', status: '在线'),
          _ContactData(name: 'Andy', status: '离线'),
        ],
      ),
      _ContactSectionData(
        letter: 'B',
        contacts: [
          _ContactData(name: 'Ben', status: '在线'),
          _ContactData(name: 'Baby', status: '离线'),
        ],
      ),
      _ContactSectionData(
        letter: 'C',
        contacts: [
          _ContactData(name: 'Catherine', status: '离线'),
          _ContactData(name: 'Chen', status: '在线'),
        ],
      ),
      _ContactSectionData(
        letter: 'J',
        contacts: [_ContactData(name: 'Jenny', status: '在线')],
      ),
      _ContactSectionData(
        letter: 'L',
        contacts: [_ContactData(name: 'Lily', status: '在线')],
      ),
      _ContactSectionData(
        letter: 'Z',
        contacts: [_ContactData(name: '张三', status: '离线')],
      ),
    ];

    const indexLetters = [
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
      'I',
      'J',
      'K',
      'L',
      'M',
      'N',
      'O',
      'P',
      'Q',
      'R',
      'S',
      'T',
      'U',
      'V',
      'W',
      'X',
      'Y',
      'Z',
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '联系人',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    _HeaderActionButton(icon: Icons.add_rounded, onTap: () {}),
                  ],
                ),
                const SizedBox(height: 14),
                const _SearchField(hintText: '搜索联系人'),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF0F2F7)),
                  ),
                  child: Column(
                    children: [
                      for (final action in quickActions) ...[
                        _QuickActionTile(data: action),
                        if (action != quickActions.last)
                          const Divider(height: 1, indent: 70, endIndent: 16),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '我的好友 (86)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final section in sections) ...[
                  _ContactSection(section: section),
                ],
              ],
            ),
            Positioned(
              right: 6,
              top: 190,
              bottom: 120,
              child: IgnorePointer(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final letter in indexLetters)
                      Text(
                        letter,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF9CA3AF),
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hintText});

  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
          const SizedBox(width: 8),
          Text(hintText, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.data});

  final _QuickActionData data;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: data.color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(data.icon, color: Colors.white, size: 20),
      ),
      title: Text(data.title),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFFC3C9D4),
      ),
      onTap: () {},
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.section});

  final _ContactSectionData section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          child: Text(
            section.letter,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF98A2B3)),
          ),
        ),
        for (final contact in section.contacts) ...[
          _ContactTile(contact: contact),
          if (contact != section.contacts.last)
            const Divider(height: 1, indent: 56),
        ],
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});

  final _ContactData contact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFEFF3FB),
            child: Text(
              contact.name.characters.first,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              contact.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            contact.status,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: contact.status == '在线'
                  ? const Color(0xFF12B76A)
                  : const Color(0xFF98A2B3),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, color: const Color(0xFF111827)),
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;
}

class _ContactSectionData {
  const _ContactSectionData({required this.letter, required this.contacts});

  final String letter;
  final List<_ContactData> contacts;
}

class _ContactData {
  const _ContactData({required this.name, required this.status});

  final String name;
  final String status;
}
