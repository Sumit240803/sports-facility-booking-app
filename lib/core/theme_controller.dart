import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / dark / follow-the-phone choice, remembered across launches.
class ThemeController extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode mode = ThemeMode.system;

  Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      mode = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    } catch (_) {
      mode = ThemeMode.system;
    }
  }

  Future<void> set(ThemeMode next) async {
    if (next == mode) return;
    mode = next;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_key, next.name);
    } catch (_) {
      // The choice still applies for this session.
    }
  }
}
