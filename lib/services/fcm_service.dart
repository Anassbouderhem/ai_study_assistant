import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'package:flutter/foundation.dart';

// Top-level background handler required by firebase_messaging
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService().init();
  try {
    final data = message.notification;
    if (data != null) {
      await NotificationService().showNotification(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: data.title ?? 'Notification',
        body: data.body ?? '',
      );
    }
  } catch (_) {}
}

class FcmService {
  FcmService._internal();
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    // Avoid initializing FCM fully on web to prevent startup hangs in Chrome.
    if (kIsWeb) return;
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permissions (iOS)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification != null) {
        await NotificationService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          title: notification.title ?? 'Notification',
          body: notification.body ?? '',
        );
      }
    });

    // When the app is opened from a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // handle navigation if required
    });

    // Get and save token
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }

    // Handle token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      await _saveTokenToFirestore(newToken);
    });
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final db = FirebaseFirestore.instance;
        await db.collection('users').doc(user.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
    } catch (_) {}
  }
}
