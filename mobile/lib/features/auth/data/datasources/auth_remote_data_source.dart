import 'package:production_chat_app/features/auth/domain/entities/auth_code_purpose.dart';
import 'package:production_chat_app/features/auth/data/dto/auth_bundle_dto.dart';
import 'package:production_chat_app/features/auth/data/dto/auth_code_receipt_dto.dart';
import 'package:production_chat_app/features/auth/data/dto/device_session_dto.dart';
import 'package:production_chat_app/shared/network/api_client.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AuthCodeReceiptDto> requestCode({
    required String identifier,
    required AuthCodePurpose purpose,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/request-code',
      body: {'identifier': identifier, 'purpose': purpose.wireValue},
    );

    return AuthCodeReceiptDto.fromJson(response);
  }

  Future<AuthBundleDto> register({
    required String identifier,
    required String code,
    required String password,
    required String nickname,
    String? deviceName,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/register',
      body: {
        'identifier': identifier,
        'code': code,
        'password': password,
        'nickname': nickname,
        if (deviceName != null && deviceName.trim().isNotEmpty)
          'deviceName': deviceName,
      },
    );

    return AuthBundleDto.fromJson(response);
  }

  Future<AuthBundleDto> login({
    required String identifier,
    required String password,
    String? deviceName,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/login',
      body: {
        'identifier': identifier,
        'password': password,
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

  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String password,
  }) async {
    await _apiClient.postJson(
      '/auth/reset-password',
      body: {'identifier': identifier, 'code': code, 'password': password},
    );
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
