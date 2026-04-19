import 'package:flutter/foundation.dart';

import '../domain/entities/chat_message.dart';

class ChatController extends ChangeNotifier {
  final List<ChatMessage> messages = const [
    ChatMessage(
      id: 'msg-001',
      senderName: '系统',
      content: '这里先放聊天页骨架，后续接入实时消息与重发状态。',
    ),
    ChatMessage(id: 'msg-002', senderName: '产品', content: '消息、已读、输入中会在下一阶段补上。'),
  ];
}
