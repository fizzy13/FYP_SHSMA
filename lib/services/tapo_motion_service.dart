import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/camera_screen.dart';
import 'notification_preferences_service.dart';
import 'security_event_service.dart';

class TapoMotionService {
  static final TapoMotionService instance = TapoMotionService._internal();

  TapoMotionService._internal();

  final SecurityEventService _securityEventService = SecurityEventService();
  final NotificationPreferencesService _notificationPreferencesService =
      NotificationPreferencesService();

  Timer? _pollingTimer;
  Uint8List? _lastFrameBytesFront;
  Uint8List? _lastFrameBytesBack;
  DateTime? _lastAlertTimeFront;
  DateTime? _lastAlertTimeBack;
  bool _isProcessingFront = false;
  bool _isProcessingBack = false;

  static const Duration _pollInterval = Duration(milliseconds: 1800);
  static const Duration _alertCooldown = Duration(seconds: 12);
  static const double _motionThresholdRatio = 0.08;

  bool get isRunning => _pollingTimer != null && _pollingTimer!.isActive;

  void startMonitoring() {
    if (isRunning) return;
    _pollingTimer = Timer.periodic(_pollInterval, (_) {
      _checkCameraMotion(
        streamKey: 'tapo_stream_name',
        defaultStreamName: kTapoDefaultStreamName,
        cameraLabel: 'Front Camera',
        cameraIp: kTapoCameraIp,
        isBackCamera: false,
      );
      _checkCameraMotion(
        streamKey: 'tapo_stream_name2',
        defaultStreamName: kTapoDefaultStreamName2,
        cameraLabel: 'Back Camera',
        cameraIp: kTapoCamera2Ip,
        isBackCamera: true,
      );
    });
    debugPrint(
      '[TapoMotionService] Live motion detector started for Front & Back Cameras.',
    );
  }

  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _lastFrameBytesFront = null;
    _lastFrameBytesBack = null;
    debugPrint('[TapoMotionService] Live motion detector stopped.');
  }

  Future<void> _checkCameraMotion({
    required String streamKey,
    required String defaultStreamName,
    required String cameraLabel,
    required String cameraIp,
    required bool isBackCamera,
  }) async {
    if (isBackCamera ? _isProcessingBack : _isProcessingFront) return;
    if (isBackCamera) {
      _isProcessingBack = true;
    } else {
      _isProcessingFront = true;
    }

    try {
      final motionEnabled = await _notificationPreferencesService
          .getMotionAlertsEnabled();
      if (!motionEnabled) return;

      final prefs = await SharedPreferences.getInstance();
      final savedRelayIp = prefs.getString('tapo_relay_ip');
      final relayIp =
          savedRelayIp == kTapoCameraIp ||
              savedRelayIp == null ||
              savedRelayIp.trim().isEmpty
          ? kTapoDefaultRelayIp
          : savedRelayIp;
      final relayPort =
          prefs.getString('tapo_relay_port') ?? kTapoDefaultRelayPort;
      final streamName = prefs.getString(streamKey) ?? defaultStreamName;

      final snapshotUri = Uri.parse(
        'http://$relayIp:$relayPort$kGo2rtcSnapshotPath?src=$streamName',
      );

      final response = await http
          .get(snapshotUri)
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final currentBytes = response.bodyBytes;
        final lastBytes = isBackCamera
            ? _lastFrameBytesBack
            : _lastFrameBytesFront;
        final lastAlert = isBackCamera
            ? _lastAlertTimeBack
            : _lastAlertTimeFront;

        if (lastBytes != null && lastBytes.isNotEmpty) {
          final diffRatio = _calculateFrameDifference(lastBytes, currentBytes);

          if (diffRatio >= _motionThresholdRatio) {
            final now = DateTime.now();
            if (lastAlert == null ||
                now.difference(lastAlert) > _alertCooldown) {
              if (isBackCamera) {
                _lastAlertTimeBack = now;
              } else {
                _lastAlertTimeFront = now;
              }

              final formattedTime =
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

              await _securityEventService.createMotionAlertAndLog(
                cameraLabel: cameraLabel,
                message:
                    '"$cameraLabel": Motion was detected at $formattedTime.',
                sourceIp: cameraIp,
              );

              debugPrint(
                '[TapoMotionService] Motion detected on $cameraLabel! (diff: ${(diffRatio * 100).toStringAsFixed(1)}%) Alert triggered.',
              );
            }
          }
        }

        if (isBackCamera) {
          _lastFrameBytesBack = currentBytes;
        } else {
          _lastFrameBytesFront = currentBytes;
        }
      }
    } catch (_) {
      // Ignore transient network errors
    } finally {
      if (isBackCamera) {
        _isProcessingBack = false;
      } else {
        _isProcessingFront = false;
      }
    }
  }

  double _calculateFrameDifference(Uint8List frameA, Uint8List frameB) {
    if (frameA.isEmpty || frameB.isEmpty) return 0.0;

    final minLen = frameA.length < frameB.length
        ? frameA.length
        : frameB.length;
    if (minLen < 500) return 0.0;

    int totalDiff = 0;
    int samples = 0;
    const step = 20;

    for (int i = 100; i < minLen - 100; i += step) {
      totalDiff += (frameA[i] - frameB[i]).abs();
      samples++;
    }

    if (samples == 0) return 0.0;

    return (totalDiff / samples) / 255.0;
  }
}
