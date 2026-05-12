import 'package:shared_preferences/shared_preferences.dart';

/// Whether blood-request (and similar) pushes may be surfaced on this device.
/// Mirrors "logged in with token synced": [setActive](true) only after the
/// server has a token; [setActive](false) on logout and when there is no user.
///
/// Used by the FCM **background isolate**, which cannot rely on [FirebaseAuth].
class PushSessionGate {
  PushSessionGate._();

  static const _key = 'bloodbank_push_session_active';

  static Future<void> setActive(bool active) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, active);
  }

  static Future<bool> isActive() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_key) ?? false;
  }
}
