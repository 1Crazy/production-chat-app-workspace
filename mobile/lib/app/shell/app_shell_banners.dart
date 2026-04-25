part of 'app_shell.dart';

class _RealtimeStatusBanner extends StatelessWidget {
  const _RealtimeStatusBanner({required this.state, required this.message});

  final ChatRealtimeConnectionState state;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (state) {
      ChatRealtimeConnectionState.connected => '实时连接正常',
      ChatRealtimeConnectionState.connecting => '实时连接中...',
      ChatRealtimeConnectionState.disconnected => '实时连接已断开',
    };

    return AppInlineNotice(
      message: message == null ? statusText : '$statusText：$message',
      tone: switch (state) {
        ChatRealtimeConnectionState.connected => AppStatusTone.success,
        ChatRealtimeConnectionState.connecting => AppStatusTone.info,
        ChatRealtimeConnectionState.disconnected => AppStatusTone.error,
      },
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    );
  }
}

class _FirebaseConfigurationBanner extends StatelessWidget {
  const _FirebaseConfigurationBanner();

  @override
  Widget build(BuildContext context) {
    return const AppInlineNotice(
      message: '推送配置未完成：请执行 flutterfire configure，并补齐移动端推送配置文件。',
      tone: AppStatusTone.warning,
      margin: EdgeInsets.fromLTRB(16, 8, 16, 0),
    );
  }
}
