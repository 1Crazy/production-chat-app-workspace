import 'package:flutter/material.dart';
import 'package:production_chat_app/features/auth/presentation/pages/login_page.dart';
import 'package:production_chat_app/shared/config/app_environment.dart';
import 'package:production_chat_app/app/shell/app_shell.dart';

class AppRouter {
  const AppRouter({required this.environment});

  static const String rootPath = '/';
  static const String loginPath = '/login';

  final AppEnvironment environment;

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case loginPath:
        return MaterialPageRoute<void>(
          builder: (_) => const LoginPage(),
          settings: settings,
        );
      case rootPath:
      default:
        return MaterialPageRoute<void>(
          builder: (_) => AppShell(environment: environment),
          settings: settings,
        );
    }
  }
}
