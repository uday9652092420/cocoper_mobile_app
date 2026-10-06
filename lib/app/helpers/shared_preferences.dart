import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsHelper {
  static SharedPreferences? _prefs;

  // ============================================================
  // LOCALIZATION KEYS
  // ============================================================

  static const String languageCode = 'language_code';
  static const String countryCode = 'country_code';

  // ============================================================
  // API / AUTH KEYS
  // ============================================================

  static const String accessToken = 'accessToken';

  // ============================================================
  // USER / SESSION KEYS
  // ============================================================

  static const String userId = 'userId';
  static const String username = 'username';
  static const String emailId = 'emailId';
  static const String fullName = 'fullName';
  static const String userRole = 'userRole';
  static const String organizationId = 'organizationId';
  static const String rememberMe = 'rememberMe';

  // ============================================================
  // INITIALIZATION
  // ============================================================

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
  }

  // ============================================================
  // SAVE DATA
  // ============================================================

  static Future<bool> setString(
    String key,
    String value,
  ) async {
    await _ensureInitialized();
    return _prefs!.setString(key, value);
  }

  static Future<bool> setBool(
    String key,
    bool value,
  ) async {
    await _ensureInitialized();
    return _prefs!.setBool(key, value);
  }

  static Future<bool> setInt(
    String key,
    int value,
  ) async {
    await _ensureInitialized();
    return _prefs!.setInt(key, value);
  }

  static Future<bool> setDouble(
    String key,
    double value,
  ) async {
    await _ensureInitialized();
    return _prefs!.setDouble(key, value);
  }

  static Future<bool> setList(
    String key,
    List<String> value,
  ) async {
    await _ensureInitialized();
    return _prefs!.setStringList(key, value);
  }

  static Future<bool> setMap(
    String key,
    Map<String, dynamic> value,
  ) async {
    await _ensureInitialized();
    return _prefs!.setString(
      key,
      jsonEncode(value),
    );
  }

  static Future<bool> setDynamic(
    String key,
    dynamic value,
  ) async {
    await _ensureInitialized();
    return _prefs!.setString(
      key,
      jsonEncode(value),
    );
  }

  // ============================================================
  // READ DATA
  // ============================================================

  static Future<String> getString(
    String key, {
    String defaultValue = '',
  }) async {
    await _ensureInitialized();

    final value = _prefs!.getString(key);

    return value ?? defaultValue;
  }

  static Future<bool> getBool(
    String key, {
    bool defaultValue = false,
  }) async {
    await _ensureInitialized();

    return _prefs!.getBool(key) ?? defaultValue;
  }

  static Future<int> getInt(
    String key, {
    int defaultValue = 0,
  }) async {
    await _ensureInitialized();

    return _prefs!.getInt(key) ?? defaultValue;
  }

  static Future<double> getDouble(
    String key, {
    double defaultValue = 0.0,
  }) async {
    await _ensureInitialized();

    return _prefs!.getDouble(key) ?? defaultValue;
  }

  static Future<List<String>> getList(
    String key, {
    List<String> defaultValue = const [],
  }) async {
    await _ensureInitialized();

    return _prefs!.getStringList(key) ?? defaultValue;
  }

  // ============================================================
  // GET MAP
  // ============================================================

  static Future<Map<String, dynamic>> getMap(
    String key, {
    Map<String, dynamic> defaultValue = const {},
  }) async {
    await _ensureInitialized();

    final jsonString = _prefs!.getString(key);

    if (jsonString == null || jsonString.isEmpty) {
      return defaultValue;
    }

    try {
      final decoded = jsonDecode(jsonString);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return defaultValue;
    }

    return defaultValue;
  }

  // ============================================================
  // GET DYNAMIC
  // ============================================================

  static Future<dynamic> getDynamic(
    String key, {
    dynamic defaultValue,
  }) async {
    await _ensureInitialized();

    final jsonString = _prefs!.getString(key);

    if (jsonString == null || jsonString.isEmpty) {
      return defaultValue;
    }

    try {
      return jsonDecode(jsonString);
    } catch (_) {
      return defaultValue;
    }
  }

  // ============================================================
  // REMOVE DATA
  // ============================================================

  static Future<bool> remove(String key) async {
    await _ensureInitialized();

    return _prefs!.remove(key);
  }

  // ============================================================
  // CLEAR ALL DATA
  // ============================================================

  static Future<bool> clearAll() async {
    await _ensureInitialized();

    return _prefs!.clear();
  }
}
