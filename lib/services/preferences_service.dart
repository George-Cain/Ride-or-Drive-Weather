import 'package:shared_preferences/shared_preferences.dart';
import '../shared/utils/logging_utils.dart';

/// Service for centralized SharedPreferences management
class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  SharedPreferences? _prefs;

  /// Initialize SharedPreferences
  Future<void> initialize() async {
    try {
      LoggingUtils.logInitialization('Preferences Service');
      _prefs ??= await SharedPreferences.getInstance();
      LoggingUtils.logCompletion('Preferences service initialization');
    } catch (e, stackTrace) {
      LoggingUtils.logCriticalError(
          'PREFERENCES SERVICE INITIALIZATION', e, stackTrace);
      rethrow;
    }
  }

  /// Get SharedPreferences instance
  Future<SharedPreferences> get prefs async {
    if (_prefs == null) {
      await initialize();
    }
    return _prefs!;
  }

  /// Get string value
  Future<String?> getString(String key) async {
    final preferences = await prefs;
    return preferences.getString(key);
  }

  /// Set string value
  Future<bool> setString(String key, String value) async {
    final preferences = await prefs;
    return preferences.setString(key, value);
  }

  /// Get string list value
  Future<List<String>?> getStringList(String key) async {
    final preferences = await prefs;
    return preferences.getStringList(key);
  }

  /// Set string list value
  Future<bool> setStringList(String key, List<String> value) async {
    final preferences = await prefs;
    return preferences.setStringList(key, value);
  }

  /// Get bool value
  Future<bool?> getBool(String key) async {
    final preferences = await prefs;
    return preferences.getBool(key);
  }

  /// Set bool value
  Future<bool> setBool(String key, bool value) async {
    final preferences = await prefs;
    return preferences.setBool(key, value);
  }

  /// Get int value
  Future<int?> getInt(String key) async {
    final preferences = await prefs;
    return preferences.getInt(key);
  }

  /// Set int value
  Future<bool> setInt(String key, int value) async {
    final preferences = await prefs;
    return preferences.setInt(key, value);
  }

  /// Get double value
  Future<double?> getDouble(String key) async {
    final preferences = await prefs;
    return preferences.getDouble(key);
  }

  /// Set double value
  Future<bool> setDouble(String key, double value) async {
    final preferences = await prefs;
    return preferences.setDouble(key, value);
  }

  /// Remove key
  Future<bool> remove(String key) async {
    final preferences = await prefs;
    return preferences.remove(key);
  }

  /// Get all keys
  Future<Set<String>> getKeys() async {
    final preferences = await prefs;
    return preferences.getKeys();
  }

  /// Clear all preferences
  Future<bool> clear() async {
    final preferences = await prefs;
    return preferences.clear();
  }
}
