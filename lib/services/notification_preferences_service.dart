import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferencesService {
  static const String _pushAlertsKey = 'pref_push_alerts_enabled';
  static const String _motionAlertsKey = 'pref_motion_alerts_enabled';

  Future<bool> getPushAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pushAlertsKey) ?? true;
  }

  Future<bool> getMotionAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_motionAlertsKey) ?? true;
  }

  Future<void> setPushAlertsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushAlertsKey, value);
  }

  Future<void> setMotionAlertsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_motionAlertsKey, value);
  }
}