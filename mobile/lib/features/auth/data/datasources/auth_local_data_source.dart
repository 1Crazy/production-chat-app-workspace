import 'dart:convert';
import 'package:production_chat_app/features/auth/data/dto/auth_bundle_dto.dart';
import 'package:production_chat_app/shared/storage/key_value_store.dart';

class AuthLocalDataSource {
  const AuthLocalDataSource({required KeyValueStore keyValueStore})
    : _keyValueStore = keyValueStore;

  static const String _sessionStorageKey = 'auth_session_bundle';

  final KeyValueStore _keyValueStore;

  Future<void> saveSession(AuthBundleDto dto) async {
    await _keyValueStore.writeString(
      _sessionStorageKey,
      jsonEncode(dto.toJson()),
    );
  }

  AuthBundleDto? readSession() {
    final rawValue = _keyValueStore.readString(_sessionStorageKey);

    if (rawValue == null) {
      return null;
    }

    return AuthBundleDto.fromJson(jsonDecode(rawValue) as Map<String, dynamic>);
  }

  Future<void> clearSession() async {
    await _keyValueStore.remove(_sessionStorageKey);
  }
}
