import 'package:shared_preferences/shared_preferences.dart';
import 'package:production_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:production_chat_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:production_chat_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:production_chat_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:production_chat_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:production_chat_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:production_chat_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:production_chat_app/shared/config/app_environment.dart';
import 'package:production_chat_app/shared/network/api_client.dart';
import 'package:production_chat_app/shared/storage/key_value_store.dart';

class AppDependencies {
  const AppDependencies({
    required this.authRepository,
    required this.profileRepository,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;

  static Future<AppDependencies> create(AppEnvironment environment) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final keyValueStore = KeyValueStore(sharedPreferences: sharedPreferences);
    final apiClient = ApiClient(baseUrl: environment.apiBaseUrl);

    return AppDependencies(
      authRepository: AuthRepositoryImpl(
        remoteDataSource: AuthRemoteDataSource(apiClient: apiClient),
        localDataSource: AuthLocalDataSource(keyValueStore: keyValueStore),
      ),
      profileRepository: ProfileRepositoryImpl(
        remoteDataSource: ProfileRemoteDataSource(apiClient: apiClient),
      ),
    );
  }
}
