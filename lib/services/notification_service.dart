// lib/services/notification_service.dart
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:Ratedly/services/analytics_service.dart';
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

  Future<void> _logStep(String stepName, String notificationType,
      {String? targetUserId, String? status, String? additionalInfo}) async {
    try {
      await FirebaseFirestore.instance.collection('notification_logs').add({
            'timestamp': FieldValue.serverTimestamp(),
            'step': stepName,
            'notification_type': notificationType,
            'target_user_id': targetUserId ?? 'unknown',
            'status': status ?? 'in_progress',
            'additional_info': additionalInfo ?? '',
            'platform': 'ios',
          } as Map<String, Object?>);
    } catch (e) {
      print('🔥 Failed to log step: $e');
    }
  }

  int _getNotificationId() {
    return DateTime.now().millisecondsSinceEpoch % 2147483647;
  }

  Future<void> init() async {
    try {
      await _logStep('init_started', 'service');

      final NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: true,
        sound: true,
      );

      await _logStep('permission_received', 'service',
          status: 'success',
          additionalInfo: 'Status: ${settings.authorizationStatus.name}');

      AnalyticsService.logEvent(
        name: 'notification_permission',
        params: {
          'status': settings.authorizationStatus.name,
          'alert':
              '${settings.authorizationStatus == AuthorizationStatus.authorized}',
          'provisional':
              '${settings.authorizationStatus == AuthorizationStatus.provisional}',
        },
      );

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      _handleTokenRetrieval();

      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        await _logStep('token_refresh', 'service',
            additionalInfo: 'New token: ${newToken.substring(0, 6)}...');
        AnalyticsService.logFcmToken(newToken);
        await _saveTokenToFirestore(newToken);
      });

      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentSound: true,
      );

      await _notifications.initialize(
        InitializationSettings(iOS: initializationSettingsIOS),
        onDidReceiveNotificationResponse:
            (NotificationResponse response) async {
          if (response.payload != null) {
            try {
              final data = jsonDecode(response.payload!);
              await _logStep(
                  'notification_tapped', data['type']?.toString() ?? 'unknown',
                  status: 'success',
                  additionalInfo: 'Payload: ${response.payload}');

              AnalyticsService.logNotificationDisplay(
                type: data['type']?.toString() ?? 'local',
                source: 'tap',
              );
            } catch (e) {
              await _logStep('notification_tapped', 'unknown',
                  status: 'error', additionalInfo: 'Parse error: $e');

              AnalyticsService.logNotificationError(
                type: 'payload_parse',
                targetUserId: 'unknown',
                exception: e,
                stack: StackTrace.current,
              );
            }
          }
        },
      );

      await _configureNotificationChannels();
      _setupAuthListener();

      AnalyticsService.logEvent(
        name: 'notification_service_init',
        params: {'status': 'success'},
      );

      await _logStep('init_complete', 'service', status: 'success');
    } catch (e, st) {
      await _logStep('init_failed', 'service',
          status: 'error', additionalInfo: 'Error: ${e.toString()}');

      AnalyticsService.logNotificationError(
        type: 'initialization',
        targetUserId: 'system',
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: 'initialization',
        targetUserId: 'system',
        exception: e,
        stackTrace: st,
        additionalInfo: 'Failed to initialize notification service',
      );
    }
  }

  Future<void> _setupAuthListener() async {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _logStep('user_logged_in', 'service',
            targetUserId: user.uid, additionalInfo: 'User logged in');

        final token = await _firebaseMessaging.getToken();
        if (token != null) {
          await _saveTokenToFirestore(token);
        }
      } else {
        await _logStep('user_logged_out', 'service',
            additionalInfo: 'User logged out');
      }
    });
  }

  Future<void> _handleTokenRetrieval() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _logStep('token_received', 'service',
            status: 'success',
            additionalInfo: 'Token: ${token.substring(0, 6)}...');

        AnalyticsService.logFcmToken(token);
        await _saveTokenToFirestore(token);
      } else {
        await _logStep('token_received', 'service',
            status: 'failed', additionalInfo: 'Token is null');
      }
    } catch (e, st) {
      await _logStep('token_retrieval_failed', 'service',
          status: 'error', additionalInfo: 'Error: ${e.toString()}');

      AnalyticsService.logNotificationError(
        type: 'token_retrieval',
        targetUserId: 'system',
        exception: e,
        stack: st,
      );
    }
  }

  Future<void> _configureNotificationChannels() async {
    try {
      await _logStep('channel_config_start', 'service');

      final iOSPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      if (iOSPlugin != null) {
        final bool? result = await iOSPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

        await _logStep('ios_permission_result', 'service',
            status: result == true ? 'success' : 'failed',
            additionalInfo: 'Result: $result');
      } else {
        await _logStep('ios_permission_request', 'service',
            status: 'skipped', additionalInfo: 'iOS plugin not available');
      }

      AnalyticsService.logEvent(
        name: 'notification_categories',
        params: {'status': 'configured'},
      );

      await _logStep('channel_config_complete', 'service', status: 'success');
    } catch (e) {
      await _logStep('channel_config_failed', 'service',
          status: 'error', additionalInfo: 'Error: ${e.toString()}');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    User? user;
    try {
      await _logStep('token_save_start', 'service',
          additionalInfo: 'Token: ${token.substring(0, 6)}...');

      user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));

        await _logStep('token_save_success', 'service',
            targetUserId: user.uid,
            additionalInfo: 'Saved for user ${user.uid}');

        AnalyticsService.logEvent(
          name: 'fcm_token_saved',
          params: {
            'userId': user.uid,
            'token_snippet': token.substring(0, 6),
          },
        );
      } else {
        await _logStep('token_save_skipped', 'service',
            status: 'skipped', additionalInfo: 'No user logged in');
        await _storePendingToken(token);
      }
    } catch (e, st) {
      await _logStep('token_save_failed', 'service',
          status: 'error', additionalInfo: 'Error: ${e.toString()}');

      AnalyticsService.logNotificationError(
        type: 'token_save',
        targetUserId: 'system',
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: 'token_save',
        targetUserId: 'system',
        exception: e,
        stackTrace: st,
        additionalInfo: 'Failed to save token for user: ${user?.uid ?? "none"}',
      );
    }
  }

  Future<void> _storePendingToken(String token) async {
    try {
      await _logStep('pending_token_store', 'service',
          additionalInfo: 'Storing token for later association');

      await FirebaseFirestore.instance
          .collection('pending_tokens')
          .doc(token)
          .set(
              {
                'token': token,
                'createdAt': FieldValue.serverTimestamp(),
                'associated': false,
              } as Map<String, Object?>,
              SetOptions(merge: true));
    } catch (e, st) {
      await _logStep('pending_token_store_failed', 'service',
          status: 'error', additionalInfo: 'Error: ${e.toString()}');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final String? rawTargetUserId = message.data['targetUserId'];
    final String targetUserId = rawTargetUserId ?? 'unknown';

    final String notificationType = message.data['type'] ?? 'fcm';
    final String? messageId = message.messageId;

    try {
      await _logStep('foreground_message_received', notificationType,
          targetUserId: targetUserId,
          additionalInfo: 'Message ID: $messageId, '
              'Data: ${_truncateData(message.data, 200)}');

      AnalyticsService.logEvent(
        name: 'fcm_foreground',
        params: {
          'message_id': messageId ?? 'unknown',
          'sent_time': message.sentTime?.toIso8601String() ?? 'unknown',
          'data': message.data,
          'target_user_id': targetUserId,
        },
      );

      if (message.notification != null || message.data.isNotEmpty) {
        await _showNotification(
          title: message.notification?.title ?? '',
          body: message.notification?.body ?? '',
          data: message.data,
        );
      } else {
        await _logStep('foreground_no_notification', notificationType,
            targetUserId: targetUserId,
            additionalInfo: 'No notification payload');
      }
    } catch (e, st) {
      await _logStep('foreground_message_failed', notificationType,
          targetUserId: targetUserId,
          status: 'error',
          additionalInfo: 'Error: ${e.toString()}');

      AnalyticsService.logNotificationError(
        type: 'foreground_message',
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: 'foreground_message',
        targetUserId: targetUserId,
        exception: e,
        stackTrace: st,
        additionalInfo: '''
FCM Payload:
Title: ${message.notification?.title}
Body: ${message.notification?.body}
Data: ${message.data}''',
      );
    }
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    final String? rawTargetUserId = message.data['targetUserId'];
    final String targetUserId = rawTargetUserId ?? 'unknown';

    final String notificationType = message.data['type'] ?? 'fcm';
    final String? messageId = message.messageId;

    try {
      await Firebase.initializeApp();

      await FirebaseFirestore.instance.collection('notification_logs').add({
            'timestamp': FieldValue.serverTimestamp(),
            'step': 'background_message_received',
            'notification_type': notificationType,
            'target_user_id': targetUserId,
            'status': 'in_progress',
            'additional_info': 'Message ID: $messageId, '
                'Data: ${_truncateData(message.data, 200)}',
            'platform': 'ios',
          } as Map<String, Object?>);

      AnalyticsService.logEvent(
        name: 'fcm_background',
        params: {
          'message_id': messageId ?? 'unknown',
          'sent_time': message.sentTime?.toIso8601String() ?? 'unknown',
          'data': message.data,
          'target_user_id': targetUserId,
        },
      );

      if (message.notification != null || message.data.isNotEmpty) {
        await FirebaseFirestore.instance.collection('notification_logs').add({
              'timestamp': FieldValue.serverTimestamp(),
              'step': 'background_show_notification',
              'notification_type': notificationType,
              'target_user_id': targetUserId,
              'status': 'in_progress',
              'additional_info':
                  'Title: ${message.notification?.title ?? "No title"}',
              'platform': 'ios',
            } as Map<String, Object?>);

        final NotificationService service = NotificationService();
        await service._showNotification(
          title: message.notification?.title ?? '',
          body: message.notification?.body ?? '',
          data: message.data,
        );
      } else {
        await FirebaseFirestore.instance.collection('notification_logs').add({
              'timestamp': FieldValue.serverTimestamp(),
              'step': 'background_no_notification',
              'notification_type': notificationType,
              'target_user_id': targetUserId,
              'status': 'skipped',
              'additional_info': 'No notification payload',
              'platform': 'ios',
            } as Map<String, Object?>);
      }
    } catch (e, st) {
      await FirebaseFirestore.instance.collection('notification_logs').add({
            'timestamp': FieldValue.serverTimestamp(),
            'step': 'background_message_failed',
            'notification_type': notificationType,
            'target_user_id': targetUserId,
            'status': 'error',
            'additional_info': 'Error: ${e.toString()}',
            'platform': 'ios',
          } as Map<String, Object?>);

      AnalyticsService.logNotificationError(
        type: 'background_message',
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: 'background_message',
        targetUserId: targetUserId,
        exception: e,
        stackTrace: st,
        additionalInfo: '''
Background FCM Payload:
Title: ${message.notification?.title}
Body: ${message.notification?.body}
Data: ${message.data}''',
      );
    }
  }

  Future<void> _showNotification({
    required String? title,
    required String? body,
    required Map<String, dynamic> data,
  }) async {
    final String? rawTargetUserId = data['targetUserId'];
    final String targetUserId = rawTargetUserId ?? 'unknown';
    final String notificationType = data['type'] ?? 'unknown';

    try {
      await _logStep('show_notification_start', notificationType,
          targetUserId: targetUserId,
          additionalInfo: 'Title: ${title ?? "No title"}, '
              'Data: ${_truncateData(data, 200)}');

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        categoryIdentifier: 'ratedly_actions',
        threadIdentifier: 'ratedly_notifications',
      );

      final notificationId = _getNotificationId();
      final String finalTitle = title ?? data['title'] ?? 'New Activity';
      final String finalBody = body ?? data['body'] ?? 'You have new activity';

      await _notifications.show(
        notificationId,
        finalTitle,
        finalBody,
        const NotificationDetails(iOS: iosDetails),
        payload: jsonEncode(data),
      );

      await _logStep('notification_shown', notificationType,
          targetUserId: targetUserId,
          status: 'success',
          additionalInfo: 'ID: $notificationId, '
              'Type: $notificationType, '
              'Target: $targetUserId');

      // FIXED: Removed the undefined targetUserId parameter
      AnalyticsService.logNotificationDisplay(
        type: notificationType,
        source: 'server',
      );
    } catch (e, st) {
      await _logStep('notification_show_failed', notificationType,
          targetUserId: targetUserId,
          status: 'error',
          additionalInfo: 'Error: ${e.toString()}');

      AnalyticsService.logNotificationError(
        type: 'local_show',
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: 'local_show',
        targetUserId: targetUserId,
        exception: e,
        stackTrace: st,
        additionalInfo: '''
Notification Type: $notificationType
Title: ${title ?? 'N/A'}
Body: ${body ?? 'N/A'}
Payload: ${data.toString()}''',
      );
    }
  }

  static String _truncateData(Map<String, dynamic> data, int maxLength) {
    final dataStr = data.toString();
    return dataStr.length > maxLength
        ? dataStr.substring(0, maxLength) + '...'
        : dataStr;
  }

  Future<void> showTestNotification() async {
    const type = 'test';
    try {
      await _logStep('test_notification_start', type);

      AnalyticsService.logNotificationAttempt(
        type: type,
        targetUserId: 'test',
        trigger: 'manual',
      );

      await _notifications.show(
        _getNotificationId(),
        'Test Notification',
        'This is a test notification from Ratedly!',
        const NotificationDetails(iOS: DarwinNotificationDetails()),
        payload: jsonEncode({
          'type': type,
          'source': 'debug',
        }),
      );

      await _logStep('test_notification_shown', type, status: 'success');

      AnalyticsService.logNotificationDisplay(
        type: type,
        source: 'local',
      );
    } catch (e, st) {
      await _logStep('test_notification_failed', type,
          status: 'error', additionalInfo: 'Error: ${e.toString()}');

      AnalyticsService.logNotificationError(
        type: type,
        targetUserId: 'test',
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: type,
        targetUserId: 'test',
        exception: e,
        stackTrace: st,
        additionalInfo: 'Test notification failed',
      );
    }
  }

  // SERVER-TRIGGERED NOTIFICATION METHOD
  Future<void> triggerServerNotification({
    required String type,
    required String targetUserId,
    String? title,
    String? body,
    Map<String, dynamic>? customData,
  }) async {
    try {
      await _logStep('server_notification_trigger', type,
          targetUserId: targetUserId,
          additionalInfo: 'Triggering server notification');

      await FirebaseFirestore.instance.collection('notifications').add({
            'type': type,
            'targetUserId': targetUserId,
            'title': title ?? 'New Notification',
            'body': body ?? 'You have a new notification',
            'customData': customData ?? {},
            'createdAt': FieldValue.serverTimestamp(),
          } as Map<String, Object?>);

      await _logStep('server_notification_triggered', type,
          targetUserId: targetUserId, status: 'success');
    } catch (e, st) {
      // FIXED: Added comma after the second positional parameter
      await _logStep('server_notification_trigger_failed', type,
          targetUserId: targetUserId,
          status: 'error',
          additionalInfo: 'Error: ${e.toString()}');

      AnalyticsService.logNotificationError(
        type: 'server_trigger',
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: 'server_trigger',
        targetUserId: targetUserId,
        exception: e,
        stackTrace: st,
        additionalInfo: 'Failed to trigger server notification',
      );
    }
  }
}
