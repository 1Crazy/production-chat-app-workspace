import 'package:flutter/material.dart';
import 'package:production_chat_app/features/conversation/application/conversation_list_controller.dart';

class ConversationListPage extends StatelessWidget {
  const ConversationListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ConversationListController();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: controller.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = controller.items[index];

        return ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(item.title),
          subtitle: Text(item.lastMessagePreview),
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }
}
