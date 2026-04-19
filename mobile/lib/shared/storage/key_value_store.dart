import 'package:shared_preferences/shared_preferences.dart';

class KeyValueStore {
  const KeyValueStore({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  Future<void> writeString(String key, String value) async {
    await _sharedPreferences.setString(key, value);
  }

  String? readString(String key) {
    return _sharedPreferences.getString(key);
  }

  Future<void> remove(String key) async {
    await _sharedPreferences.remove(key);
  }
}
