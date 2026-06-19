import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/welcome_screen.dart';
import 'firebase_options.dart';
import 'theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: kIsWeb ? DefaultFirebaseOptions.currentPlatform : null,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4EEF9B),
        surface: Color(0xFFF4F5F7),
        onSurface: Color(0xFF121212),
      ),
      textTheme: ThemeData.light().textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF121212),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFF2F4F6),
        selectedItemColor: Color(0xFF4EEF9B),
        unselectedItemColor: Color(0xFF7A8693),
      ),
      useMaterial3: true,
    );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0C100E),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF4EEF9B),
        surface: Color(0xFF161C19),
        onSurface: Colors.white,
      ),
      textTheme: ThemeData.dark().textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0C100E),
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0C100E),
        selectedItemColor: Color(0xFF4EEF9B),
        unselectedItemColor: Colors.white54,
      ),
      useMaterial3: true,
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, mode, child) {
        return MaterialApp(
          title: 'Smart Home Security Monitoring',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: mode,
          home: const WelcomeScreen(),
        );
      },
    );
  }
}
