import 'dart:convert';
import 'package:production_chat_app/features/auth/data/dto/auth_bundle_dto.dart';
import 'package:production_chat_app/shared/storage/key_value_store.dart';
import 'package:production_chat_app/shared/storage/secure_key_value_store.dart';

class AuthLocalDataSource {
  const AuthLocalDataSource({
    required KeyValueStore legacyKeyValueStore,
    required SecureKeyValueStore secureKeyValueStore,
  }) : _legacyKeyValueStore = legacyKeyValueStore,
       _secureKeyValueStore = secureKeyValueStore;

  static const String _sessionStorageKey = 'auth_session_bundle';

  final KeyValueStore _legacyKeyValueStore;
  final SecureKeyValueStore _secureKeyValueStore;

  Future<void> saveSession(AuthBundleDto dto) async {
    await _secureKeyValueStore.writeString(
      _sessionStorageKey,
      jsonEncode(dto.toJson()),
    );
    await _legacyKeyValueStore.remove(_sessionStorageKey);
  }

  Future<AuthBundleDto?> readSession() async {
    final secureRawValue = await _secureKeyValueStore.readString(
      _sessionStorageKey,
    );

    if (secureRawValue != null) {
      return AuthBundleDto.fromJson(
        jsonDecode(secureRawValue) as Map<String, dynamic>,
      );
    }

    final legacyRawValue = _legacyKeyValueStore.readString(_sessionStorageKey);

    if (legacyRawValue == null) {
      return null;
    }

    final dto = AuthBundleDto.fromJson(
      jsonDecode(legacyRawValue) as Map<String, dynamic>,
    );

    // Preserve existing login state while removing the legacy plaintext copy.
    await saveSession(dto);
    return dto;
  }

  Future<void> clearSession() async {
    await _secureKeyValueStore.remove(_sessionStorageKey);
    await _legacyKeyValueStore.remove(_sessionStorageKey);
  }
}
