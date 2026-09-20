import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences for simple key-value storage.
class LocalStorage {
  final SharedPreferences _prefs;

  LocalStorage(this._prefs);

  // ── String ──
  String? getString(String key) => _prefs.getString(key);
  Future<bool> setString(String key, String value) => _prefs.setString(key, value);

  // ── Bool ──
  bool getBool(String key, {bool defaultValue = false}) =>
      _prefs.getBool(key) ?? defaultValue;
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  // ── Int ──
  int getInt(String key, {int defaultValue = 0}) =>
      _prefs.getInt(key) ?? defaultValue;
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  // ── Double ──
  double getDouble(String key, {double defaultValue = 0.0}) =>
      _prefs.getDouble(key) ?? defaultValue;
  Future<bool> setDouble(String key, double value) => _prefs.setDouble(key, value);

  // ── List<String> ──
  List<String> getStringList(String key) => _prefs.getStringList(key) ?? [];
  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  // ── Remove ──
  Future<bool> remove(String key) => _prefs.remove(key);

  // ── Clear ──
  Future<bool> clear() => _prefs.clear();

  // ── Contains ──
  bool containsKey(String key) => _prefs.containsKey(key);
}
