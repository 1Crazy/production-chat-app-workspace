import 'package:flutter/material.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies_scope.dart';
import 'package:production_chat_app/app/shell/app_shell.dart';
import 'package:production_chat_app/app/theme/app_theme.dart';
import 'package:production_chat_app/features/auth/application/auth_controller.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/auth/application/auth_status.dart';
import 'package:production_chat_app/features/auth/presentation/pages/login_page.dart';
import 'package:production_chat_app/shared/config/app_environment.dart';

class ProductionChatApp extends StatelessWidget {
  const ProductionChatApp({
    super.key,
    required this.environment,
    required this.dependencies,
    required this.authController,
  });

  final AppEnvironment environment;
  final AppDependencies dependencies;
  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: authController,
      child: AppDependenciesScope(
        dependencies: dependencies,
        child: AnimatedBuilder(
          animation: authController,
          builder: (context, child) {
            return MaterialApp(
              title: environment.appName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              home: _buildHome(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHome() {
    switch (authController.status) {
      case AuthStatus.bootstrapping:
        return const _AppBootstrappingPage();
      case AuthStatus.authenticated:
        return AppShell(environment: environment);
      case AuthStatus.unauthenticated:
        return const LoginPage();
    }
  }
}

class _AppBootstrappingPage extends StatelessWidget {
  const _AppBootstrappingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
