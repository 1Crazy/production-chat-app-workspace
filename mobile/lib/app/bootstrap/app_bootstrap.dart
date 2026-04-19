import 'package:flutter/widgets.dart';
import 'package:production_chat_app/app/app.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies.dart';
import 'package:production_chat_app/features/auth/application/auth_controller.dart';
import 'package:production_chat_app/shared/config/app_environment.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<void> run() async {
    WidgetsFlutterBinding.ensureInitialized();
    final environment = AppEnvironment.fromDartDefine();
    final dependencies = await AppDependencies.create(environment);
    final authController = AuthController(
      authRepository: dependencies.authRepository,
    );

    await authController.bootstrap();
    runApp(
      ProductionChatApp(
        environment: environment,
        dependencies: dependencies,
        authController: authController,
      ),
    );
  }
}
