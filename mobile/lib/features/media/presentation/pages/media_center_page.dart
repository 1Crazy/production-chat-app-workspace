import 'package:flutter/material.dart';
import 'package:production_chat_app/features/media/application/media_controller.dart';
import 'package:production_chat_app/shared/widgets/placeholder_panel.dart';

class MediaCenterPage extends StatelessWidget {
  const MediaCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MediaController();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const PlaceholderPanel(
            title: '媒体中心骨架',
            description: '这里预留附件上传、处理中状态和安全校验结果的展示位置。',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: controller.pendingAssets.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text(controller.pendingAssets[index]));
              },
            ),
          ),
        ],
      ),
    );
  }
}
