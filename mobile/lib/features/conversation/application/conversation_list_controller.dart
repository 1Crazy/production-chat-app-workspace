import 'package:flutter/foundation.dart';

import '../domain/entities/conversation_summary.dart';

class ConversationListController extends ChangeNotifier {
  final List<ConversationSummary> items = const [
    ConversationSummary(
      id: 'conv-001',
      title: '产品讨论组',
      lastMessagePreview: '下一步接入消息主链路',
    ),
    ConversationSummary(
      id: 'conv-002',
      title: '设计同步',
      lastMessagePreview: '目录骨架已经搭好了',
    ),
  ];
}
