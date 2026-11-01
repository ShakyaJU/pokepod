import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` (and in tests) with an already-loaded instance, so
/// notifiers can read persisted state synchronously during `build`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

/// Small JSON cache for PokéAPI responses, stored as compact app-defined JSON.
class JsonCache {
  JsonCache(this._prefs);

  final SharedPreferences _prefs;
  static const _prefix = 'cache.v1.';

  Object? read(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) {
      return null;
    }
    try {
      return jsonDecode(raw);
    } catch (_) {
      // Corrupt cache entries are treated as missing.
      return null;
    }
  }

  Future<void> write(String key, Object value) async {
    await _prefs.setString('$_prefix$key', jsonEncode(value));
  }
}

final jsonCacheProvider = Provider<JsonCache>(
  (ref) => JsonCache(ref.watch(sharedPreferencesProvider)),
);

/// Reads a JSON object from preferences, returning null if absent or corrupt.
Map<String, dynamic>? readJsonMap(SharedPreferences prefs, String key) {
  final raw = prefs.getString(key);
  if (raw == null) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    // Corrupt stored data is treated as absent.
  }
  return null;
}

List<dynamic>? readJsonList(SharedPreferences prefs, String key) {
  final raw = prefs.getString(key);
  if (raw == null) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List<dynamic>) {
      return decoded;
    }
  } catch (_) {
    // Corrupt stored data is treated as absent.
  }
  return null;
}
