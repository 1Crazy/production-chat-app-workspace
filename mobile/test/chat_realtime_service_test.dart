import 'package:flutter_test/flutter_test.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime_service.dart';

void main() {
  test('chat realtime service sends access token via auth and header', () {
    final service = ChatRealtimeService(baseUrl: 'http://localhost:3000');

    final options = service.buildSocketOptionsForTest(
      accessToken: 'access-token-123',
    );

    expect(options['auth'], {'token': 'access-token-123'});
    expect(options['extraHeaders'], {
      'Authorization': 'Bearer access-token-123',
    });
    expect(options['transports'], ['websocket']);
    expect(options['autoConnect'], isFalse);
  });
}
