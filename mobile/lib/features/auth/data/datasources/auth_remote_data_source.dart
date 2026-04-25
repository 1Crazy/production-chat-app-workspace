import 'package:production_chat_app/features/auth/data/dto/auth_bundle_dto.dart';
import 'package:production_chat_app/features/auth/data/dto/auth_code_receipt_dto.dart';
import 'package:production_chat_app/features/auth/data/dto/device_session_dto.dart';
import 'package:production_chat_app/shared/network/api_client.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AuthCodeReceiptDto> requestCode({required String identifier}) async {
    final response = await _apiClient.postJson(
      '/auth/request-code',
      body: {'identifier': identifier},
    );

    return AuthCodeReceiptDto.fromJson(response);
  }

  Future<AuthBundleDto> register({
    required String identifier,
    required String code,
    required String nickname,
    String? deviceName,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/register',
      body: {
        'identifier': identifier,
        'code': code,
        'nickname': nickname,
        if (deviceName != null && deviceName.trim().isNotEmpty)
          'deviceName': deviceName,
      },
    );

    return AuthBundleDto.fromJson(response);
  }

  Future<AuthBundleDto> login({
    required String identifier,
    required String code,
    String? deviceName,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/login',
      body: {
        'identifier': identifier,
        'code': code,
        if (deviceName != null && deviceName.trim().isNotEmpty)
          'deviceName': deviceName,
      },
    );

    return AuthBundleDto.fromJson(response);
  }

  Future<AuthBundleDto> refresh({required String refreshToken}) async {
    final response = await _apiClient.postJson(
      '/auth/refresh',
      body: {'refreshToken': refreshToken},
    );

    return AuthBundleDto.fromJson(response);
  }

  Future<List<DeviceSessionDto>> listSessions({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJsonList(
      '/auth/sessions',
      accessToken: accessToken,
    );

    return response
        .map((item) {
          return DeviceSessionDto.fromJson(item as Map<String, dynamic>);
        })
        .toList(growable: false);
  }

  Future<void> revokeSession({
    required String accessToken,
    required String sessionId,
  }) async {
    await _apiClient.deleteJson(
      '/auth/sessions/$sessionId',
      accessToken: accessToken,
    );
  }

  Future<void> logout({required String accessToken}) async {
    await _apiClient.postJson('/auth/logout', accessToken: accessToken);
  }
}
