import 'package:flutter/material.dart';
import 'package:production_chat_app/features/chat/application/chat_controller.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ChatController();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: controller.messages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = controller.messages[index];

        return Align(
          alignment: index.isEven
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: index.isEven
                  ? Colors.white
                  : Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.senderName,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(item.content),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
