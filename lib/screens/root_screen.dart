import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme_helpers.dart';
import 'dashboard_screen.dart';
import 'camera_screen.dart';
import 'alerts_screen.dart';
import 'profile_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const CameraScreen(),
    const AlertsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navBackground = theme.bottomNavigationBarTheme.backgroundColor ?? context.navigationBarBackground;
    final navInactiveColor = theme.bottomNavigationBarTheme.unselectedItemColor ?? context.navigationBarInactive;
    final selectedIconColor = theme.bottomNavigationBarTheme.selectedItemColor ?? const Color(0xFF4EEF9B);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Theme(
        data: theme.copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          backgroundColor: navBackground,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: selectedIconColor,
          unselectedItemColor: navInactiveColor,
          selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
          showUnselectedLabels: true,
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          items: [
             BottomNavigationBarItem(
              icon: _buildIcon(Icons.home, 0, isDark: isDark),
              label: _selectedIndex == 0 ? '' : 'HOME',
            ),
            BottomNavigationBarItem(
              icon: _buildIcon(Icons.videocam, 1, isDark: isDark),
              label: _selectedIndex == 1 ? '' : 'CAMERAS',
            ),
            BottomNavigationBarItem(
              icon: _buildIcon(Icons.location_on, 2, isDark: isDark),
              label: _selectedIndex == 2 ? '' : 'SAFETY',
            ),
            BottomNavigationBarItem(
              icon: _buildIcon(Icons.person, 3, isDark: isDark),
              label: _selectedIndex == 3 ? '' : 'PROFILE',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(IconData iconData, int index, {required bool isDark}) {
    if (_selectedIndex == index) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF4EEF9B),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4EEF9B).withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(iconData, color: isDark ? const Color(0xFF0C100E) : Colors.white),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Icon(iconData, color: isDark ? Colors.white70 : const Color(0xFF4C5865)),
    );
  }
}
