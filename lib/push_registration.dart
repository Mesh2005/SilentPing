import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enable only in a build paired with the deployed deliverPing function.
const androidPushDeployed = bool.fromEnvironment('ENABLE_ANDROID_PUSH');
bool get androidPushAvailable =>
    androidPushDeployed &&
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.android;

class PushRegistration {
  PushRegistration(this.uid, {required this.onError});
  final String uid;
  final void Function() onError;
  StreamSubscription<String>? _refresh;
  bool _disposed = false;
  bool _acceptTokens = false;
  Future<void> _pendingSave = Future<void>.value();
  String? _deviceId;
  String get _preference => 'push-enabled-$uid';
  bool get _signedIn =>
      !_disposed && FirebaseAuth.instance.currentUser?.uid == uid;

  Future<bool> restore() async {
    if (!androidPushAvailable) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_preference) != true) return false;
    return enable(requestPermission: false);
  }

  Future<bool> enable({bool requestPermission = true}) async {
    if (!androidPushAvailable || !_signedIn) return false;
    final messaging = FirebaseMessaging.instance;
    final settings = requestPermission
        ? await messaging.requestPermission(
            alert: true,
            badge: false,
            sound: false,
          )
        : await messaging.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      await disable();
      return false;
    }
    await const MethodChannel(
      'silent_ping/haptics',
    ).invokeMethod<void>('prepareNotifications');
    await messaging.setAutoInitEnabled(true);
    _acceptTokens = true;
    // Admin sendEachForMulticast accepts registration tokens, not the FID
    // returned by the newer register/onRegistered API.
    // ignore: deprecated_member_use
    final token = await messaging.getToken();
    if (token == null || !_signedIn) {
      throw StateError('Could not register this phone. Please retry.');
    }
    await _queueSave(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preference, true);
    await _refresh?.cancel();
    // Keep token refresh consistent with the server's registration-token API.
    // ignore: deprecated_member_use
    _refresh = messaging.onTokenRefresh.listen(
      (token) async {
        try {
          await _queueSave(token);
        } catch (_) {
          if (!_disposed) onError();
        }
      },
      onError: (_) {
        if (!_disposed) onError();
      },
    );
    return true;
  }

  Future<void> _queueSave(String token) {
    final task = _pendingSave
        .catchError((Object _) {})
        .then((_) => _save(token));
    _pendingSave = task;
    return task;
  }

  Future<void> _save(String token) async {
    if (!_signedIn || !_acceptTokens) return;
    final prefs = await SharedPreferences.getInstance();
    // One stable document per installation prevents old refresh tokens from
    // leaving extra subscriptions behind when this phone changes accounts.
    var id = prefs.getString('push-installation-id');
    if (id == null) {
      final random = Random.secure();
      id = List.generate(
        32,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await prefs.setString('push-installation-id', id);
    }
    _deviceId = id;
    // Remember the document before writing so cleanup can revoke a queued write
    // even if the server acknowledgement times out.
    await prefs.setString('push-device-$uid', id);
    final devices = FirebaseFirestore.instance.collection('pushDevices');
    await devices
        .doc(id)
        .set({
          'ownerUid': uid,
          'token': token,
          'platform': 'android',
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 15));
  }

  Future<void> disable() async {
    if (!androidPushAvailable) return;
    _acceptTokens = false;
    await _refresh?.cancel();
    _refresh = null;
    try {
      await _pendingSave;
    } catch (_) {
      /* Still remove any completed registration. */
    }
    final prefs = await SharedPreferences.getInstance();
    final id = _deviceId ?? prefs.getString('push-device-$uid');
    // Revoke cloud routing before allowing sign-out; do not leave a shared phone
    // subscribed to the previous account if a network error prevents cleanup.
    if (id != null) {
      await FirebaseFirestore.instance
          .collection('pushDevices')
          .doc(id)
          .delete()
          .timeout(const Duration(seconds: 15));
    }
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
    if (id != null || prefs.getBool(_preference) == true) {
      // Revoke the legacy registration token used by Admin multicast sends.
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken().timeout(
        const Duration(seconds: 15),
      );
    }
    await prefs.remove(_preference);
    await prefs.remove('push-device-$uid');
    _deviceId = null;
  }

  void dispose() {
    _disposed = true;
    _refresh?.cancel();
  }
}
