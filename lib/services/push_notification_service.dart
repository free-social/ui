import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pushTokenPrefsKey = 'pushToken';
const _deviceIdPrefsKey = 'deviceId';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (error) {
    debugPrint('FCM background init failed: $error');
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _isInitialized = false;
  bool _isFirebaseAvailable = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;

    if (kIsWeb) {
      debugPrint('FCM initialization skipped on web');
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final token = await messaging.getToken();
      await _persistPushToken(token);

      messaging.onTokenRefresh.listen((token) async {
        await _persistPushToken(token);
      });

      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('FCM foreground message: ${jsonEncode(message.data)}');
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('FCM opened app: ${jsonEncode(message.data)}');
      });

      _isFirebaseAvailable = true;
    } catch (error) {
      debugPrint('FCM initialization failed: $error');
    }
  }

  Future<void> clearStoredPushToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pushTokenPrefsKey);
  }

  Future<String?> getStoredPushToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pushTokenPrefsKey);
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdPrefsKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }

    final deviceId = _generateDeviceId();
    await prefs.setString(_deviceIdPrefsKey, deviceId);
    return deviceId;
  }

  String get platformHeaderValue {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    return 'android';
  }

  String get deviceName {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isIOS) {
      return 'ios-device';
    }
    return 'android-device';
  }

  bool get isFirebaseAvailable => _isFirebaseAvailable;

  Future<void> _persistPushToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.trim().isEmpty) {
      await prefs.remove(_pushTokenPrefsKey);
      return;
    }

    await prefs.setString(_pushTokenPrefsKey, token.trim());
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
