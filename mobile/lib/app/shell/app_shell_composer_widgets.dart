part of 'app_shell.dart';

enum _ConversationComposerAction { addFriend, group }

class _ConversationComposerTile extends StatelessWidget {
  const _ConversationComposerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF6FAF9),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFD6F2EB),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF0F766E)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateGroupConversationPayload {
  const _CreateGroupConversationPayload({
    required this.title,
    required this.memberHandles,
  });

  final String title;
  final List<String> memberHandles;
}

class _CreateDirectConversationDialog extends StatefulWidget {
  const _CreateDirectConversationDialog();

  @override
  State<_CreateDirectConversationDialog> createState() =>
      _CreateDirectConversationDialogState();
}

class _CreateDirectConversationDialogState
    extends State<_CreateDirectConversationDialog> {
  late final TextEditingController _handleController;

  @override
  void initState() {
    super.initState();
    _handleController = TextEditingController();
  }

  @override
  void dispose() {
    _handleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建单聊'),
      content: TextField(
        controller: _handleController,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '对方账号',
          hintText: '例如 测试用户1',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_handleController.text.trim());
          },
          child: const Text('进入聊天'),
        ),
      ],
    );
  }
}

class _CreateGroupConversationDialog extends StatefulWidget {
  const _CreateGroupConversationDialog();

  @override
  State<_CreateGroupConversationDialog> createState() =>
      _CreateGroupConversationDialogState();
}

class _CreateGroupConversationDialogState
    extends State<_CreateGroupConversationDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _handlesController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _handlesController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _handlesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建群聊'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '群聊名称',
                hintText: '例如 设计评审群',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _handlesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '成员账号',
                hintText: '用逗号、空格或换行分隔，例如 测试用户1,测试用户2',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final memberHandles = _handlesController.text
                .split(RegExp(r'[\s,，]+'))
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false);
            Navigator.of(context).pop(
              _CreateGroupConversationPayload(
                title: _titleController.text.trim(),
                memberHandles: memberHandles,
              ),
            );
          },
          child: const Text('确认创建'),
        ),
      ],
    );
  }
}
