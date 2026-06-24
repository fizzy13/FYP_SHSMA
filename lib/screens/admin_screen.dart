import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_service.dart';
import '../models/user_model.dart';
import '../theme_helpers.dart';
import '../theme_manager.dart';
import 'camera_screen.dart';
import 'welcome_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const String _usersCollectionName = 'Users';
  static const String _activityLogsCollectionName = 'activity_logs';
  static const Duration _activeSessionWindow = Duration(minutes: 5);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Switches state
  bool _humanDetection = true;
  bool _faceRecognition = true;
  bool _petFiltering = false;

  // Navigation state
  int _currentPage = 0; // 0: Dashboard, 1: Camera, 2: Statistics, 3: Shield
  bool _showSettings = false;
  bool _darkModeEnabled = true;
  Color get _primaryTextColor => context.headingText;
  Color get _secondaryTextColor => context.mutedText;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _activityLogsStream;

  @override
  void initState() {
    super.initState();
    _usersStream = _firestore.collection(_usersCollectionName).snapshots();
    _activityLogsStream = _firestore
        .collection(_activityLogsCollectionName)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 7)),
          ),
        )
        .snapshots();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _darkModeEnabled = isDark;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            if (_currentPage == 0)
              _buildDashboard()
            else if (_currentPage == 1)
              _buildCameraPage()
            else if (_currentPage == 2)
              _buildStatisticsPage()
            else
              _buildShieldPage(),

            // Semi-transparent backdrop when settings is open
            if (_showSettings)
              GestureDetector(
                onTap: () => setState(() => _showSettings = false),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),

            // Settings sidebar
            if (_showSettings)
              _buildSettingsOverlay(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      extendBody: true,
    );
  }

  Stream<UserInfo?> _adminInfoStream() {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      return Stream<UserInfo?>.value(null);
    }
    return _authService.getUserInfoStreamByUid(uid);
  }

  String _displayNameFromUser(User? user) {
    final fullName = user?.displayName;
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.contains('@') ? email.split('@').first : email;
    }

    return 'Admin';
  }

  String _resolveAdminName(UserInfo? info) {
    final fullName = info?.fullName.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }
    return _displayNameFromUser(_authService.currentUser);
  }

  Future<void> _showChangeAdminNameDialog() async {
    final currentName = _displayNameFromUser(_authService.currentUser);
    final nameController = TextEditingController(text: currentName);

    await showDialog<void>(
      context: context,
      builder: (context) {
        bool isSubmitting = false;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Change Name', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: GoogleFonts.inter()),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final newName = nameController.text.trim();
                          if (newName.isEmpty) {
                            setState(() => errorText = 'Name cannot be empty.');
                            return;
                          }

                          setState(() {
                            isSubmitting = true;
                            errorText = null;
                          });

                          try {
                            final currentUser = _authService.currentUser;
                            if (currentUser == null) {
                              throw Exception('No authenticated admin found.');
                            }

                            final currentInfo = await _authService.getCurrentUserInfo();
                            final updatedInfo = (currentInfo ??
                                    UserInfo(
                                      uid: currentUser.uid,
                                      email: currentUser.email ?? '',
                                      phoneNumber: '',
                                      address: '',
                                      fullName: newName,
                                      createdAt: DateTime.now(),
                                    ))
                                .copyWith(
                                  uid: currentUser.uid,
                                  email: currentUser.email ?? currentInfo?.email ?? '',
                                  fullName: newName,
                                );

                            await _authService.updateUserInfo(updatedInfo);

                            if (!mounted) return;
                            Navigator.of(this.context).pop();
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Name updated successfully.', style: GoogleFonts.inter()),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (_) {
                            setState(() {
                              errorText = 'Unable to update name right now.';
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
                      : Text('Save', style: GoogleFonts.inter()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showChangeAdminPasswordDialog() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        bool showNewPassword = false;
        bool showConfirmPassword = false;
        bool isSubmitting = false;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Change Password', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newPasswordController,
                    obscureText: !showNewPassword,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(showNewPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            showNewPassword = !showNewPassword;
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
                        icon: Icon(showConfirmPassword ? Icons.visibility : Icons.visibility_off),
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
                    Text(
                      errorText!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
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
                            Navigator.of(this.context).pop();
                            ScaffoldMessenger.of(this.context).showSnackBar(
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
                          } catch (_) {
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

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          const SizedBox(height: 32),
          _buildTitle(),
          const SizedBox(height: 32),
          _buildManageUsersCard(),
          const SizedBox(height: 24),
          _buildAiDetectionCard(),
          const SizedBox(height: 24),
          _buildManageDevicesCard(),
          const SizedBox(height: 24),
          _buildSystemLogsCard(),
          const SizedBox(height: 100), // Space for bottom nav
        ],
      ),
    );
  }

  Widget _buildCameraPage() {
    final borderColor = context.canvasBorder;
    final accent = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          const SizedBox(height: 32),
          Text(
            'Camera Stream',
            style: GoogleFonts.outfit(
              color: _primaryTextColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00E676),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE MONITORING',
                style: GoogleFonts.inter(
                  color: _secondaryTextColor,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'ESP32-CAM LIVE',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Esp32SensorBar(hostIp: kEsp32HostIp),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: context.secondarySurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.0,
              children: kEsp32DeviceList.map((device) {
                return CameraFeedCard(
                  ip: device['ip'] ?? '',
                  label: device['label'] ?? 'Camera',
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatisticsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          const SizedBox(height: 32),
          _buildStatisticsHeader(),
          const SizedBox(height: 32),
          _buildLiveStatisticsSection(),
          const SizedBox(height: 24),
          _buildRegionalDistributionCard(),
          const SizedBox(height: 24),
          _buildSecuritySegmentsCard(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildShieldPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          const SizedBox(height: 32),
          Text(
            'Security Center',
            style: GoogleFonts.outfit(
              color: _primaryTextColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00E676),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SECURITY OVERVIEW',
                style: GoogleFonts.inter(
                  color: _secondaryTextColor,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Coming soon...',
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatisticsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'User Statistics',
              style: GoogleFonts.outfit(
                color: _primaryTextColor,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4EEF9B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Last 7 Days',
                style: GoogleFonts.inter(
                  color: const Color(0xFF0C100E),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: context.tertiarySurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Download Report',
            style: GoogleFonts.inter(
              color: const Color(0xFF4EEF9B),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveStatisticsSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream,
      builder: (context, usersSnapshot) {
        if (usersSnapshot.hasError) {
          return _buildCardContainer(
            child: Text(
              'Unable to load user statistics right now.',
              style: GoogleFonts.inter(color: _secondaryTextColor, fontSize: 12),
            ),
          );
        }

        if (!usersSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final usersDocs = usersSnapshot.data!.docs;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _activityLogsStream,
          builder: (context, logsSnapshot) {
            if (logsSnapshot.hasError) {
              return _buildCardContainer(
                child: Text(
                  'Unable to load activity trends right now.',
                  style: GoogleFonts.inter(color: _secondaryTextColor, fontSize: 12),
                ),
              );
            }

            final logsDocs = logsSnapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final metrics = _computeLiveUserStats(usersDocs, logsDocs);

            return Column(
              children: [
                _buildStatisticsCardsWithData(metrics),
                const SizedBox(height: 24),
                _buildActivityTrendsCard(metrics.trendPoints),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatisticsCardsWithData(_LiveUserStatsMetrics metrics) {
    return Column(
      children: [
        _buildStatCard(
          title: 'TOTAL USERS',
          value: _formatCount(metrics.totalUsers),
          change: '+ LIVE',
          changeColor: const Color(0xFF4EEF9B),
        ),
        const SizedBox(height: 16),
        _buildStatCard(
          title: 'ACTIVE NOW',
          value: _formatCount(metrics.activeUsers),
          change: '● LIVE',
          changeColor: const Color(0xFF4EEF9B),
        ),
        const SizedBox(height: 16),
        _buildStatCard(
          title: 'INACTIVE',
          value: _formatCount(metrics.inactiveUsers),
          change: '● TRACKED',
          changeColor: Colors.redAccent,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String change,
    required Color changeColor,
  }) {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
                  color: _secondaryTextColor.withValues(alpha: 0.7),
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  color: _primaryTextColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                change,
                style: GoogleFonts.inter(
                  color: changeColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTrendsCard(List<_ActivityTrendPoint> points) {
    final maxCount = points.isEmpty
        ? 1
        : points
            .map((point) => point.activeUsers > point.inactiveUsers ? point.activeUsers : point.inactiveUsers)
            .reduce((a, b) => a > b ? a : b);

    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Activity Trends',
            style: GoogleFonts.outfit(
              color: const Color(0xFF4EEF9B),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comparing real-time active sessions vs inactive accounts',
            style: GoogleFonts.inter(
              color: _secondaryTextColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: context.appBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: points
                    .map(
                      (point) => _buildTrendBarPair(
                        point.dayLabel,
                        point.activeUsers,
                        point.inactiveUsers,
                        maxCount,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF4EEF9B),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ACTIVE',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(width: 24),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'INACTIVE',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendBarPair(
    String day,
    int activeUsers,
    int inactiveUsers,
    int maxCount,
  ) {
    final activeHeight = maxCount == 0 ? 4.0 : (activeUsers / maxCount) * 80;
    final inactiveHeight = maxCount == 0 ? 4.0 : (inactiveUsers / maxCount) * 80;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 8,
              height: activeHeight < 4 ? 4 : activeHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF4EEF9B),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: inactiveHeight < 4 ? 4 : inactiveHeight,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }

  _LiveUserStatsMetrics _computeLiveUserStats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> usersDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> logsDocs,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(const Duration(days: 6));

    final userIds = <String>{};
    final usersById = <String, Map<String, dynamic>>{};

    for (final doc in usersDocs) {
      final data = doc.data();
      final docId = doc.id.trim();
      if (docId.isNotEmpty) {
        userIds.add(docId);
        usersById[docId] = data;
      }

      final uid = (data['uid'] ?? '').toString().trim();
      if (uid.isNotEmpty) {
        userIds.add(uid);
        usersById[uid] = data;
      }
    }

    final activeNowIds = <String>{};

    for (final entry in usersById.entries) {
      if (_isMarkedActive(entry.value, now)) {
        activeNowIds.add(entry.key);
      }
    }

    final activeByDay = <String, Set<String>>{};
    for (var i = 0; i < 7; i++) {
      final day = startDate.add(Duration(days: i));
      activeByDay[_dayKey(day)] = <String>{};
    }

    for (final logDoc in logsDocs) {
      final data = logDoc.data();
      final userId = (data['userId'] ?? '').toString().trim();
      if (userId.isEmpty || !userIds.contains(userId)) {
        continue;
      }

      final activityTime = _asDateTime(data['timestamp']) ?? _asDateTime(data['clientTimestamp']);
      if (activityTime == null) {
        continue;
      }

      final localTime = activityTime.toLocal();
      if (now.difference(localTime) <= _activeSessionWindow) {
        activeNowIds.add(userId);
      }

      final day = DateTime(localTime.year, localTime.month, localTime.day);
      if (day.isBefore(startDate) || day.isAfter(today)) {
        continue;
      }

      activeByDay[_dayKey(day)]?.add(userId);
    }

    final totalUsers = usersDocs.length;
    final uniqueActiveNow = activeNowIds.length > totalUsers ? totalUsers : activeNowIds.length;
    final inactiveUsers = totalUsers - uniqueActiveNow < 0 ? 0 : totalUsers - uniqueActiveNow;

    final trendPoints = <_ActivityTrendPoint>[];
    for (var i = 0; i < 7; i++) {
      final day = startDate.add(Duration(days: i));
      final activeUsers = activeByDay[_dayKey(day)]?.length ?? 0;
      final inactiveForDay = totalUsers - activeUsers < 0 ? 0 : totalUsers - activeUsers;
      trendPoints.add(
        _ActivityTrendPoint(
          dayLabel: _dayLabel(day.weekday),
          activeUsers: activeUsers,
          inactiveUsers: inactiveForDay,
        ),
      );
    }

    return _LiveUserStatsMetrics(
      totalUsers: totalUsers,
      activeUsers: uniqueActiveNow,
      inactiveUsers: inactiveUsers,
      trendPoints: trendPoints,
    );
  }

  bool _isMarkedActive(Map<String, dynamic> data, DateTime now) {
    final status = (data['status'] ?? data['userStatus'] ?? '').toString().toLowerCase();
    if (status == 'online' || status == 'active' || status == 'live') {
      return true;
    }

    final isActive = data['isActive'];
    if (isActive is bool && isActive) {
      return true;
    }

    final lastSeen = _asDateTime(data['lastSeen']) ??
        _asDateTime(data['lastActiveAt']) ??
        _asDateTime(data['updatedAt']);
    if (lastSeen == null) {
      return false;
    }

    return now.difference(lastSeen.toLocal()) <= _activeSessionWindow;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  String _dayKey(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }

  String _dayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'MON';
      case DateTime.tuesday:
        return 'TUE';
      case DateTime.wednesday:
        return 'WED';
      case DateTime.thursday:
        return 'THU';
      case DateTime.friday:
        return 'FRI';
      case DateTime.saturday:
        return 'SAT';
      default:
        return 'SUN';
    }
  }

  String _formatCount(int value) {
    final text = value.toString();
    return text.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
  }

  Widget _buildRegionalDistributionCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Regional Distribution',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF4EEF9B),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'VIEW MAP',
                style: GoogleFonts.inter(
                  color: const Color(0xFF4EEF9B),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildRegionItem('North America', 62),
          const SizedBox(height: 16),
          _buildRegionItem('European Union', 31),
          const SizedBox(height: 16),
          _buildRegionItem('Asia Pacific', 18),
        ],
      ),
    );
  }

  Widget _buildRegionItem(String region, int percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4EEF9B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.public,
                      size: 12, color: Color(0xFF0C100E)),
                ),
                const SizedBox(width: 12),
                Text(
                  region,
                  style: GoogleFonts.inter(
                    color: _primaryTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              '$percentage%',
              style: GoogleFonts.inter(
                color: _secondaryTextColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            backgroundColor: context.canvasBorder,
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF4EEF9B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySegmentsCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Security Segments',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF4EEF9B),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.appBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'AI SORTED',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF4EEF9B),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSegmentItem('Enterprise Nodes', 'High Traffic Volume', '824'),
          const SizedBox(height: 16),
          _buildSegmentItem('Guardian Proxies', 'Residential/SOHO', '5,102'),
          const SizedBox(height: 16),
          _buildSegmentItem('Sentinel Guests', 'Public Verification', '12,488'),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(String title, String subtitle, String count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: _primaryTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: _secondaryTextColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Text(
            count,
            style: GoogleFonts.outfit(
              color: const Color(0xFF4EEF9B),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsOverlay() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 380,
      child: Container(
        decoration: BoxDecoration(
          color: context.tertiarySurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Settings Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              decoration: BoxDecoration(
                color: context.tertiarySurface,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white10,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Settings',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF4EEF9B),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_forward,
                            color: Color(0xFF4EEF9B), size: 20),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: _secondaryTextColor, size: 20),
                        onPressed: () {
                          setState(() => _showSettings = false);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Settings Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.appBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundImage: NetworkImage(
                              'https://i.pravatar.cc/150?img=47',
                            ),
                          ),
                          const SizedBox(width: 16),
                          StreamBuilder<UserInfo?>(
                            stream: _adminInfoStream(),
                            builder: (context, snapshot) {
                              final adminName = _resolveAdminName(snapshot.data);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    adminName,
                                    style: GoogleFonts.outfit(
                                      color: _primaryTextColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Administrator',
                                    style: GoogleFonts.inter(
                                      color: _secondaryTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Manage Account Section
                    _buildSettingGroup(
                      'MANAGE ACCOUNT',
                      [
                        _buildSimpleSettingItem(
                          'Change Name',
                          Icons.check_circle_outline,
                          onTap: _showChangeAdminNameDialog,
                        ),
                        _buildSimpleSettingItem(
                          'Change Password',
                          Icons.check_circle_outline,
                          onTap: _showChangeAdminPasswordDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // App Settings Section
                    Text(
                      'APP SETTINGS',
                      style: GoogleFonts.inter(
                        color: _secondaryTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDarkModeToggle(),
                    const SizedBox(height: 200),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleSettingItem(String title, IconData icon, {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF4EEF9B), size: 20),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: _primaryTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Icon(Icons.chevron_right, color: _secondaryTextColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDarkModeToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.dark_mode, color: const Color(0xFF4EEF9B), size: 20),
              const SizedBox(width: 12),
              Text(
                'Dark Mode',
                style: GoogleFonts.inter(
                  color: _primaryTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Switch(
            value: _darkModeEnabled,
            onChanged: (val) {
              setState(() => _darkModeEnabled = val);
              AppTheme.setDarkMode(val);
            },
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF4EEF9B).withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.white10,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingGroup(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: _secondaryTextColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          items.length,
          (index) => Column(
            children: [
              items[index],
              if (index < items.length - 1) const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(
            'https://i.pravatar.cc/150?img=47',
          ),
        ),
        const SizedBox(width: 12),
        StreamBuilder<UserInfo?>(
          stream: _adminInfoStream(),
          builder: (context, snapshot) {
            final adminName = _resolveAdminName(snapshot.data);
            return Text(
              adminName,
              style: GoogleFonts.outfit(
                color: const Color(0xFF00E676),
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            );
          },
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.notifications, color: Color(0xFF00E676)),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: Color(0xFF00E676)),
          onPressed: () {
            setState(() => _showSettings = true);
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              (route) => false,
            );
          },
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Admin Panel',
          style: GoogleFonts.outfit(
            color: _primaryTextColor,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF00E676),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'SHSMA ECOSYSTEM ONLINE',
              style: GoogleFonts.inter(
                color: _secondaryTextColor,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: context.mutedText.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            color: const Color(0xFF4EEF9B),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildManageUsersCard() {
    return StreamBuilder<UserInfo?>(
      stream: _adminInfoStream(),
      builder: (context, snapshot) {
        final adminName = _resolveAdminName(snapshot.data);

        return _buildCardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Manage Users',
                trailing: Row(
                  children: [
                    Icon(Icons.person_add, color: _secondaryTextColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'ADD MEMBER',
                      style: GoogleFonts.inter(
                        color: _secondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildUserRow(
                name: adminName,
                role: 'Administrator',
                status: 'ACTIVE',
                avatarUrl: 'https://i.pravatar.cc/150?img=47',
                statusColor: const Color(0xFF00E676),
              ),
              const SizedBox(height: 16),
              _buildUserRow(
                name: 'Marcus Chen',
                role: 'Family Member',
                status: 'LIMITED',
                avatarUrl: 'https://i.pravatar.cc/150?img=11',
                statusColor: Colors.white54,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserRow({
    required String name,
    required String role,
    required String status,
    required String avatarUrl,
    required Color statusColor,
  }) {
    final borderColor = context.isDarkMode ? Colors.white10 : const Color(0xFFE3E8EF);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    color: _primaryTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  role,
                  style: GoogleFonts.inter(color: _secondaryTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: context.tertiarySurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiDetectionCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('AI Detection'),
          const SizedBox(height: 24),
          _buildSwitchRow(
            title: 'Human Detection',
            subtitle: 'Neural motion filtering',
            value: _humanDetection,
            onChanged: (val) => setState(() => _humanDetection = val),
          ),
          const SizedBox(height: 20),
          _buildSwitchRow(
            title: 'Face Recognition',
            subtitle: 'Identify known profiles',
            value: _faceRecognition,
            onChanged: (val) => setState(() => _faceRecognition = val),
          ),
          const SizedBox(height: 20),
          _buildSwitchRow(
            title: 'Pet Filtering',
            subtitle: 'Ignore animal activity',
            value: _petFiltering,
            onChanged: (val) => setState(() => _petFiltering = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                color: _primaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(color: _secondaryTextColor, fontSize: 12),
            ),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF00E676),
          activeTrackColor: const Color(0xFF00E676).withValues(alpha: 0.3),
          inactiveThumbColor: Colors.grey,
          inactiveTrackColor: Colors.white10,
        ),
      ],
    );
  }

  Widget _buildManageDevicesCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Manage Devices',
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.tertiarySurface,
                shape: BoxShape.circle,
                border: Border.all(color: context.mutedText.withValues(alpha: 0.10)),
              ),
              child: const Icon(Icons.sync, color: Color(0xFF4EEF9B), size: 18),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '12 ACTIVE NODES',
            style: GoogleFonts.inter(
              color: _secondaryTextColor,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Camera Monitor',
            style: GoogleFonts.outfit(
              color: _primaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Esp32SensorBar(hostIp: kEsp32HostIp),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: context.secondarySurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.canvasBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.0,
              children: kEsp32DeviceList.map((device) {
                return CameraFeedCard(
                  ip: device['ip'] ?? '',
                  label: device['label'] ?? 'Camera',
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDeviceItem({
    required IconData icon,
    required String name,
    required String status,
    required Color statusColor,
    required bool isOnline,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF00E676), size: 28),
          const Spacer(),
          Text(
            name,
            style: GoogleFonts.outfit(
              color: _primaryTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (isOnline)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                status,
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemLogsCard() {
    return StreamBuilder<UserInfo?>(
      stream: _adminInfoStream(),
      builder: (context, snapshot) {
        final adminName = _resolveAdminName(snapshot.data);

        return _buildCardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'System Logs',
                trailing: Text(
                  'EXPORT',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildLogItem(
                '14:02',
                'INFO',
                '[Human Detected] Front Door Cam',
                const Color(0xFF00E676),
              ),
              const SizedBox(height: 12),
              _buildLogItem(
                '13:45',
                'INFO',
                '[Lock Engaged] Main Entry',
                const Color(0xFF00E676),
              ),
              const SizedBox(height: 12),
              _buildLogItem(
                '13:12',
                'WARN',
                '[Low Battery] Garage Sensor',
                Colors.orangeAccent,
              ),
              const SizedBox(height: 12),
              _buildLogItem(
                '12:58',
                'INFO',
                '[Auth] $adminName logged in',
                const Color(0xFF00E676),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: context.tertiarySurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    'VIEW FULL HISTORY',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF4EEF9B),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogItem(
    String time,
    String level,
    String message,
    Color levelColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: levelColor.withValues(alpha: 0.5), width: 2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: GoogleFonts.jetBrainsMono(
              color: _secondaryTextColor.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            level,
            style: GoogleFonts.jetBrainsMono(
              color: levelColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.jetBrainsMono(
                color: _secondaryTextColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.tertiarySurface,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              Icons.space_dashboard_rounded,
              color: _currentPage == 0
                  ? const Color(0xFF4EEF9B)
                  : (context.isDarkMode ? Colors.white54 : Colors.black54),
            ),
            onPressed: () => setState(() => _currentPage = 0),
          ),
          IconButton(
            icon: Icon(
              Icons.videocam_rounded,
              color: _currentPage == 1
                  ? const Color(0xFF4EEF9B)
                  : (context.isDarkMode ? Colors.white54 : Colors.black54),
            ),
            onPressed: () => setState(() => _currentPage = 1),
          ),
          IconButton(
            icon: Icon(
              Icons.insert_chart_rounded,
              color: _currentPage == 2
                  ? const Color(0xFF4EEF9B)
                  : (context.isDarkMode ? Colors.white54 : Colors.black54),
            ),
            onPressed: () => setState(() => _currentPage = 2),
          ),
          GestureDetector(
            onTap: () => setState(() => _currentPage = 3),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _currentPage == 3
                    ? const Color(0xFF4EEF9B)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: _currentPage == 3
                    ? null
                    : Border.all(
                        color: context.isDarkMode ? Colors.white54 : Colors.black12,
                        width: 2,
                      ),
              ),
              child: Icon(
                Icons.shield,
                color: _currentPage == 3
                    ? const Color(0xFF0C100E)
                    : (context.isDarkMode ? Colors.white54 : Colors.black54),
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveUserStatsMetrics {
  const _LiveUserStatsMetrics({
    required this.totalUsers,
    required this.activeUsers,
    required this.inactiveUsers,
    required this.trendPoints,
  });

  final int totalUsers;
  final int activeUsers;
  final int inactiveUsers;
  final List<_ActivityTrendPoint> trendPoints;
}

class _ActivityTrendPoint {
  const _ActivityTrendPoint({
    required this.dayLabel,
    required this.activeUsers,
    required this.inactiveUsers,
  });

  final String dayLabel;
  final int activeUsers;
  final int inactiveUsers;
}
