import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const String _themeKey = 'appearance_theme_mode';
  static const String _accentKey = 'appearance_accent_color';

  ThemeMode _themeMode = ThemeMode.system;
  int _accentColorValue = 0xFF2563EB;

  ThemeMode get themeMode => _themeMode;

  Color get accentColor => Color(_accentColorValue);

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();

    final savedTheme = preferences.getString(_themeKey);
    final savedAccent = preferences.getInt(_accentKey);

    switch (savedTheme) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }

    _accentColorValue = savedAccent ?? 0xFF2563EB;

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();

    final value = switch (mode) {
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
    };

    await preferences.setString(_themeKey, value);
  }

  Future<void> setAccentColor(Color color) async {
    _accentColorValue = color.toARGB32();
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();

    await preferences.setInt(_accentKey, _accentColorValue);
  }
}
