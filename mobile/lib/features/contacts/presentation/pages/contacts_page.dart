import 'package:flutter/material.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies_scope.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/friendship/application/friendship_contacts_controller.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_summary.dart';
import 'package:production_chat_app/features/friendship/presentation/pages/friend_requests_page.dart';
import 'package:production_chat_app/features/friendship/presentation/pages/relationship_profile_page.dart';
import 'package:production_chat_app/shared/widgets/status_surfaces.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({
    super.key,
    this.onOpenDirectConversation,
    this.onFriendshipStateChanged,
    this.pendingRequestCount = 0,
  });

  final Future<void> Function(String handle)? onOpenDirectConversation;
  final Future<void> Function()? onFriendshipStateChanged;
  final int pendingRequestCount;

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  FriendshipContactsController? _controller;
  bool _didBootstrap = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controller != null) {
      return;
    }

    final dependencies = AppDependenciesScope.of(context);
    _controller = FriendshipContactsController(
      friendshipRepository: dependencies.friendshipRepository,
    );

    if (!_didBootstrap) {
      _didBootstrap = true;
      _load();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final sections = _buildSections(controller.friends);

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
                        _HeaderActionButton(
                          icon: Icons.refresh_rounded,
                          onTap: controller.isLoading
                              ? null
                              : () async {
                                  await _load(silent: true);
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _SearchHintField(hintText: '我的好友仅展示已通过申请的联系人'),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF0F2F7)),
                      ),
                      child: Column(
                        children: [
                          _QuickActionTile(
                            data: _QuickActionData(
                              icon: Icons.person_add_alt_1_rounded,
                              title: '新的朋友',
                              color: const Color(0xFF4C8DFF),
                              badgeCount: widget.pendingRequestCount,
                            ),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) {
                                    return const FriendRequestsPage();
                                  },
                                ),
                              );
                              await _load(silent: true);
                              if (widget.onFriendshipStateChanged != null) {
                                await widget.onFriendshipStateChanged!();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    if (controller.errorMessage case final message?) ...[
                      const SizedBox(height: 12),
                      AppInlineNotice(
                        message: message,
                        tone: AppStatusTone.error,
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      '我的好友 (${controller.friends.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (controller.isLoading && controller.friends.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (sections.isEmpty)
                      const _EmptyFriendsPanel()
                    else
                      for (final section in sections)
                        _ContactSection(
                          section: section,
                          onOpenDirectConversation:
                              widget.onOpenDirectConversation,
                        ),
                  ],
                ),
                if (sections.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 190,
                    bottom: 120,
                    child: IgnorePointer(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final section in sections)
                            Text(
                              section.letter,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
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
      },
    );
  }

  Future<void> _load({bool silent = false}) async {
    final accessToken = AuthScope.of(context).authSession?.accessToken;

    if (accessToken == null || _controller == null) {
      return;
    }

    await _controller!.load(accessToken: accessToken, silent: silent);
  }

  List<_ContactSectionData> _buildSections(List<FriendSummary> friends) {
    final grouped = <String, List<FriendSummary>>{};

    for (final friend in friends) {
      final source = friend.profile.nickname.trim().isNotEmpty
          ? friend.profile.nickname.trim()
          : friend.profile.handle.trim();
      final letter = source.characters.first.toUpperCase();
      final normalizedLetter = RegExp(r'^[A-Z]$').hasMatch(letter)
          ? letter
          : '#';
      grouped.putIfAbsent(normalizedLetter, () => []).add(friend);
    }

    final letters = grouped.keys.toList()..sort();

    return letters
        .map((letter) {
          final items = grouped[letter]!
            ..sort((left, right) {
              return left.profile.nickname.compareTo(right.profile.nickname);
            });

          return _ContactSectionData(letter: letter, contacts: items);
        })
        .toList(growable: false);
  }
}

class _SearchHintField extends StatelessWidget {
  const _SearchHintField({required this.hintText});

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
  const _QuickActionTile({required this.data, this.onTap});

  final _QuickActionData data;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: data.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: Colors.white, size: 20),
          ),
          if (data.badgeCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF4D4F),
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Text(
                  data.badgeCount > 99 ? '99+' : '${data.badgeCount}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(data.title),
      subtitle: data.badgeCount > 0
          ? Text('你有 ${data.badgeCount} 条新的好友申请')
          : null,
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

class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.section, this.onOpenDirectConversation});

  final _ContactSectionData section;
  final Future<void> Function(String handle)? onOpenDirectConversation;

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
          _ContactTile(
            friend: contact,
            onOpenDirectConversation: onOpenDirectConversation,
          ),
          if (contact != section.contacts.last)
            const Divider(height: 1, indent: 56),
        ],
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.friend, this.onOpenDirectConversation});

  final FriendSummary friend;
  final Future<void> Function(String handle)? onOpenDirectConversation;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () async {
        final handle = await Navigator.of(context).push<String?>(
          MaterialPageRoute<String?>(
            builder: (context) {
              return RelationshipProfilePage(
                handle: friend.profile.handle,
                displayName: friend.profile.nickname,
                avatarUrl: friend.profile.avatarUrl,
              );
            },
          ),
        );

        if (handle == null || onOpenDirectConversation == null) {
          return;
        }

        await onOpenDirectConversation!(handle);
      },
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE8EEF9),
        child: Text(friend.profile.nickname.characters.first),
      ),
      title: Text(friend.profile.nickname),
      subtitle: Text('@${friend.profile.handle}'),
      trailing: Text(
        '好友',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: const Color(0xFF12B76A)),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({required this.icon, this.onTap});

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
        width: 34,
        height: 34,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF111827)),
      ),
    );
  }
}

class _EmptyFriendsPanel extends StatelessWidget {
  const _EmptyFriendsPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0F2F7)),
      ),
      child: Text(
        '暂时还没有好友，先去“新的朋友”里搜索并添加吧。',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.icon,
    required this.title,
    required this.color,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final Color color;
  final int badgeCount;
}

class _ContactSectionData {
  const _ContactSectionData({required this.letter, required this.contacts});

  final String letter;
  final List<FriendSummary> contacts;
}
