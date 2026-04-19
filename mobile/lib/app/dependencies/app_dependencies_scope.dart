import 'package:flutter/widgets.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies.dart';

class AppDependenciesScope extends InheritedWidget {
  const AppDependenciesScope({
    super.key,
    required this.dependencies,
    required super.child,
  });

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppDependenciesScope>();

    assert(scope != null, 'AppDependenciesScope 未注入到当前组件树中');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppDependenciesScope oldWidget) {
    return oldWidget.dependencies != dependencies;
  }
}
