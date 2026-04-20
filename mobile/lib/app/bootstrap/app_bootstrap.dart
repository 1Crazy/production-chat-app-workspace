import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:production_chat_app/app/app.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies.dart';
import 'package:production_chat_app/features/auth/application/auth_controller.dart';
import 'package:production_chat_app/shared/config/app_environment.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<void> run() async {
    WidgetsFlutterBinding.ensureInitialized();
    final firebaseReady = await _initializeFirebase();
    final environment = AppEnvironment.fromDartDefine();
    final dependencies = await AppDependencies.create(
      environment,
      firebaseReady: firebaseReady,
    );
    await dependencies.pushNotificationService.initialize();
    final authController = AuthController(
      authRepository: dependencies.authRepository,
      pushRegistrationService: dependencies.pushRegistrationService,
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

  static Future<bool> _initializeFirebase() async {
    if (Firebase.apps.isNotEmpty) {
      return true;
    }

    try {
      await Firebase.initializeApp();
      return true;
    } catch (_) {
      // 本地开发可能尚未放置 google-services.json / GoogleService-Info.plist。
      // Firebase 初始化失败时保留应用可用，推送能力在后续配置完成后自动恢复。
      return false;
    }
  }
}
