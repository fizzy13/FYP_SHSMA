import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth_service.dart';
import '../models/user_model.dart';
import '../services/user_info_service.dart';
import '../theme_helpers.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final UserInfoService _userInfoService = UserInfoService();
  UserInfo? _userInfo;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
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
                        _userInfo?.fullName ?? _authService.currentUser?.displayName ?? 'User',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4EEF9B),
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.notifications, color: Color(0xFF4EEF9B)),
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
              // Live Camera Devices from Firebase
              StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('devices')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: borderColor),
                      ),
                      child: Center(
                        child: Text(
                          'No devices found',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    );
                  }

                  var devices = snapshot.data!.docs;

                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: borderColor),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        var device = devices[index];
                        String deviceName = device['device_name'] ?? 'Unknown Device';
                        String deviceStatus = device['status'] ?? 'offline';
                        bool isOnline = deviceStatus.toLowerCase() == 'online';

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: panel,
                            border: Border(
                              bottom: index < devices.length - 1
                                  ? BorderSide(color: borderColor)
                                  : BorderSide.none,
                            ),
                            borderRadius: index == 0
                                ? const BorderRadius.only(
                                    topLeft: Radius.circular(28),
                                    topRight: Radius.circular(28),
                                  )
                                : index == devices.length - 1
                                    ? const BorderRadius.only(
                                        bottomLeft: Radius.circular(28),
                                        bottomRight: Radius.circular(28),
                                      )
                                    : BorderRadius.zero,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? bg : const Color(0xFFF4F6F8),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isOnline
                                            ? const Color(0xFF4EEF9B)
                                            : borderColor,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.videocam,
                                      color: isOnline
                                          ? const Color(0xFF4EEF9B)
                                          : textSecondary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        deviceName,
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isOnline ? 'ONLINE' : 'OFFLINE',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isOnline
                                              ? const Color(0xFF4EEF9B)
                                              : textSecondary,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF4EEF9B).withValues(alpha: 0.1)
                                      : panel,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isOnline
                                        ? const Color(0xFF4EEF9B).withValues(alpha: 0.3)
                                        : borderColor,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isOnline
                                            ? const Color(0xFF4EEF9B)
                                            : textSecondary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'VIEW',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isOnline
                                            ? const Color(0xFF4EEF9B)
                                            : textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
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
