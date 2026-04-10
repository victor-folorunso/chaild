import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chaild_collection.dart';

/// Entry point for ChaildStorage.
///
/// Call [initialize] once in main() after ChaildAuth.initialize().
/// All keys are namespaced to prevent collisions between partner apps.
class ChaildStorage {
  ChaildStorage._();

  static String? _namespace;
  static SharedPreferences? _prefs;
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Must be called once before any other method.
  ///
  /// [namespace] — short unique identifier for your app.
  /// Use lowercase letters, numbers, and underscores only.
  static Future<void> initialize({required String namespace}) async {
    assert(
      RegExp(r'^[a-z0-9_]+$').hasMatch(namespace),
      'namespace must contain only lowercase letters, numbers, and underscores',
    );
    _namespace = namespace;
    _prefs = await SharedPreferences.getInstance();
  }

  static String _k(String key) {
    assert(_namespace != null, 'ChaildStorage.initialize() must be called first');
    return 'chaild.$_namespace.$key';
  }

  // ─── Key-Value ────────────────────────────────────────────────────────────

  /// Save [value] under [key]. Value must be JSON-compatible.
  static Future<void> set(String key, dynamic value) async {
    final encoded = jsonEncode(value);
    await _prefs!.setString(_k(key), encoded);
  }

  /// Read the value stored under [key], or null if it does not exist.
  static Future<dynamic> get(String key) async {
    final raw = _prefs!.getString(_k(key));
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  /// Returns true if [key] exists in storage.
  static Future<bool> has(String key) async {
    return _prefs!.containsKey(_k(key));
  }

  /// Delete the value stored under [key].
  static Future<void> delete(String key) async {
    await _prefs!.remove(_k(key));
  }

  /// Delete all key-value pairs for this namespace.
  /// Does not affect secure storage or collections.
  static Future<void> clear() async {
    final prefix = 'chaild.$_namespace.';
    final keys = _prefs!.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final k in keys) {
      await _prefs!.remove(k);
    }
  }

  // ─── Secure Storage ───────────────────────────────────────────────────────

  /// Save [value] in the device keychain / EncryptedSharedPreferences.
  static Future<void> setSecure(String key, String value) async {
    await _secure.write(key: _k(key), value: value);
  }

  /// Read a secure value, or null if it does not exist.
  static Future<String?> getSecure(String key) async {
    return _secure.read(key: _k(key));
  }

  /// Delete a secure value.
  static Future<void> deleteSecure(String key) async {
    await _secure.delete(key: _k(key));
  }

  // ─── Collections ──────────────────────────────────────────────────────────

  /// Returns a [ChaildCollection] scoped to [name] within this namespace.
  static ChaildCollection collection(String name) {
    assert(_namespace != null, 'ChaildStorage.initialize() must be called first');
    return ChaildCollection(_prefs!, 'chaild.$_namespace.collection.$name');
  }
}
