import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:production_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:production_chat_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:production_chat_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:production_chat_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:production_chat_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:production_chat_app/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:production_chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:production_chat_app/features/conversation/data/datasources/conversation_remote_data_source.dart';
import 'package:production_chat_app/features/conversation/data/repositories/conversation_repository_impl.dart';
import 'package:production_chat_app/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:production_chat_app/features/friendship/data/datasources/friendship_remote_data_source.dart';
import 'package:production_chat_app/features/friendship/data/repositories/friendship_repository_impl.dart';
import 'package:production_chat_app/features/friendship/domain/repositories/friendship_repository.dart';
import 'package:production_chat_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:production_chat_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:production_chat_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:production_chat_app/shared/config/app_environment.dart';
import 'package:production_chat_app/shared/network/api_client.dart';
import 'package:production_chat_app/shared/notifications/app_badge_service.dart';
import 'package:production_chat_app/shared/notifications/notification_remote_data_source.dart';
import 'package:production_chat_app/shared/notifications/push_notification_service.dart';
import 'package:production_chat_app/shared/notifications/push_registration_service.dart';
import 'package:production_chat_app/shared/notifications/push_registration_service_impl.dart';
import 'package:production_chat_app/shared/notifications/push_token_provider.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime_service.dart';
import 'package:production_chat_app/shared/storage/key_value_store.dart';
import 'package:production_chat_app/shared/storage/secure_key_value_store.dart';

class AppDependencies {
  const AppDependencies({
    required this.authRepository,
    required this.appBadgeService,
    required this.chatRepository,
    required this.chatRealtime,
    required this.conversationRepository,
    required this.firebaseReady,
    required this.friendshipRepository,
    required this.notificationRemoteDataSource,
    required this.profileRepository,
    required this.pushNotificationService,
    required this.pushRegistrationService,
  });

  final AuthRepository authRepository;
  final AppBadgeService appBadgeService;
  final ChatRepository chatRepository;
  final ChatRealtime chatRealtime;
  final ConversationRepository conversationRepository;
  final bool firebaseReady;
  final FriendshipRepository friendshipRepository;
  final NotificationRemoteDataSource notificationRemoteDataSource;
  final ProfileRepository profileRepository;
  final PushNotificationService pushNotificationService;
  final PushRegistrationService pushRegistrationService;

  static Future<AppDependencies> create(
    AppEnvironment environment, {
    required bool firebaseReady,
  }) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final keyValueStore = KeyValueStore(sharedPreferences: sharedPreferences);
    final secureKeyValueStore = SecureKeyValueStore(
      secureStorage: const FlutterSecureStorage(),
    );
    final apiClient = ApiClient(baseUrl: environment.apiBaseUrl);
    final notificationRemoteDataSource = NotificationRemoteDataSource(
      apiClient: apiClient,
    );
    final pushNotificationService = firebaseReady
        ? FirebasePushNotificationService()
        : const NoopPushNotificationService();
    final pushTokenProvider = firebaseReady
        ? FirebaseMessagingPushTokenProvider()
        : const NoopPushTokenProvider();

    return AppDependencies(
      authRepository: AuthRepositoryImpl(
        remoteDataSource: AuthRemoteDataSource(apiClient: apiClient),
        localDataSource: AuthLocalDataSource(
          legacyKeyValueStore: keyValueStore,
          secureKeyValueStore: secureKeyValueStore,
        ),
      ),
      appBadgeService: const AppBadgeService(),
      chatRepository: ChatRepositoryImpl(
        remoteDataSource: ChatRemoteDataSource(apiClient: apiClient),
      ),
      chatRealtime: ChatRealtimeService(baseUrl: environment.apiBaseUrl),
      conversationRepository: ConversationRepositoryImpl(
        remoteDataSource: ConversationRemoteDataSource(apiClient: apiClient),
      ),
      firebaseReady: firebaseReady,
      friendshipRepository: FriendshipRepositoryImpl(
        remoteDataSource: FriendshipRemoteDataSource(apiClient: apiClient),
      ),
      notificationRemoteDataSource: notificationRemoteDataSource,
      profileRepository: ProfileRepositoryImpl(
        remoteDataSource: ProfileRemoteDataSource(apiClient: apiClient),
      ),
      pushNotificationService: pushNotificationService,
      pushRegistrationService: PushRegistrationServiceImpl(
        remoteDataSource: notificationRemoteDataSource,
        pushTokenProvider: pushTokenProvider,
        keyValueStore: keyValueStore,
      ),
    );
  }
}
