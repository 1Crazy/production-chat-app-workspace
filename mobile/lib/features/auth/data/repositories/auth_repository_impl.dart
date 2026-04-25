import 'package:production_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:production_chat_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_code_receipt.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_session.dart';
import 'package:production_chat_app/features/auth/domain/entities/device_session.dart';
import 'package:production_chat_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  @override
  Future<AuthCodeReceipt> requestCode({required String identifier}) async {
    final dto = await _remoteDataSource.requestCode(identifier: identifier);
    return dto.toEntity();
  }

  @override
  Future<AuthSession> register({
    required String identifier,
    required String code,
    required String nickname,
    String? deviceName,
  }) async {
    final dto = await _remoteDataSource.register(
      identifier: identifier,
      code: code,
      nickname: nickname,
      deviceName: deviceName,
    );
    await _localDataSource.saveSession(dto);
    return dto.toEntity();
  }

  @override
  Future<AuthSession> login({
    required String identifier,
    required String code,
    String? deviceName,
  }) async {
    final dto = await _remoteDataSource.login(
      identifier: identifier,
      code: code,
      deviceName: deviceName,
    );
    await _localDataSource.saveSession(dto);
    return dto.toEntity();
  }

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    final dto = await _remoteDataSource.refresh(refreshToken: refreshToken);
    await _localDataSource.saveSession(dto);
    return dto.toEntity();
  }

  @override
  Future<AuthSession?> restore() async {
    final dto = _localDataSource.readSession();
    return dto?.toEntity();
  }

  @override
  Future<List<DeviceSession>> listSessions({
    required String accessToken,
  }) async {
    final dtos = await _remoteDataSource.listSessions(accessToken: accessToken);
    return dtos.map((item) => item.toEntity()).toList(growable: false);
  }

  @override
  Future<void> revokeSession({
    required String accessToken,
    required String sessionId,
  }) async {
    await _remoteDataSource.revokeSession(
      accessToken: accessToken,
      sessionId: sessionId,
    );
  }

  @override
  Future<void> logout({required String accessToken}) async {
    await _remoteDataSource.logout(accessToken: accessToken);
    await _localDataSource.clearSession();
  }

  @override
  Future<void> clear() async {
    await _localDataSource.clearSession();
  }
}
