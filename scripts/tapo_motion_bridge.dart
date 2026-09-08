// Standalone Dart server bridge for Tapo Motion Detection & Firebase Firestore logging.
//
// Usage:
//   dart run scripts/tapo_motion_bridge.dart --user-id="<ALI_USER_ID>"
//
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String firebaseProjectId = 'shsma-db2b4';
const String firestoreRestUrl =
    'https://firestore.googleapis.com/v1/projects/$firebaseProjectId/databases/(default)/documents/Alerts';

Future<void> sendMotionAlertToFirestore({
  required String cameraLabel,
  required String message,
  required String cameraIp,
  String? userId,
}) async {
  final now = DateTime.now().toUtc();
  final isoTime = now.toIso8601String();

  final Map<String, dynamic> fields = {
    'type': {'stringValue': 'Motion Alert'},
    'alerts': {'stringValue': 'Motion Alert'},
    'message': {'stringValue': message},
    'location': {'stringValue': cameraLabel},
    'status': {'stringValue': 'LIVE'},
    'sourceIp': {'stringValue': cameraIp},
    'clientTimestamp': {'timestampValue': isoTime},
    'timestamp': {'timestampValue': isoTime},
  };

  if (userId != null && userId.isNotEmpty) {
    fields['userId'] = {'stringValue': userId};
  }

  try {
    final response = await http.post(
      Uri.parse(firestoreRestUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fields': fields}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      stdout.writeln(
        '[${DateTime.now().toIso8601String()}] Tapo Motion alert successfully stored in Firestore!',
      );
    } else {
      stderr.writeln(
        'Failed to store alert in Firestore: ${response.statusCode} - ${response.body}',
      );
    }
  } catch (e) {
    stderr.writeln('Error sending alert to Firestore: $e');
  }
}

void main(List<String> args) async {
  String? userId;
  for (final arg in args) {
    if (arg.startsWith('--user-id=')) {
      userId = arg.split('=')[1];
    }
  }

  stdout.writeln('====================================================');
  stdout.writeln('  Tapo Motion Listener Bridge (Firebase Firestore)');
  stdout.writeln('  Firebase Project: $firebaseProjectId');
  if (userId != null) {
    stdout.writeln('  User UID: $userId');
  }
  stdout.writeln('====================================================');

  // Trigger test ping to verify connection
  final now = DateTime.now();
  final formattedTime =
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

  await sendMotionAlertToFirestore(
    cameraLabel: 'Front Camera',
    message: '"Front Camera": Motion was detected at $formattedTime.',
    cameraIp: '192.168.0.11',
    userId: userId,
  );
}
