import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  
  ThemeProvider() {
    _loadThemePreference();
  }
  
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('theme_mode') ?? 'system';
      
      if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (e) {
      _themeMode = ThemeMode.system;
    }
  }
  
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mode == ThemeMode.dark) {
        await prefs.setString('theme_mode', 'dark');
      } else if (mode == ThemeMode.light) {
        await prefs.setString('theme_mode', 'light');
      } else {
        await prefs.setString('theme_mode', 'system');
      }
    } catch (e) {
      // Kaydetme hatası
    }
  }
  
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light || _themeMode == ThemeMode.system) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }
  
  String get themeName {
    switch (_themeMode) {
      case ThemeMode.dark:
        return 'Karanlık';
      case ThemeMode.light:
        return 'Aydınlık';
      case ThemeMode.system:
        return 'Sistem';
    }
  }
}
