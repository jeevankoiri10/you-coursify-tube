import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_state.dart';

/// Persists the single source of truth ([AppState]) to disk so the app can
/// reopen exactly where it was — same video/playlist, same position.
class Storage {
  static const _key = 'floater_app_state_v1';

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return AppState();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppState.fromJson(map);
    } catch (_) {
      // Corrupt/old data: start fresh rather than crash on launch.
      return AppState();
    }
  }

  static Future<void> save(AppState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
