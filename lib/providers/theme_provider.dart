import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('themeMode') ?? 'system';
      if (s == 'light') _themeMode = ThemeMode.light;
      else if (s == 'dark') _themeMode = ThemeMode.dark;
      else _themeMode = ThemeMode.system;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system';
      await prefs.setString('themeMode', s);
    } catch (_) {}
  }

  void toggleDark() {
    if (_themeMode == ThemeMode.dark) setThemeMode(ThemeMode.light);
    else setThemeMode(ThemeMode.dark);
  }

  /// Toggle by boolean (true = dark)
  void toggleTheme(bool isDark) {
    setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}
