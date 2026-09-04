import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_service.dart';
import '../models/user_model.dart';
import '../services/user_info_service.dart';
import '../theme_helpers.dart';
import 'camera_screen.dart';
import 'welcome_screen.dart';

const String _kPrefTapoRelayIp = 'tapo_relay_ip';
const String _kPrefTapoRelayPort = 'tapo_relay_port';
const String _kPrefTapoStreamName = 'tapo_stream_name';
const String _kPrefTapoStreamName2 = 'tapo_stream_name2';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenCamera;

  const DashboardScreen({super.key, this.onOpenCamera});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final UserInfoService _userInfoService = UserInfoService();
  UserInfo? _userInfo;

  bool _frontCameraOnline = false;
  bool _backCameraOnline = false;
  Timer? _cameraStatusTimer;
  String _tapoRelayIp = kTapoDefaultRelayIp;
  String _tapoRelayPort = kTapoDefaultRelayPort;
  String _tapoStreamName = kTapoDefaultStreamName;
  String _tapoStreamName2 = kTapoDefaultStreamName2;

  String _displayNameFromUser() {
    final currentUser = _authService.currentUser;
    final fullName = currentUser?.displayName;
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }

    final email = currentUser?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.contains('@') ? email.split('@').first : email;
    }

    return 'User';
  }

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadCameraConfigAndPoll();
  }

  Future<void> _loadCameraConfigAndPoll() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedTapoIp = prefs.getString(_kPrefTapoRelayIp);
    setState(() {
      _tapoRelayIp = savedTapoIp == kTapoCameraIp || savedTapoIp == null || savedTapoIp.trim().isEmpty
          ? kTapoDefaultRelayIp
          : savedTapoIp;
      _tapoRelayPort = prefs.getString(_kPrefTapoRelayPort) ?? kTapoDefaultRelayPort;
      _tapoStreamName = prefs.getString(_kPrefTapoStreamName) ?? kTapoDefaultStreamName;
      _tapoStreamName2 = prefs.getString(_kPrefTapoStreamName2) ?? kTapoDefaultStreamName2;
    });

    _pollCameraStatus();
    _cameraStatusTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollCameraStatus());
  }

  Future<bool> _isCameraReachable(String streamName) async {
    try {
      final uri = Uri.parse('http://$_tapoRelayIp:$_tapoRelayPort/health?src=$streamName');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;
      return (jsonDecode(response.body) as Map<String, dynamic>)['online'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pollCameraStatus() async {
    final front = await _isCameraReachable(_tapoStreamName);
    final back = await _isCameraReachable(_tapoStreamName2);
    if (!mounted) return;
    setState(() {
      _frontCameraOnline = front;
      _backCameraOnline = back;
    });
  }

  @override
  void dispose() {
    _cameraStatusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    UserInfo? userInfo;
    try {
      if (currentUser.uid.isNotEmpty) {
        userInfo = await _userInfoService.getUserInfoByUid(currentUser.uid);
      }
      if (userInfo == null && currentUser.email != null) {
        userInfo = await _userInfoService.getUserInfoByEmail(currentUser.email!);
      }
    } catch (e) {
      // ignore errors for now; fallback values will still render
      print('Dashboard user load error: $e');
    }

    if (mounted) {
      setState(() {
        _userInfo = userInfo;
      });
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    await _authService.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final panel = context.tertiarySurface;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE3E8EF);
    final textPrimary = context.headingText;
    final textSecondary = context.mutedText;
    final accent = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundImage: AssetImage('assets/avatar.png'),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        (_userInfo?.fullName.isNotEmpty == true)
                            ? _userInfo!.fullName
                            : _displayNameFromUser(),
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4EEF9B),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.notifications, color: Color(0xFF4EEF9B)),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                        onPressed: () => _handleSignOut(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Welcome Text
              Text(
                'Welcome Back, ${_userInfo?.email ?? _authService.currentUser?.email ?? 'user'}',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              // Status badges
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF133623),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF1F4D33)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4EEF9B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SYSTEM STATUS: ARMED',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4EEF9B),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 14, color: textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'SHSMA SECURE',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // AI Detection Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AI DETECTION ENGINE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                              color: textSecondary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Icon(Icons.face_retouching_natural, color: Color(0xFF4EEF9B), size: 24),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Human Detected',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '98% Confidence',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4EEF9B),
                          ),
                        ),
                        Text(
                          ' • Today, 14:24',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.98,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF4EEF9B),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Sensor Status Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SENSOR STATUS',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'ALL POINTS SECURE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4EEF9B),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Sensor Grid
              Row(
                children: [
                  Expanded(child: _buildSensorCard(context, 'MOTION DETECTED', 'Front Porch', Icons.radar, true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSensorCard(context, 'DOOR CLOSED', 'Main Entrance', Icons.door_sliding, false)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildSensorCard(context, 'ALL SECURE', 'Garage', Icons.check_circle_outline, false)),
                  const SizedBox(width: 12),
                  Expanded(child: const SizedBox()), 
                ],
              ),
              const SizedBox(height: 32),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(context, 'ARM', Icons.shield, accent),
                  _buildActionButton(context, 'DISARM', Icons.gpp_good_outlined, textSecondary),
                  _buildActionButton(context, 'TRIGGER', Icons.warning_amber_rounded, const Color(0xFFFF4949), isDanger: true),
                ],
              ),
              const SizedBox(height: 32),
              // Camera Devices Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CAMERA DEVICES',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Icon(Icons.videocam, color: Color(0xFF4EEF9B), size: 18),
                ],
              ),
              const SizedBox(height: 16),
              // Camera status tiles, live-polled from the go2rtc relay (same source as the Cameras page).
              Row(
                children: [
                  Expanded(
                    child: _buildCameraStatusCard(context, 'Front Camera', _frontCameraOnline),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCameraStatusCard(context, 'Back Camera', _backCameraOnline),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Recent Activity Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECENT ACTIVITY',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Icon(Icons.history, color: textSecondary, size: 18),
                ],
              ),
              const SizedBox(height: 16),
              // Activity Items
              _buildActivityItem(context, 'AI: Human Detected', 'Front Door • 98% Conf • 2m ago', Icons.face, const Color(0xFF4EEF9B)),
              _buildActivityItem(context, 'Sensor: Motion Event', 'Backyard • 15m ago', Icons.radar, textSecondary),
              _buildActivityItem(context, 'Sensor: Door Locked', 'Main Entrance • 1h ago', Icons.door_sliding, textSecondary),
              _buildActivityItem(context, 'System: Disarmed', 'Mobile App • 3h ago', Icons.lock_open, textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraStatusCard(BuildContext context, String name, bool isOnline) {
    final panel = context.tertiarySurface;
    final borderColor = context.canvasBorder;
    final textPrimary = context.headingText;
    final textSecondary = context.mutedText;
    final statusColor = isOnline ? const Color(0xFF4EEF9B) : textSecondary;

    return Material(
      color: panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Reuse the bottom-nav Cameras tab instead of pushing a second CameraScreen,
          // which would compete with it for the same camera stream and cause disconnects.
          if (widget.onOpenCamera != null) {
            widget.onOpenCamera!();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
          }
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isOnline ? statusColor : borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_outlined, color: statusColor, size: 24),
              const SizedBox(height: 8),
              Text(
                name,
                style: GoogleFonts.outfit(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                isOnline ? 'ONLINE' : 'OFFLINE',
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorCard(BuildContext context, String title, String subtitle, IconData icon, bool isActive) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panel = context.tertiarySurface;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE3E8EF);
    final textPrimary = context.headingText;
    final textSecondary = context.mutedText;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isActive ? (isDark ? Colors.white24 : const Color(0xFFCBD5E1)) : borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: isActive ? const Color(0xFF4EEF9B) : textSecondary, size: 28),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: textPrimary), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, {bool isDanger = false}) {
    final panel = context.tertiarySurface;
    final textSecondary = context.mutedText;

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isDanger ? const Color(0xFF3B1515) : panel,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(icon, color: color, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDanger ? color : textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(BuildContext context, String title, String subtitle, IconData icon, Color iconColor) {
    final panel = context.tertiarySurface;
    final borderColor = context.isDarkMode ? Colors.white10 : const Color(0xFFE3E8EF);
    final textPrimary = context.headingText;
    final textSecondary = context.mutedText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: panel,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
