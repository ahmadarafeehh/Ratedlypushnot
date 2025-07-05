// lib/services/notification_service.dart
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Ratedly/services/error_log_service.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  int _getNotificationId() {
    return DateTime.now().millisecondsSinceEpoch % 2147483647;
  }

  Future<void> init() async {
    try {
      // Request iOS notification permissions
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Configure foreground presentation options
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Set up message listeners
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // Handle existing token and refresh
      await _handleTokenRetrieval();
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        await _saveTokenToFirestore(newToken);
      });

      // Initialize local notifications plugin
      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentSound: true,
      );
      await _notifications.initialize(
        InitializationSettings(iOS: iosSettings),
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          if (response.payload != null) {
            try {
              jsonDecode(response.payload!);
              // Handle tapped notification payload if needed
            } catch (e) {
              ErrorLogService.logNotificationError(
                type: 'tap_parse',
                targetUserId: 'unknown',
                exception: e,
                stackTrace: StackTrace.current,
                additionalInfo: 'Failed to parse notification payload',
              );
            }
          }
        },
      );

      // Configure notification channels and auth listener
      await _configureNotificationChannels();
      _setupAuthListener();
    } catch (e, st) {
      ErrorLogService.logNotificationError(
        type: 'initialization',
        targetUserId: 'system',
        exception: e,
        stackTrace: st,
        additionalInfo: 'Initialization failed',
      );
    }
  }

  Future<void> _setupAuthListener() async {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        final token = await _firebaseMessaging.getToken();
        if (token != null) {
          await _saveTokenToFirestore(token);
        }
      }
    });
  }

  Future<void> _handleTokenRetrieval() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e, st) {
      ErrorLogService.logNotificationError(
        type: 'token_retrieval',
        targetUserId: 'system',
        exception: e,
        stackTrace: st,
        additionalInfo: 'Token retrieval failed',
      );
    }
  }

  Future<void> _configureNotificationChannels() async {
    try {
      final iOSPlugin = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iOSPlugin != null) {
        await iOSPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e, st) {
      ErrorLogService.logNotificationError(
        type: 'channel_config',
        targetUserId: 'system',
        exception: e,
        stackTrace: st,
        additionalInfo: 'Channel configuration failed',
      );
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance
            .collection('pending_tokens')
            .doc(token)
            .set({
          'token': token,
          'createdAt': FieldValue.serverTimestamp(),
          'associated': false,
        }, SetOptions(merge: true));
      }
    } catch (e, st) {
      ErrorLogService.logNotificationError(
        type: 'token_save',
        targetUserId: 'system',
        exception: e,
        stackTrace: st,
        additionalInfo: 'Token save failed',
      );
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final title = data['title'] ?? message.notification?.title;
    final body = data['body'] ?? message.notification?.body;
    if (title != null || body != null) {
      await _showNotification(title: title, body: body, data: data);
    }
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    try {
      await Firebase.initializeApp();
      final data = message.data;
      final title = data['title'] ?? message.notification?.title;
      final body = data['body'] ?? message.notification?.body;
      if (title != null || body != null) {
        final service = NotificationService();
        await service._showNotification(title: title, body: body, data: data);
      }
    } catch (e, st) {
      ErrorLogService.logNotificationError(
        type: 'background_message',
        targetUserId: 'system',
        exception: e,
        stackTrace: st,
        additionalInfo: 'Background handling failed',
      );
    }
  }

  Future<void> _showNotification({
    required String? title,
    required String? body,
    required Map<String, dynamic> data,
  }) async {
    final id = _getNotificationId();
    final t = title ?? 'New Activity';
    final b = body ?? 'You have new activity';
    const details = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      categoryIdentifier: 'ratedly_actions',
      threadIdentifier: 'ratedly_notifications',
    );
    await _notifications.show(
      id,
      t,
      b,
      const NotificationDetails(iOS: details),
      payload: jsonEncode(data),
    );
  }

  Future<void> showTestNotification() async {
    await _notifications.show(
      _getNotificationId(),
      'Test Notification',
      'This is a test notification from Ratedly!',
      const NotificationDetails(iOS: DarwinNotificationDetails()),
      payload: jsonEncode({'type': 'test', 'source': 'debug'}),
    );
  }

  Future<void> triggerServerNotification({
    required String type,
    required String targetUserId,
    String? title,
    String? body,
    Map<String, dynamic>? customData,
  }) async {
    try {
      final notificationData = {
        'type': type,
        'targetUserId': targetUserId,
        'title': title ?? 'New Notification',
        'body': body ?? 'You have a new notification',
        'customData': customData ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notificationData);
    } catch (e, st) {
      ErrorLogService.logNotificationError(
        type: 'server_notification',
        targetUserId: targetUserId,
        exception: e,
        stackTrace: st,
        additionalInfo: 'Server trigger failed',
      );
    }
  }
}
