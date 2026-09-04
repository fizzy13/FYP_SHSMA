import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_service.dart';
import '../models/user_model.dart';
import '../theme_helpers.dart';
import '../theme_manager.dart';
import 'camera_screen.dart';
import 'welcome_screen.dart';

const String _kPrefTapoRelayIp = 'tapo_relay_ip';
const String _kPrefTapoRelayPort = 'tapo_relay_port';
const String _kPrefTapoStreamName = 'tapo_stream_name';
const String _kPrefTapoStreamName2 = 'tapo_stream_name2';

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
  bool _animalDetection = true;

  // Live-polled camera reachability, mirrors the user dashboard status tiles.
  bool _frontCameraOnline = false;
  bool _backCameraOnline = false;
  Timer? _cameraStatusTimer;
  String _tapoRelayIp = kTapoDefaultRelayIp;
  String _tapoRelayPort = kTapoDefaultRelayPort;
  String _tapoStreamName = kTapoDefaultStreamName;
  String _tapoStreamName2 = kTapoDefaultStreamName2;

  // Navigation state
  int _currentPage = 0; // 0: Dashboard, 1: Statistics, 2: Shield
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
    _loadCameraConfigAndPoll();
    _loadManagedDetectionOptions();
  }

  @override
  void dispose() {
    _cameraStatusTimer?.cancel();
    super.dispose();
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

  Future<void> _loadManagedDetectionOptions() async {
    final settings = await _firestore.collection('ai_detection_settings').doc('current').get();
    if (!mounted || !settings.exists) return;
    final data = settings.data()!;
    setState(() {
      _humanDetection = data['humanDetectionEnabled'] as bool? ?? true;
      _animalDetection = data['animalDetectionEnabled'] as bool? ?? true;
    });
  }

  Future<void> _updateManagedDetectionOptions({bool? human, bool? animal}) async {
    final nextHuman = human ?? _humanDetection;
    final nextAnimal = animal ?? _animalDetection;
    setState(() {
      _humanDetection = nextHuman;
      _animalDetection = nextAnimal;
    });
    try {
      await _authService.setManagedDetectionOptions(
        humanDetectionEnabled: nextHuman,
        animalDetectionEnabled: nextAnimal,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _humanDetection = !nextHuman;
        _animalDetection = !nextAnimal;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update AI detection settings.')),
      );
    }
  }

  Future<void> _showAddMemberDialog() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    var passwordVisible = false;
    var submitting = false;
    var dialogOpen = true;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add Administrator', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: !passwordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: passwordVisible ? 'Hide password' : 'Show password',
                    onPressed: () => setDialogState(() => passwordVisible = !passwordVisible),
                    icon: Icon(passwordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(errorMessage!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () {
                      dialogOpen = false;
                      Navigator.pop(dialogContext);
                    },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final username = usernameController.text.trim();
                      final password = passwordController.text;
                      if (username.isEmpty || password.length < 6) {
                        setDialogState(() => errorMessage = 'Enter a username and a password of at least 6 characters.');
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                        errorMessage = null;
                      });
                      try {
                        await _authService.createAdministrator(username: username, password: password);
                        if (dialogContext.mounted) {
                          dialogOpen = false;
                          Navigator.pop(dialogContext);
                        }
                      } on FirebaseAuthException catch (error) {
                        setDialogState(() => errorMessage = error.message ?? 'Unable to create administrator.');
                      } catch (_) {
                        setDialogState(() => errorMessage = 'Unable to create administrator.');
                      } finally {
                        if (dialogOpen && dialogContext.mounted) {
                          setDialogState(() => submitting = false);
                        }
                      }
                    },
              child: Text(submitting ? 'Creating...' : 'Add Member'),
            ),
          ],
        ),
      ),
    );
    usernameController.dispose();
    passwordController.dispose();
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildCardContainer(
            child: Text(
              'Unable to load regional distribution right now.',
              style: GoogleFonts.inter(color: _secondaryTextColor, fontSize: 12),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final regions = _computeRegionalDistribution(snapshot.data!.docs);
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
                    '${_formatCount(regions.totalUsers)} USERS',
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
              if (regions.items.isEmpty)
                Text(
                  'No users have selected a country yet.',
                  style: GoogleFonts.inter(color: _secondaryTextColor, fontSize: 12),
                )
              else
                ...regions.items.expand(
                  (region) => [
                    _buildRegionItem(region),
                    const SizedBox(height: 16),
                  ],
                ).toList()
                  ..removeLast(),
            ],
          ),
        );
      },
    );
  }

  _RegionalDistribution _computeRegionalDistribution(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
  ) {
    final counts = <String, int>{};
    var totalUsers = 0;
    for (final user in users) {
      final country = (user.data()['country'] ?? '').toString().trim();
      if (country.isEmpty) continue;
      final region = _regionForCountry(country);
      counts[region] = (counts[region] ?? 0) + 1;
      totalUsers++;
    }

    final items = counts.entries
        .map((entry) => _RegionalDistributionItem(
              region: entry.key,
              userCount: entry.value,
              percentage: totalUsers == 0 ? 0 : (entry.value / totalUsers) * 100,
            ))
        .toList()
      ..sort((left, right) => right.userCount.compareTo(left.userCount));
    return _RegionalDistribution(totalUsers: totalUsers, items: items);
  }

  String _regionForCountry(String country) {
    switch (country) {
      case 'Malaysia':
      case 'Singapore':
      case 'Indonesia':
      case 'Thailand':
      case 'Brunei':
      case 'Philippines':
      case 'Vietnam':
      case 'China':
      case 'India':
      case 'Japan':
      case 'South Korea':
      case 'Australia':
        return 'Asia Pacific';
      case 'United Kingdom':
        return 'Europe';
      case 'United States':
        return 'North America';
      default:
        return 'Other';
    }
  }

  Widget _buildRegionItem(_RegionalDistributionItem item) {
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
                  item.region,
                  style: GoogleFonts.inter(
                    color: _primaryTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              '${_formatCount(item.userCount)} (${item.percentage.round()}%)',
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
            value: item.percentage / 100,
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream,
      builder: (context, snapshot) {
        final currentAdmin = _authService.currentUser;
        final currentAdminId = currentAdmin?.uid;
        final members = snapshot.data?.docs
                .where(
                  (doc) =>
                      doc.data()['role'] == 'Administrator' &&
                      doc.id != currentAdminId,
                )
                .toList() ??
            const [];
        return _buildCardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Manage Users',
                trailing: TextButton.icon(
                  onPressed: _showAddMemberDialog,
                  icon: Icon(Icons.person_add, color: _secondaryTextColor, size: 16),
                  label: Text('ADD MEMBER', style: GoogleFonts.inter(color: _secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
              _buildUserRow(
                name: _displayNameFromUser(currentAdmin),
                role: 'Administrator',
                status: 'ACTIVE',
                avatarUrl: 'https://i.pravatar.cc/150?img=47',
                statusColor: const Color(0xFF00E676),
              ),
              if (members.isNotEmpty) const SizedBox(height: 16),
              ...members.map((member) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildUserRow(
                        name: (member.data()['fullName'] ?? member.data()['email'] ?? 'Administrator').toString(),
                        role: 'Administrator',
                        status: (member.data()['accountStatus'] ?? 'ACTIVE').toString(),
                        avatarUrl: 'https://i.pravatar.cc/150?img=47',
                        statusColor: const Color(0xFF00E676),
                      ),
                    )),
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
          _buildSectionHeader('Manage AI Detection'),
          const SizedBox(height: 24),
          _buildSwitchRow(
            title: 'Human Detection',
            subtitle: 'Neural motion filtering',
            value: _humanDetection,
            onChanged: (val) => _updateManagedDetectionOptions(human: val),
          ),
          const SizedBox(height: 20),
          _buildSwitchRow(
            title: 'Animal Detection',
            subtitle: 'Detect cats, dogs, and birds',
            value: _animalDetection,
            onChanged: (val) => _updateManagedDetectionOptions(animal: val),
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
          Esp32SensorBar(hostIp: kEsp32HostIp, showConditionLabel: true),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildCameraStatusBox(context, 'Front Camera', _frontCameraOnline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCameraStatusBox(context, 'Back Camera', _backCameraOnline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCameraStatusBox(BuildContext context, String name, bool isOnline) {
    final panel = context.tertiarySurface;
    final borderColor = context.canvasBorder;
    final statusColor = isOnline ? const Color(0xFF4EEF9B) : _secondaryTextColor;

    return Material(
      color: panel,
      borderRadius: BorderRadius.circular(16),
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
                color: _primaryTextColor,
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
              Icons.insert_chart_rounded,
              color: _currentPage == 1
                  ? const Color(0xFF4EEF9B)
                  : (context.isDarkMode ? Colors.white54 : Colors.black54),
            ),
            onPressed: () => setState(() => _currentPage = 1),
          ),
          GestureDetector(
            onTap: () => setState(() => _currentPage = 2),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _currentPage == 2
                    ? const Color(0xFF4EEF9B)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: _currentPage == 2
                    ? null
                    : Border.all(
                        color: context.isDarkMode ? Colors.white54 : Colors.black12,
                        width: 2,
                      ),
              ),
              child: Icon(
                Icons.shield,
                color: _currentPage == 2
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

class _RegionalDistribution {
  const _RegionalDistribution({
    required this.totalUsers,
    required this.items,
  });

  final int totalUsers;
  final List<_RegionalDistributionItem> items;
}

class _RegionalDistributionItem {
  const _RegionalDistributionItem({
    required this.region,
    required this.userCount,
    required this.percentage,
  });

  final String region;
  final int userCount;
  final double percentage;
}
