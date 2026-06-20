import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/library.dart';

/// Persists the whole [Library] (folders, saved links, positions, history) so
/// the app reopens exactly where it was.
class Storage {
  static const _key = 'coursify_library_v1';

  static Future<Library> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return Library.empty();
    try {
      return Library.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return Library.empty();
    }
  }

  static Future<void> save(Library library) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(library.toJson()));
  }
}
