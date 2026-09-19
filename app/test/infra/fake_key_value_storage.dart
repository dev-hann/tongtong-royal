import 'package:app/infra/profile_store.dart';

/// In-memory [KeyValueStorage] for tests — no real SharedPreferences.
final class FakeKeyValueStorage implements KeyValueStorage {
  final Map<String, Object> _values = {};

  /// Written entries, exposed for namespace assertions.
  Map<String, Object> get values => _values;

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> setBool(String key, {required bool value}) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}
