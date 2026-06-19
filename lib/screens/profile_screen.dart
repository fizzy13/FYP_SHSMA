import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_service.dart';
import '../theme_helpers.dart';
import '../theme_manager.dart';
import '../models/user_model.dart';
import '../services/user_info_service.dart';
import 'welcome_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _biometricEnabled = true;
  bool _pushAlertsEnabled = true;
  bool _motionAlertsEnabled = false;
  bool _systemUpdatesEnabled = true;
  bool _darkModeEnabled = true;

  late UserInfoService _userInfoService;
  late AuthService _authService;
  UserInfo? _userInfo;

  @override
  void initState() {
    super.initState();
    _userInfoService = UserInfoService();
    _authService = AuthService();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        UserInfo? userInfo;
        // Try loading by UID first (this matches Firestore documents keyed by UID)
        userInfo = await _userInfoService.getUserInfoByUid(currentUser.uid);
        // Fallback: try by email if UID lookup didn't return anything
        if (userInfo == null && currentUser.email != null) {
          userInfo = await _userInfoService.getUserInfoByEmail(currentUser.email!);
        }

        if (mounted) {
          setState(() {
            _userInfo = userInfo;
          });
        }
      }
    } catch (e) {
      print("Error loading user info: $e");
    }
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push<UserInfo>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(userInfo: _userInfo),
      ),
    );

    // Reload user info if changes were made
    if (result != null) {
      setState(() {
        _userInfo = result;
      });
    }
  }

  Future<void> _handleSignOut() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final parentContext = context;
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String? errorText;
    bool isSubmitting = false;

    await showDialog<void>(
      context: parentContext,
      barrierDismissible: false,
      builder: (context) {
        bool showPassword = false;
        bool showConfirmPassword = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Change Password', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newPasswordController,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            showPassword = !showPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: !showConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Re-type New Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            showConfirmPassword = !showConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(errorText ?? '', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel', style: GoogleFonts.inter()),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final newPassword = newPasswordController.text.trim();
                          final confirmPassword = confirmPasswordController.text.trim();

                          if (newPassword.isEmpty || confirmPassword.isEmpty) {
                            setState(() {
                              errorText = 'Please enter both password fields.';
                            });
                            return;
                          }

                          if (newPassword != confirmPassword) {
                            setState(() {
                              errorText = 'Passwords do not match. Please try again.';
                            });
                            return;
                          }

                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text('Confirm password change?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                content: Text('Are you sure you want to update your password?', style: GoogleFonts.inter()),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: Text('No', style: GoogleFonts.inter()),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: Text('Yes', style: GoogleFonts.inter()),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed != true) {
                            return;
                          }

                          setState(() {
                            isSubmitting = true;
                            errorText = null;
                          });

                          try {
                            await _authService.changePassword(newPassword);
                            if (!mounted) return;
                            Navigator.of(parentContext).pop();
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text('Password updated successfully.', style: GoogleFonts.inter()),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } on FirebaseAuthException catch (e) {
                            setState(() {
                              if (e.code == 'requires-recent-login') {
                                errorText = 'Please sign in again before changing your password.';
                              } else {
                                errorText = e.message ?? 'Password update failed. Please try again.';
                              }
                            });
                          } catch (e) {
                            setState(() {
                              errorText = 'Unable to update password right now.';
                            });
                          } finally {
                            setState(() {
                              isSubmitting = false;
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Change Password', style: GoogleFonts.inter()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = theme.colorScheme.primary;
    final pageBackground = theme.scaffoldBackgroundColor;
    final sectionBackground = context.tertiarySurface;
    final titleTextColor = context.headingText;
    final subtitleTextColor = context.mutedText;
    final iconColor = isDark ? Colors.white54 : const Color(0xFF7A8693);

    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundImage: AssetImage('assets/avatar.png'),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _userInfo?.fullName ?? 'User',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: titleTextColor,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _navigateToEditProfile,
                    child: Icon(Icons.settings, color: iconColor, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Big Profile Avatar
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: CircleAvatar(
                        radius: 56,
                        backgroundImage: AssetImage('assets/avatar.png'),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF0C100E) : Colors.black12, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0C100E) : Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ACTIVE',
                            style: GoogleFonts.inter(
                              color: isDark ? const Color(0xFF0C100E) : Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                _userInfo?.fullName ?? 'User',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: titleTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Premium Sentinel Member',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: subtitleTextColor,
                ),
              ),
              const SizedBox(height: 40),

              // ACCOUNT INFORMATION
              _buildSectionHeader(
                context,
                'ACCOUNT INFORMATION',
                actionText: 'EDIT',
                onActionTap: _navigateToEditProfile,
              ),
              _buildInfoCard(
                context,
                Icons.email_outlined,
                'EMAIL ADDRESS',
                _userInfo?.email ?? 'Not set',
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                context,
                Icons.phone_outlined,
                'PHONE',
                _userInfo?.phoneNumber ?? 'Not set',
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                context,
                Icons.location_on_outlined,
                'HOME ADDRESS',
                _userInfo?.address ?? 'Not set',
              ),
              const SizedBox(height: 40),

              // SECURITY SETTINGS
              _buildSectionHeader(context, 'SECURITY SETTINGS'),
              Container(
                decoration: BoxDecoration(
                  color: sectionBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                          _buildSettingsRow(
                      context,
                      Icons.restore,
                      'Change Password',
                      subtitle: null,
                      trailing: Icon(Icons.chevron_right, color: iconColor, size: 20),
                      onTap: _showChangePasswordDialog,
                    ),
                    _buildSettingsRow(context, Icons.fingerprint, 'Biometric Login', subtitle: 'FaceID / Fingerprint enabled', trailing: _buildToggle(context, _biometricEnabled, (val) => setState(() => _biometricEnabled = val))),
                    _buildSettingsRow(context, Icons.gpp_good_outlined, 'Two-Factor\nAuthentication', subtitle: null, trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F382E) : const Color(0xFFE6F5EA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('SECURED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor)),
                    )),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              // NOTIFICATION PREFERENCES
              _buildSectionHeader(context, 'NOTIFICATION PREFERENCES'),
              _buildNotificationToggle(context, 'Push Alerts (High Priority)', _pushAlertsEnabled, (val) => setState(() => _pushAlertsEnabled = val)),
              const SizedBox(height: 12),
              _buildNotificationToggle(context, 'Motion Alerts', _motionAlertsEnabled, (val) => setState(() => _motionAlertsEnabled = val)),
              const SizedBox(height: 12),
              _buildNotificationToggle(context, 'System Updates', _systemUpdatesEnabled, (val) => setState(() => _systemUpdatesEnabled = val)),

              const SizedBox(height: 40),
              // APP SETTINGS
              _buildSectionHeader(context, 'APP SETTINGS'),
              Container(
                decoration: BoxDecoration(
                  color: sectionBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    _buildSettingsRow(context, Icons.dark_mode_outlined, 'Dark Mode', trailing: _buildToggle(context, _darkModeEnabled, (val) {
                      setState(() => _darkModeEnabled = val);
                      AppTheme.setDarkMode(val);
                    })),
                    _buildSettingsRow(context, Icons.language, 'Language', trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Text('English (US)', style: GoogleFonts.inter(fontSize: 12, color: subtitleTextColor)),
                         const SizedBox(width: 8),
                         Icon(Icons.chevron_right, color: iconColor, size: 20),
                      ],
                    )),
                    _buildSettingsRow(context, Icons.privacy_tip_outlined, 'Privacy Policy', trailing: Icon(Icons.open_in_new, color: iconColor, size: 18)),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              // SIGN OUT BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _handleSignOut,
                  icon: const Icon(Icons.logout, color: Color(0xFFFF6B6B), size: 20),
                  label: Text(
                    'SIGN OUT',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF6B6B),
                      letterSpacing: 2.0,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isDark ? const Color(0xFF3B1515) : const Color(0xFFD6D9DE), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              Text(
                'VERSION 2.4.0 (SENTINEL CORE)',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isDark ? Colors.white30 : const Color(0xFF7A7A7A),
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    String? actionText,
    VoidCallback? onActionTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 4.0, right: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
              letterSpacing: 1.5,
            ),
          ),
          if (actionText != null)
            GestureDetector(
              onTap: onActionTap,
              child: Text(
                actionText,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF121212),
                  letterSpacing: 1.0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, IconData icon, String title, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2B24) : const Color(0xFFE9EEF3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 9, color: context.mutedText, letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.inter(fontSize: 13, color: context.headingText, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(BuildContext context, IconData icon, String title, {String? subtitle, required Widget trailing, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: context.mutedText, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 15, color: context.headingText)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: context.mutedText)),
                  ]
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(BuildContext context, String title, bool isEnabled, ValueChanged<bool> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isEnabled ? Theme.of(context).colorScheme.primary : (isDark ? Colors.white24 : Colors.black26),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: GoogleFonts.outfit(fontSize: 15, color: context.headingText))),
          _buildToggle(context, isEnabled, onChanged),
        ],
      ),
    );
  }

  Widget _buildToggle(BuildContext context, bool value, ValueChanged<bool> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? Theme.of(context).colorScheme.primary : (isDark ? const Color(0xFF26332C) : const Color(0xFFE1E5EA)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? (isDark ? const Color(0xFF0C100E) : Colors.white) : (isDark ? Colors.white24 : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
