import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/models.dart';

/// Save a tiny single-player state. No internet connection is needed.
class SaveService {
  SaveService({SharedPreferencesAsync? preferences})
      : _overridePreferences = preferences;

  // Lazily create the device plugin only when a real read/write is needed.
  // This keeps pure controller/widget tests free from plugin initialization.
  final SharedPreferencesAsync? _overridePreferences;
  late final SharedPreferencesAsync _preferences =
      _overridePreferences ?? SharedPreferencesAsync();
  static const _key = 'dead_day_save_v1';

  Future<GameState?> load() async {
    final raw = await _preferences.getString(_key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      return GameState.fromJson(data);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(GameState state) =>
      _preferences.setString(_key, jsonEncode(state.toJson()));
}
