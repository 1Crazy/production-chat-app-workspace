import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyValueStore {
  SecureKeyValueStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  Future<void> writeString(String key, String value) {
    return _secureStorage.write(key: key, value: value);
  }

  Future<String?> readString(String key) {
    return _secureStorage.read(key: key);
  }

  Future<void> remove(String key) {
    return _secureStorage.delete(key: key);
  }
}
