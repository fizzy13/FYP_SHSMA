import 'package:flutter/material.dart';

extension ThemeHelpers on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get appBackground => Theme.of(this).scaffoldBackgroundColor;

  Color get surfaceBackground => Theme.of(this).colorScheme.surface;

  Color get secondarySurface => isDarkMode ? const Color(0xFF161C19) : const Color(0xFFF4F5F7);

  Color get tertiarySurface => isDarkMode ? const Color(0xFF131A17) : Colors.white;

  Color get canvasBorder => isDarkMode ? Colors.white10 : const Color(0xFFE1E5EA);

  Color get mutedText => isDarkMode ? Colors.white54 : const Color(0xFF6E7580);

  Color get headingText => isDarkMode ? Colors.white : const Color(0xFF121212);

  Color get navigationBarBackground => isDarkMode ? const Color(0xFF0C100E) : const Color(0xFFF2F4F6);

  Color get navigationBarInactive => isDarkMode ? Colors.white54 : const Color(0xFF7A8693);
}
