import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String kAlertsCollectionName = 'Alerts';
const String kActivityLogsCollectionName = 'activity_logs';

class SecurityEventService {
  SecurityEventService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<String?> createMotionAlertAndLog({
    required String cameraLabel,
    required String message,
    required String sourceIp,
    double? distanceCm,
  }) async {
    final now = DateTime.now();
    final userId = _auth.currentUser?.uid;

    try {
      final alertRef = await _firestore.collection(kAlertsCollectionName).add({
        'type': 'Motion Alert',
        'alerts': 'Motion Alert',
        'message': message,
        'location': cameraLabel,
        'status': 'LIVE',
        'userId': userId,
        'sourceIp': sourceIp,
        'distanceCm': distanceCm,
        'timestamp': FieldValue.serverTimestamp(),
        'clientTimestamp': Timestamp.fromDate(now),
      });

      await _firestore.collection(kActivityLogsCollectionName).add({
        'userId': userId,
        'deviceId': sourceIp,
        'activityType': 'MOTION_DETECTED',
        'description': message,
        'alertId': alertRef.id,
        'source': 'ESP32_ULTRASONIC',
        'timestamp': FieldValue.serverTimestamp(),
        'clientTimestamp': Timestamp.fromDate(now),
      });

      return alertRef.id;
    } catch (_) {
      rethrow;
    }
  }
}
