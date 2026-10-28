import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/models.dart';

/// Save a tiny single-player state. No internet connection is needed.
class SaveService {
  SaveService({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;
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
