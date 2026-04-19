import 'package:flutter/widgets.dart';
import 'package:production_chat_app/features/auth/application/auth_controller.dart';

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();

    assert(scope != null, 'AuthScope 未注入到当前组件树中');
    return scope!.notifier!;
  }
}
