import 'package:flutter/services.dart';

class AppBadgeService {
  static const _channel = MethodChannel('production_chat_app/badge');

  const AppBadgeService();

  Future<void> updateBadgeCount(int count) async {
    final normalizedCount = count < 0 ? 0 : count;

    try {
      await _channel.invokeMethod<void>('setBadgeCount', normalizedCount);
    } on MissingPluginException {
      // 非移动端或当前平台未接入原生 badge 能力时静默降级。
    }
  }
}
