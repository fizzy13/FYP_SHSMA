import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.dark);

  static void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
  }

  static void setDarkMode(bool enabled) {
    themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
  }
}
