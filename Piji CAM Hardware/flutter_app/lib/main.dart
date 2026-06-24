import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ===== CHANGE THESE to match your ESP32-CAM IPs =====
// Check the IP in Arduino IDE Serial Monitor after upload
const String HOST_IP  = '192.168.1.100'; // Host camera — fixed IP set in esp32cam_host.ino
const String CAM2_IP  = '192.168.1.101'; // Camera 2  — fixed IP set in esp32cam_basic.ino
const String CAM3_IP  = '192.168.1.102'; // Camera 3  — fixed IP set in esp32cam_basic.ino
const String CAM4_IP  = '192.168.1.103'; // Camera 4  — fixed IP set in esp32cam_basic.ino
// =====================================================

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32-CAM Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('ESP32-CAM Monitor'),
        backgroundColor: Colors.blue.shade900,
      ),
      body: Column(
        children: [
          // Ultrasonic sensor reading from host camera
          const SensorBar(hostIp: HOST_IP),

          // 2x2 camera grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(8),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: const [
                CameraView(ip: HOST_IP,  label: 'Camera 1 (Host)'),
                CameraView(ip: CAM2_IP,  label: 'Camera 2'),
                CameraView(ip: CAM3_IP,  label: 'Camera 3'),
                CameraView(ip: CAM4_IP,  label: 'Camera 4'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Camera View Widget ----------
// Polls /snapshot every 200ms and displays the JPEG image.
class CameraView extends StatefulWidget {
  final String ip;
  final String label;

  const CameraView({super.key, required this.ip, required this.label});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  Uint8List? _frame;
  Timer? _timer;
  bool _connected = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchFrame(); // fetch immediately
    // Then poll every 200ms (~5 fps)
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) => _fetchFrame());
  }

  Future<void> _fetchFrame() async {
    try {
      final response = await http
          .get(Uri.parse('http://${widget.ip}/snapshot'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _frame = response.bodyBytes;
          _connected = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _connected = false;
          _loading = false;
        });
      }
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
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _connected ? Colors.blue : Colors.red.shade700,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Label bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: _connected ? Colors.blue.shade900 : Colors.red.shade900,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(
              children: [
                Icon(
                  _connected ? Icons.videocam : Icons.videocam_off,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  widget.ip,
                  style: TextStyle(fontSize: 10, color: Colors.white60),
                ),
              ],
            ),
          ),

          // Camera image
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _frame != null
                    ? Image.memory(
                        _frame!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true, // prevents flicker between frames
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
                      ),
          ),
        ],
      ),
    );
  }
}

// ---------- Sensor Bar Widget ----------
// Polls /sensor from the host camera every 1 second.
class SensorBar extends StatefulWidget {
  final String hostIp;

  const SensorBar({super.key, required this.hostIp});

  @override
  State<SensorBar> createState() => _SensorBarState();
}

class _SensorBarState extends State<SensorBar> {
  String _distance = '--';
  String _status = 'Connecting...';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchSensor();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _fetchSensor());
  }

  Future<void> _fetchSensor() async {
    try {
      final response = await http
          .get(Uri.parse('http://${widget.hostIp}/sensor'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final dist = data['distance_cm'] as num;
        setState(() {
          _distance = dist < 0 ? 'Out of range' : '${dist.toStringAsFixed(1)} cm';
          _status = 'Connected';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _distance = '--';
          _status = 'Disconnected';
        });
      }
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isConnected ? Colors.blue.shade900 : Colors.red.shade900,
      child: Row(
        children: [
          const Icon(Icons.sensors, color: Colors.white),
          const SizedBox(width: 8),
          Column(
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
            ],
          ),
          const Spacer(),
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
