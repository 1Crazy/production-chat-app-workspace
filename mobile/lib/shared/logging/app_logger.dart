import 'dart:developer' as developer;

class AppLogger {
  const AppLogger._();

  static void info(String message) {
    developer.log(message, name: 'production_chat_app');
  }
}
