import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../auth_service.dart';
import '../models/user_model.dart';
import '../services/notification_preferences_service.dart';
import '../services/security_event_service.dart';
import '../theme_helpers.dart';

const bool kUseEsp32CameraFeeds = true;

// ESP32-CAM endpoints from CAM IP.txt
const String kEsp32HostIp = '192.168.1.100';
const String kEsp32SnapshotPath = '/snapshot';
const String kEsp32StreamPath = '/stream';
const String kEsp32SensorPath = '/sensor';

const List<Map<String, String>> kEsp32DeviceList = [
  {'ip': kEsp32HostIp, 'label': 'Host Camera'},
  {'ip': '192.168.1.101', 'label': 'Camera 2'},
  {'ip': '192.168.1.102', 'label': 'Camera 3'},
  {'ip': '192.168.1.103', 'label': 'Camera 4'},
];

const double kUltrasonicMotionThresholdCm = 120.0;
const Duration kUltrasonicAlertCooldown = Duration(seconds: 15);

String _displayNameFromUser(User? user) {
  final fullName = user?.displayName;
  if (fullName != null && fullName.trim().isNotEmpty) {
    return fullName.trim();
  }

  final email = user?.email?.trim();
  if (email != null && email.isNotEmpty) {
    return email.contains('@') ? email.split('@').first : email;
  }

  return 'User';
}

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = AuthService();
    final isDark = theme.brightness == Brightness.dark;
    final bg = context.appBackground;
    final surface = context.secondarySurface;
    final borderColor = context.canvasBorder;
    final accent = theme.colorScheme.primary;
    final overlaySurface = isDark ? Colors.black45 : Colors.white.withAlpha(82);
    final imageErrorBg = isDark ? Colors.black54 : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              StreamBuilder<UserInfo?>(
                stream: authService.currentUser?.uid != null
                    ? authService.getUserInfoStreamByUid(authService.currentUser!.uid)
                    : Stream<UserInfo?>.value(null),
                builder: (context, snapshot) {
                  final currentUser = authService.currentUser;
                    final headerName = snapshot.data?.fullName.isNotEmpty == true
                      ? snapshot.data!.fullName
                      : _displayNameFromUser(currentUser);

                  return Row(
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
                            headerName,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: accent,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor),
                        ),
                        child: Icon(
                          Icons.notifications,
                          color: accent,
                          size: 20,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              if (kUseEsp32CameraFeeds)
                _buildEsp32CameraSection(context)
              else
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('devices').snapshots(),
                  builder: (context, snapshot) {
                    final placeholderUrl = 'https://placehold.co/800x450?text=Camera+Stream';
                    String streamUrl = placeholderUrl;
                    String deviceLabel = 'CAM-01 • FRONT PORCH';

                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      final firstDevice = snapshot.data!.docs.first.data();
                      streamUrl = firstDevice['stream_url'] as String? ?? placeholderUrl;
                      deviceLabel = firstDevice['device_name'] as String? ?? deviceLabel;
                    }

                    return Container(
                      height: 260,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.network(
                                streamUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: surface,
                                    child: const Center(child: CircularProgressIndicator()),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(color: imageErrorBg);
                                },
                              ),
                            ),
                          ),
                          Container(
                            width: 140,
                            height: 180,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: accent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0C100E),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PERSON DETECTED',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                      color: const Color(0xFF0C100E),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 60,
                            left: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: overlaySurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFD61F1F),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'LIVE • 4K',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: overlaySurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Text(
                                    deviceLabel,
                                    style: GoogleFonts.inter(
                                      color: context.mutedText,
                                      fontSize: 10,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            child: Column(
                              children: [
                                Text(
                                  'Safe and Working',
                                  style: GoogleFonts.inter(
                                    color: context.mutedText,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'CONFIDENCE:\n98.4%',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: overlaySurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.signal_cellular_4_bar,
                                    color: Color(0xFF4EEF9B),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'STABLE',
                                    style: GoogleFonts.inter(
                                      color: accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 40),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF0C100E),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 40),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(
                      Icons.volume_up,
                      color: isDark ? Colors.white54 : Colors.black54,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'CAPTURE      ',
                    style: GoogleFonts.inter(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 48),
                  Text(
                    'SOUND',
                    style: GoogleFonts.inter(
                      color: context.mutedText,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),
              Text(
                'NETWORK NODES',
                style: GoogleFonts.inter(
                  color: context.mutedText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 16),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('devices').snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  final cards = docs.take(4).map((device) {
                    final data = device.data();
                    return _buildNodeCard(
                      context,
                      data['device_name'] as String? ?? 'DEVICE NODE',
                      null,
                      isActive: (data['status']?.toString().toLowerCase() == 'online'),
                    );
                  }).toList();

                  while (cards.length < 4) {
                    cards.add(_buildNodeCard(context, 'OFFLINE NODE', null));
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 16),
                          Expanded(child: cards[1]),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: cards[2]),
                          const SizedBox(width: 16),
                          Expanded(child: cards[3]),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEsp32CameraSection(BuildContext context) {
    final theme = Theme.of(context);
    final surface = context.secondarySurface;
    final borderColor = context.canvasBorder;
    final accent = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            color: surface,
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
      ],
    );
  }

  Widget _buildNodeCard(
    BuildContext context,
    String title,
    String? imagePath, {
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = context.secondarySurface;
    final borderColor = context.canvasBorder;
    final accent = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? accent : borderColor,
          width: isActive ? 2 : 1,
        ),
        image: imagePath != null
            ? DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
                colorFilter: isActive
                    ? null
                    : ColorFilter.mode(
                        isDark ? Colors.black.withAlpha(128) : Colors.white.withAlpha(46),
                        BlendMode.darken,
                      ),
              )
            : null,
      ),
      child: Stack(
        children: [
          if (isActive)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ACTIVE',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0C100E),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isActive ? onSurface : context.mutedText,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.videocam,
                  color: isActive ? accent : context.mutedText,
                  size: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CameraFeedCard extends StatefulWidget {
  final String ip;
  final String label;

  const CameraFeedCard({super.key, required this.ip, required this.label});

  @override
  State<CameraFeedCard> createState() => _CameraFeedCardState();
}

class _CameraFeedCardState extends State<CameraFeedCard> {
  Uint8List? _frame;
  Timer? _timer;
  bool _connected = false;
  bool _loading = true;
  bool _useSnapshot = false;

  String get _snapshotUrl => 'http://${widget.ip}$kEsp32SnapshotPath';
  String get _streamUrl => 'http://${widget.ip}$kEsp32StreamPath';

  @override
  void initState() {
    super.initState();
    // On web builds the MJPEG stream often doesn't render correctly — use snapshot polling.
    if (kIsWeb) {
      _useSnapshot = true;
      _startSnapshotPolling();
    }
  }

  void _startSnapshotPolling() {
    _fetchFrame();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 600), (_) => _fetchFrame());
  }

  Future<void> _fetchFrame() async {
    try {
      final response = await http.get(Uri.parse(_snapshotUrl)).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _frame = response.bodyBytes;
          _connected = true;
          _loading = false;
        });
        return;
      }
    } catch (_) {
      // ignore and show disconnected state
    }

    if (mounted) {
      setState(() {
        _connected = false;
        _loading = false;
      });
    }
  }

  void _switchToSnapshotFallback() {
    if (!_useSnapshot) {
      setState(() => _useSnapshot = true);
      _startSnapshotPolling();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _connected ? Colors.blue : Colors.red.shade700,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: _connected ? Colors.blue.shade900 : Colors.red.shade900,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  _connected ? Icons.videocam : Icons.videocam_off,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  widget.ip,
                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                ),
              ],
            ),
          ),
          Expanded(
            child: _useSnapshot
                ? (_loading
                    ? const Center(child: CircularProgressIndicator())
                    : (_frame != null
                        ? Image.memory(
                            _frame!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            width: double.infinity,
                          )
                        : const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.signal_wifi_off, color: Colors.red, size: 32),
                                SizedBox(height: 4),
                                Text('No connection', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          )))
                : Image.network(
                    '$_streamUrl?cb=${DateTime.now().millisecondsSinceEpoch}',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        if (!_connected || _loading) {
                          setState(() {
                            _connected = true;
                            _loading = false;
                          });
                        }
                        return child;
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      // On stream errors, fallback to snapshot polling
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _switchToSnapshotFallback();
                      });
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.signal_wifi_off, color: Colors.red, size: 32),
                            SizedBox(height: 4),
                            Text('No connection', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class Esp32SensorBar extends StatefulWidget {
  final String hostIp;

  const Esp32SensorBar({super.key, required this.hostIp});

  @override
  State<Esp32SensorBar> createState() => _Esp32SensorBarState();
}

class _Esp32SensorBarState extends State<Esp32SensorBar> {
  final SecurityEventService _securityEventService = SecurityEventService();
  final NotificationPreferencesService _notificationPreferencesService = NotificationPreferencesService();
  String _distance = '--';
  String _status = 'Connecting...';
  bool _motionDetected = false;
  bool _motionSensorEnabled = true;
  bool _pushAlertsEnabled = true;
  int _motionDetectionCounter = 0;
  double? _lastDistanceCm;
  DateTime? _lastAlertCreatedAt;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
    _fetchSensor();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _fetchSensor());
  }

  Future<void> _loadNotificationPreferences() async {
    final motionEnabled = await _notificationPreferencesService.getMotionAlertsEnabled();
    final pushEnabled = await _notificationPreferencesService.getPushAlertsEnabled();
    if (!mounted) return;
    setState(() {
      _motionSensorEnabled = motionEnabled;
      _pushAlertsEnabled = pushEnabled;
    });
  }

  Future<void> _fetchSensor() async {
    final motionEnabled = await _notificationPreferencesService.getMotionAlertsEnabled();
    final pushEnabled = await _notificationPreferencesService.getPushAlertsEnabled();

    try {
      final response = await http
          .get(Uri.parse('http://${widget.hostIp}$kEsp32SensorPath'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final dist = data['distance_cm'] as num;
        final rawMotion = dist > 0 && dist < kUltrasonicMotionThresholdCm;
        final isMotion = motionEnabled && rawMotion;

        setState(() {
          _distance = dist < 0 ? 'Out of range' : '${dist.toStringAsFixed(1)} cm';
          _status = 'Connected';
          _motionDetected = isMotion;
          _motionSensorEnabled = motionEnabled;
          _pushAlertsEnabled = pushEnabled;
          _lastDistanceCm = dist.toDouble();
        });

        if (isMotion) {
          _motionDetectionCounter += 1;
        }

        if (isMotion && pushEnabled && _motionDetectionCounter >= 5) {
          _motionDetectionCounter = 0;
          await _createMotionAlert();
        }
        return;
      }
    } catch (_) {
      // ignore
    }

    if (mounted) {
      setState(() {
        _distance = '--';
        _status = 'Disconnected';
        _motionDetected = false;
        _motionSensorEnabled = motionEnabled;
        _pushAlertsEnabled = pushEnabled;
      });
    }
  }

  Future<void> _createMotionAlert() async {
    final now = DateTime.now();
    if (_lastAlertCreatedAt != null && now.difference(_lastAlertCreatedAt!) < kUltrasonicAlertCooldown) {
      return;
    }

    final cameraLabel = kEsp32DeviceList
            .firstWhere((device) => device['ip'] == widget.hostIp, orElse: () => {'label': 'Camera 1'})['label'] ??
        'Camera 1';
    final alertMessage = 'Alert, movement detected at $cameraLabel';

    try {
      await _securityEventService.createMotionAlertAndLog(
        cameraLabel: cameraLabel,
        message: alertMessage,
        sourceIp: widget.hostIp,
        distanceCm: _lastDistanceCm,
      );

      _lastAlertCreatedAt = now;

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Movement detected'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 12,
            16,
            0,
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Motion alert write blocked: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Motion detected, but Firebase rules blocked saving the alert.'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 12,
            16,
            0,
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _status == 'Connected';
    final motionLabel = !_motionSensorEnabled
        ? 'Sensor OFF'
        : (_motionDetected ? 'MOVEMENT DETECTED' : 'No motion');
    final motionColor = _motionDetected ? Colors.orangeAccent : Colors.white70;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isConnected ? Colors.blue.shade900 : Colors.red.shade900,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.sensors, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ultrasonic Sensor (Host)',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
                Text(
                  'Distance: $_distance',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  motionLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: motionColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isConnected ? Colors.green.shade700 : Colors.red.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _status,
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
