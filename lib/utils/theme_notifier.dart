import 'package:flutter/material.dart';

/// A singleton ChangeNotifier that holds the current ThemeMode.
/// Use [ThemeNotifier.instance] to access it from anywhere.
class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier._();
  static final ThemeNotifier instance = ThemeNotifier._();

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  void setDark() {
    if (_themeMode != ThemeMode.dark) {
      _themeMode = ThemeMode.dark;
      notifyListeners();
    }
  }

  void setLight() {
    if (_themeMode != ThemeMode.light) {
      _themeMode = ThemeMode.light;
      notifyListeners();
    }
  }

  void toggle() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}
