import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_service.dart';
import '../models/user_model.dart';
import '../services/notification_preferences_service.dart';
import '../services/security_event_service.dart';
import '../theme_helpers.dart';
import '../widgets/go2rtc_live_view.dart';
import 'welcome_screen.dart';

const bool kUseEsp32CameraFeeds = true;

const String _kPrefHostIp = 'esp32_host_ip';

const String _kPrefTapoRelayIp = 'tapo_relay_ip';
const String _kPrefTapoRelayPort = 'tapo_relay_port';
const String _kPrefTapoStreamName = 'tapo_stream_name';
const String _kPrefTapoStreamName2 = 'tapo_stream_name2';
const String _kPrefTapoCameraIp = 'tapo_camera_ip';
const String _kPrefTapoCamera2Ip = 'tapo_camera2_ip';

// ESP32-CAM endpoints from CAM IP.txt.
// Overridable via --dart-define so the correct IP survives even when the
// browser's SharedPreferences/localStorage gets wiped (e.g. flutter run -d chrome
// uses a fresh temporary Chrome profile on every launch, resetting anything saved
// via the in-app "Set IP" dialog back to these defaults).
const String kEsp32HostIp = String.fromEnvironment('ESP32_HOST_IP', defaultValue: '192.168.1.100');
const String kEsp32Cam2Ip = String.fromEnvironment('ESP32_CAM2_IP', defaultValue: '192.168.1.101');
const String kEsp32SnapshotPath = '/snapshot';
const String kEsp32StreamPath = '/stream';
const String kEsp32SensorPath = '/sensor';

const List<Map<String, String>> kEsp32DeviceList = [
  {'ip': kEsp32HostIp, 'label': 'Host Camera'},
  {'ip': kEsp32Cam2Ip, 'label': 'Camera 2'},
];

// Tapo cams only speak RTSP; a go2rtc relay (fronted by scripts/cors_proxy.dart
// for CORS/Private-Network-Access) re-serves it as plain HTTP MJPEG/snapshot.
// The relay host is the PC running go2rtc/cors_proxy, while the Tapo camera source is 192.168.1.17.
const String kTapoDefaultRelayIp = String.fromEnvironment('TAPO_RELAY_IP', defaultValue: '192.168.1.13');
const String kTapoCameraIp = '192.168.1.17';
const String kTapoCamera2Ip = '192.168.1.18';
const String kTapoDefaultRelayPort = '8090';
const String kGo2rtcApiPort = '1984';
const String kTapoDefaultStreamName = 'tapo1';
const String kTapoDefaultStreamName2 = 'tapo2';
const String kGo2rtcSnapshotPath = '/api/frame.jpeg';
const String kGo2rtcStreamPath = '/webrtc.html';
// go2rtc transcodes the RTSP audio track to MP3 on the fly (requires ffmpeg, already configured).
const String kGo2rtcAudioPath = '/api/stream.mp3';

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

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _soundEnabled = false;
  bool _soundLoading = false;
  String _tapoRelayIp = kTapoDefaultRelayIp;
  String _tapoRelayPort = kTapoDefaultRelayPort;
  String _tapoStreamName = kTapoDefaultStreamName;

  String get _tapoAudioUrl =>
      'http://$_tapoRelayIp:$_tapoRelayPort$kGo2rtcAudioPath?src=$_tapoStreamName';

  @override
  void initState() {
    super.initState();
    _loadAudioConfig();
  }

  Future<void> _loadAudioConfig() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedTapoIp = prefs.getString(_kPrefTapoRelayIp);
    setState(() {
      _tapoRelayIp = savedTapoIp == kTapoCameraIp || savedTapoIp == null || savedTapoIp.trim().isEmpty
          ? kTapoDefaultRelayIp
          : savedTapoIp;
      _tapoRelayPort = prefs.getString(_kPrefTapoRelayPort) ?? kTapoDefaultRelayPort;
      _tapoStreamName = prefs.getString(_kPrefTapoStreamName) ?? kTapoDefaultStreamName;
    });
  }

  Future<void> _toggleSound() async {
    if (_soundLoading) return;

    if (_soundEnabled) {
      await _audioPlayer.stop();
      if (!mounted) return;
      setState(() => _soundEnabled = false);
      return;
    }

    setState(() => _soundLoading = true);
    try {
      await _audioPlayer.setUrl(_tapoAudioUrl);
      await _audioPlayer.play();
      if (!mounted) return;
      setState(() {
        _soundEnabled = true;
        _soundLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _soundEnabled = false;
        _soundLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start live audio. Check the camera relay connection.')),
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut(BuildContext context, AuthService authService) async {
    await authService.logout();
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
                      Row(
                        children: [
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
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.logout, color: Colors.redAccent),
                            onPressed: () => _handleSignOut(context, authService),
                          ),
                        ],
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
                  GestureDetector(
                    onTap: _toggleSound,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _soundEnabled ? accent : surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor),
                        boxShadow: _soundEnabled
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ]
                            : null,
                      ),
                      child: _soundLoading
                          ? SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            )
                          : Icon(
                              _soundEnabled ? Icons.volume_up : Icons.volume_off,
                              color: _soundEnabled ? const Color(0xFF0C100E) : (isDark ? Colors.white54 : Colors.black54),
                              size: 28,
                            ),
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
                    _soundEnabled ? 'SOUND ON' : 'SOUND',
                    style: GoogleFonts.inter(
                      color: _soundEnabled ? accent : context.mutedText,
                      fontWeight: _soundEnabled ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEsp32CameraSection(BuildContext context) {
    return const Esp32CameraSection();
  }

}

class Esp32CameraSection extends StatefulWidget {
  const Esp32CameraSection({super.key});

  @override
  State<Esp32CameraSection> createState() => _Esp32CameraSectionState();
}

class _Esp32CameraSectionState extends State<Esp32CameraSection> {
  String _hostIp = kEsp32HostIp;
  String _tapoRelayIp = kTapoDefaultRelayIp;
  String _tapoRelayPort = kTapoDefaultRelayPort;
  String _tapoStreamName = kTapoDefaultStreamName;
  String _tapoStreamName2 = kTapoDefaultStreamName2;
  String _tapoCameraIp = kTapoCameraIp;
  String _tapoCamera2Ip = kTapoCamera2Ip;

  String get _tapoSnapshotUrl => 'http://$_tapoRelayIp:$_tapoRelayPort$kGo2rtcSnapshotPath?src=$_tapoStreamName';
  String get _tapoStreamUrl => 'http://$_tapoRelayIp:$kGo2rtcApiPort$kGo2rtcStreamPath?src=$_tapoStreamName';

  // Back camera shares the same relay host/port, only the go2rtc stream name differs.
  String get _tapoSnapshotUrl2 => 'http://$_tapoRelayIp:$_tapoRelayPort$kGo2rtcSnapshotPath?src=$_tapoStreamName2';
  String get _tapoStreamUrl2 => 'http://$_tapoRelayIp:$kGo2rtcApiPort$kGo2rtcStreamPath?src=$_tapoStreamName2';

  @override
  void initState() {
    super.initState();
    _loadIpConfig();
  }

  Future<void> _loadIpConfig() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedTapoIp = prefs.getString(_kPrefTapoRelayIp);
    final effectiveTapoRelayIp = savedTapoIp == kTapoCameraIp || savedTapoIp == null || savedTapoIp.trim().isEmpty
        ? kTapoDefaultRelayIp
        : savedTapoIp;

    setState(() {
      _hostIp = prefs.getString(_kPrefHostIp) ?? kEsp32HostIp;
      _tapoRelayIp = effectiveTapoRelayIp;
      _tapoRelayPort = prefs.getString(_kPrefTapoRelayPort) ?? kTapoDefaultRelayPort;
      _tapoStreamName = prefs.getString(_kPrefTapoStreamName) ?? kTapoDefaultStreamName;
      _tapoStreamName2 = prefs.getString(_kPrefTapoStreamName2) ?? kTapoDefaultStreamName2;
      _tapoCameraIp = prefs.getString(_kPrefTapoCameraIp) ?? kTapoCameraIp;
      _tapoCamera2Ip = prefs.getString(_kPrefTapoCamera2Ip) ?? kTapoCamera2Ip;
    });
  }

  Future<void> _saveIpConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefHostIp, _hostIp);
    await prefs.setString(_kPrefTapoRelayIp, _tapoRelayIp);
    await prefs.setString(_kPrefTapoRelayPort, _tapoRelayPort);
    await prefs.setString(_kPrefTapoStreamName, _tapoStreamName);
    await prefs.setString(_kPrefTapoStreamName2, _tapoStreamName2);
    await prefs.setString(_kPrefTapoCameraIp, _tapoCameraIp);
    await prefs.setString(_kPrefTapoCamera2Ip, _tapoCamera2Ip);
  }

  bool _isValidIpv4(String value) {
    final parts = value.trim().split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  Future<void> _showIpConfigDialog() async {
    final tapoIpController = TextEditingController(text: _tapoRelayIp);
    final tapoPortController = TextEditingController(text: _tapoRelayPort);
    final tapoStreamController = TextEditingController(text: _tapoStreamName);
    final tapoStreamController2 = TextEditingController(text: _tapoStreamName2);
    final tapoCameraIpController = TextEditingController(text: _tapoCameraIp);
    final tapoCamera2IpController = TextEditingController(text: _tapoCamera2Ip);

    void resetControllers() {
      tapoIpController.text = _tapoRelayIp;
      tapoPortController.text = _tapoRelayPort;
      tapoStreamController.text = _tapoStreamName;
      tapoStreamController2.text = _tapoStreamName2;
      tapoCameraIpController.text = _tapoCameraIp;
      tapoCamera2IpController.text = _tapoCamera2Ip;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        var isEditing = false;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Camera Configuration'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Camera Devices (Tapo via relay)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    TextField(
                      controller: tapoIpController,
                      enabled: isEditing,
                      decoration: const InputDecoration(labelText: 'Relay PC IP (camera is 192.168.1.17)'),
                    ),
                    TextField(
                      controller: tapoPortController,
                      enabled: isEditing,
                      decoration: const InputDecoration(labelText: 'CORS proxy port (default 8090)'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: tapoStreamController,
                      enabled: isEditing,
                      decoration: const InputDecoration(labelText: 'Front stream name (go2rtc.yaml key)'),
                    ),
                    TextField(
                      controller: tapoCameraIpController,
                      enabled: isEditing,
                      decoration: const InputDecoration(labelText: 'Front Camera IP Address'),
                    ),
                    TextField(
                      controller: tapoStreamController2,
                      enabled: isEditing,
                      decoration: const InputDecoration(labelText: 'Back stream name (go2rtc.yaml key)'),
                    ),
                    TextField(
                      controller: tapoCamera2IpController,
                      enabled: isEditing,
                      decoration: const InputDecoration(labelText: 'Back Camera IP Address'),
                    ),
                  ],
                ),
              ),
              actions: isEditing
                  ? [
                      TextButton(
                        onPressed: () {
                          resetControllers();
                          setLocalState(() => isEditing = false);
                        },
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final nextTapoIp = tapoIpController.text.trim();
                          final nextTapoPort = tapoPortController.text.trim();
                          final nextTapoStream = tapoStreamController.text.trim();
                          final nextTapoStream2 = tapoStreamController2.text.trim();
                          final nextTapoCameraIp = tapoCameraIpController.text.trim();
                          final nextTapoCamera2Ip = tapoCamera2IpController.text.trim();
                          if (nextTapoIp.isEmpty ||
                              nextTapoPort.isEmpty ||
                              nextTapoStream.isEmpty ||
                              nextTapoStream2.isEmpty ||
                              nextTapoCameraIp.isEmpty ||
                              nextTapoCamera2Ip.isEmpty ||
                              !_isValidIpv4(nextTapoIp) ||
                              !_isValidIpv4(nextTapoCameraIp) ||
                              !_isValidIpv4(nextTapoCamera2Ip)) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill in the relay details and valid IPv4 addresses.')),
                            );
                            return;
                          }

                          if (!mounted) return;
                          setState(() {
                            _tapoRelayIp = nextTapoIp;
                            _tapoRelayPort = nextTapoPort;
                            _tapoStreamName = nextTapoStream;
                            _tapoStreamName2 = nextTapoStream2;
                            _tapoCameraIp = nextTapoCameraIp;
                            _tapoCamera2Ip = nextTapoCamera2Ip;
                          });
                          await _saveIpConfig();

                          setLocalState(() => isEditing = false);
                        },
                        child: const Text('Save'),
                      ),
                    ]
                  : [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                      FilledButton(
                        onPressed: () => setLocalState(() => isEditing = true),
                        child: const Text('Edit'),
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
    final surface = context.secondarySurface;
    final borderColor = context.canvasBorder;
    final accent = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'CAMERAS LIVE',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: accent,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _showIpConfigDialog,
              icon: const Icon(Icons.settings_ethernet, size: 16),
              label: const Text('Set IP'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Cameras via relay: $_tapoRelayIp:$_tapoRelayPort',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: context.mutedText,
          ),
        ),
        const SizedBox(height: 16),
        Esp32SensorBar(hostIp: _hostIp),
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
            children: [
              CameraFeedCard(
                ip: _tapoRelayIp,
                label: 'Front Camera',
                snapshotUrlOverride: _tapoSnapshotUrl,
                streamUrlOverride: _tapoStreamUrl,
              ),
              CameraFeedCard(
                ip: _tapoRelayIp,
                label: 'Back Camera',
                snapshotUrlOverride: _tapoSnapshotUrl2,
                streamUrlOverride: _tapoStreamUrl2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CameraFeedCard extends StatefulWidget {
  final String ip;
  final String label;
  final bool configured;
  final String? snapshotUrlOverride;
  final String? streamUrlOverride;

  const CameraFeedCard({
    super.key,
    required this.ip,
    required this.label,
    this.configured = true,
    this.snapshotUrlOverride,
    this.streamUrlOverride,
  });

  @override
  State<CameraFeedCard> createState() => _CameraFeedCardState();
}

class _CameraFeedCardState extends State<CameraFeedCard> {
  Uint8List? _frame;
  Timer? _timer;
  bool _connected = false;
  bool _loading = true;
  bool _useSnapshot = false;
  bool _isFetchingFrame = false;
  int _refreshNonce = 0;

  String get _snapshotUrl => widget.snapshotUrlOverride ?? 'http://${widget.ip}$kEsp32SnapshotPath';
  String get _streamUrl => widget.streamUrlOverride ?? 'http://${widget.ip}$kEsp32StreamPath';

  @override
  void initState() {
    super.initState();
    if (!widget.configured) {
      _loading = false;
      return;
    }
    if (kIsWeb) {
      _connected = true;
      _loading = false;
    }
    _useSnapshot = false;
  }

  void _startSnapshotPolling() {
    _timer?.cancel();
    _fetchFrame();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _fetchFrame());
  }

  void _refreshFeed() {
    if (!widget.configured || !mounted) return;

    setState(() {
      _frame = null;
      _connected = kIsWeb;
      _loading = !kIsWeb;
      _refreshNonce++;
    });

    if (_useSnapshot) {
      _startSnapshotPolling();
    }
  }

  Future<void> _fetchFrame() async {
    if (_isFetchingFrame) return;
    _isFetchingFrame = true;
    try {
      final snapshotUri = Uri.parse(_snapshotUrl).replace(
        queryParameters: {
          ...Uri.parse(_snapshotUrl).queryParameters,
          'cb': DateTime.now().microsecondsSinceEpoch.toString(),
        },
      );
      final response = await http.get(snapshotUri).timeout(const Duration(seconds: 8));
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
    _isFetchingFrame = false;
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
                if (widget.configured)
                  Text(
                    widget.ip,
                    style: const TextStyle(fontSize: 10, color: Colors.white60),
                  ),
                if (widget.configured)
                  IconButton(
                    onPressed: _refreshFeed,
                    tooltip: 'Refresh camera feed',
                    icon: const Icon(Icons.refresh, size: 17, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
              ],
            ),
          ),
          Expanded(
            child: !widget.configured
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 32),
                        SizedBox(height: 8),
                        Text('Not configured', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  )
                : _useSnapshot
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
                : kIsWeb
                ? Go2rtcLiveView(
                    key: ValueKey('$_streamUrl-$_refreshNonce'),
                  url: _streamUrl,
                  )
                : Image.network(
                  key: ValueKey('$_streamUrl-$_refreshNonce'),
                  '$_streamUrl?cb=$_refreshNonce',
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
  // When true, shows "Condition: Good/Bad" (admin view) instead of the raw distance reading.
  final bool showConditionLabel;

  const Esp32SensorBar({super.key, required this.hostIp, this.showConditionLabel = false});

  @override
  State<Esp32SensorBar> createState() => _Esp32SensorBarState();
}

class _Esp32SensorBarState extends State<Esp32SensorBar> {
  final SecurityEventService _securityEventService = SecurityEventService();
  final NotificationPreferencesService _notificationPreferencesService = NotificationPreferencesService();
  bool _motionSensorEnabled = true;
  bool _pushAlertsEnabled = true;
  int _motionDetectionCounter = 0;
  double? _lastDistanceCm;
  DateTime? _lastAlertCreatedAt;
  Timer? _timer;
  bool _liveBlink = false;

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
          _motionSensorEnabled = motionEnabled;
          _pushAlertsEnabled = pushEnabled;
          _lastDistanceCm = dist.toDouble();
          _liveBlink = !_liveBlink;
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
        _motionSensorEnabled = motionEnabled;
        _pushAlertsEnabled = pushEnabled;
        _liveBlink = false;
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
    final isActive = _motionSensorEnabled;
    final motionLabel = isActive ? 'Movement: Sensor ON' : 'Movement: Sensor OFF';
    final motionColor = isActive ? Colors.greenAccent : Colors.white70;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade900,
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
                Row(
                  children: [
                    const Text(
                      'Motion Detector',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 6),
                      AnimatedOpacity(
                        opacity: _liveBlink ? 1.0 : 0.25,
                        duration: const Duration(milliseconds: 400),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.greenAccent,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
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
              color: isActive ? Colors.green.shade700 : Colors.red.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isActive ? 'ACTIVE' : 'INACTIVE',
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
