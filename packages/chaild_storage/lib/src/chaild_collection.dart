import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'chaild_query.dart';

/// A named, ordered collection of JSON records stored locally.
///
/// Each record is automatically assigned a unique `_id`.
/// Obtain an instance via [ChaildStorage.collection].
class ChaildCollection {
  ChaildCollection(this._prefs, this._storeKey);

  final SharedPreferences _prefs;
  final String _storeKey;

  // ─── Internal helpers ─────────────────────────────────────────────────────

  List<Map<String, dynamic>> _read() {
    final raw = _prefs.getString(_storeKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> _write(List<Map<String, dynamic>> items) async {
    await _prefs.setString(_storeKey, jsonEncode(items));
  }

  String _newId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}';

  String _randomSuffix() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final buf = StringBuffer();
    for (var i = 0; i < 6; i++) {
      buf.write(chars[(DateTime.now().microsecondsSinceEpoch + i * 7) % chars.length]);
    }
    return buf.toString();
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Add [data] to the collection. Returns the generated id.
  Future<String> add(Map<String, dynamic> data) async {
    final items = _read();
    final id = _newId();
    items.add({...data, '_id': id});
    await _write(items);
    return id;
  }

  /// Return all items in insertion order.
  Future<List<Map<String, dynamic>>> getAll() async => _read();

  /// Return the item with [id], or null if not found.
  Future<Map<String, dynamic>?> getById(String id) async {
    final items = _read();
    try {
      return items.firstWhere((item) => item['_id'] == id);
    } catch (_) {
      return null;
    }
  }

  /// Merge [data] into the item with [id]. Existing keys not in [data] are kept.
  Future<void> update(String id, Map<String, dynamic> data) async {
    final items = _read();
    final idx = items.indexWhere((item) => item['_id'] == id);
    if (idx == -1) return;
    items[idx] = {...items[idx], ...data, '_id': id};
    await _write(items);
  }

  /// Remove the item with [id].
  Future<void> delete(String id) async {
    final items = _read();
    items.removeWhere((item) => item['_id'] == id);
    await _write(items);
  }

  /// Remove all items from the collection.
  Future<void> clear() async => _write([]);

  // ─── Query entry point ────────────────────────────────────────────────────

  /// Start a query on this collection.
  ///
  /// Example:
  ///   final pinned = await notes.where('pinned', isEqualTo: true);
  ChaildQuery where(
    String field, {
    dynamic isEqualTo,
    dynamic isGreaterThan,
    dynamic isLessThan,
    String? contains,
  }) {
    return ChaildQuery(_read).where(
      field,
      isEqualTo: isEqualTo,
      isGreaterThan: isGreaterThan,
      isLessThan: isLessThan,
      contains: contains,
    );
  }
}
