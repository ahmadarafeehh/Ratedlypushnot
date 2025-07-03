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
      final logData = {
        'timestamp': FieldValue.serverTimestamp(),
        'step': stepName,
        'notification_type': notificationType,
        'target_user_id': targetUserId ?? 'unknown',
        'status': status ?? 'in_progress',
        'additional_info': additionalInfo ?? '',
        'platform': 'ios',
      };

      await FirebaseFirestore.instance.collection('notification_logs').add(logData);
      print('📝 [LOG] $stepName - $notificationType - ${additionalInfo ?? ''}');
    } catch (e) {
      print('🔥 FAILED TO LOG STEP: $e');
    }
  }

  int _getNotificationId() {
    return DateTime.now().millisecondsSinceEpoch % 2147483647;
  }

  Future<void> init() async {
    try {
      await _logStep('init_started', 'service', additionalInfo: 'Initializing notification service');

      print('🔔 Requesting notification permissions...');
      final NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true, announcement: false, badge: true, carPlay: false,
        criticalAlert: true, provisional: true, sound: true,
      );

      await _logStep('permission_received', 'service',
          status: 'success',
          additionalInfo: 'Status: ${settings.authorizationStatus.name}');
      print('✅ Notification permission: ${settings.authorizationStatus.name}');

      AnalyticsService.logEvent(
        name: 'notification_permission',
        params: {'status': settings.authorizationStatus.name},
      );

      // Set presentation options
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );
      print('🎛️ Set foreground presentation options');

      // Listeners
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      print('👂 Set up message listeners');

      // Token handling
      await _handleTokenRetrieval();
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        await _logStep('token_refresh', 'service',
            additionalInfo: 'New token: ${newToken.substring(0, 6)}...');
        AnalyticsService.logFcmToken(newToken);
        await _saveTokenToFirestore(newToken);
      });

      // Initialize local notifications
      final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentSound: true,
      );

      await _notifications.initialize(
        InitializationSettings(iOS: initializationSettingsIOS),
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          if (response.payload != null) {
            try {
              print('👆 Notification tapped with payload: ${response.payload}');
              final data = jsonDecode(response.payload!);
              await _logStep('notification_tapped', data['type']?.toString() ?? 'unknown',
                  status: 'success',
                  additionalInfo: 'Payload: ${response.payload}');

              AnalyticsService.logNotificationDisplay(
                type: data['type']?.toString() ?? 'local',
                source: 'tap',
              );
            } catch (e) {
              print('❌ Notification tap error: $e');
              await _logStep('notification_tapped', 'unknown',
                  status: 'error', additionalInfo: 'Parse error: $e');
            }
          }
        },
      );
      print('🔔 Local notifications initialized');

      // Additional setup
      await _configureNotificationChannels();
      _setupAuthListener();

      AnalyticsService.logEvent(
        name: 'notification_service_init',
        params: {'status': 'success'},
      );

      await _logStep('init_complete', 'service', status: 'success');
      print('✅ Notification service initialized successfully');
    } catch (e, st) {
      print('💥 INIT ERROR: $e\n$st');
      await _logStep('init_failed', 'service',
          status: 'error', additionalInfo: 'Error: ${e.toString()}');

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
    print('👤 Setting up auth state listener');
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        print('👤 User logged in: ${user.uid}');
        await _logStep('user_logged_in', 'service',
            targetUserId: user.uid, additionalInfo: 'User logged in');

        final token = await _firebaseMessaging.getToken();
        if (token != null) {
          await _saveTokenToFirestore(token);
        }
      } else {
        print('👤 User logged out');
        await _logStep('user_logged_out', 'service',
            additionalInfo: 'User logged out');
      }
    });
  }

  Future<void> _handleTokenRetrieval() async {
    try {
      print('🔑 Retrieving FCM token...');
      final token = await _firebaseMessaging.getToken();
      
      if (token != null) {
        print('✅ FCM token received: ${token.substring(0, 6)}...');
        await _logStep('token_received', 'service',
            status: 'success',
            additionalInfo: 'Token: ${token.substring(0, 6)}...');

        AnalyticsService.logFcmToken(token);
        await _saveTokenToFirestore(token);
      } else {
        print('⚠️ FCM token is null!');
        await _logStep('token_received', 'service',
            status: 'failed', additionalInfo: 'Token is null');
      }
    } catch (e, st) {
      print('💥 Token retrieval error: $e\n$st');
      await _logStep('token_retrieval_failed', 'service',
          status: 'error', additionalInfo: 'Error: ${e.toString()}');
    }
  }

  Future<void> _configureNotificationChannels() async {
    try {
      print('⚙️ Configuring notification channels...');
      await _logStep('channel_config_start', 'service');

      final iOSPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      if (iOSPlugin != null) {
        print('📱 Requesting iOS permissions...');
        final bool? result = await iOSPlugin.requestPermissions(
          alert: true, badge: true, sound: true,
        );

        await _logStep('ios_permission_result', 'service',
            status: result == true ? 'success' : 'failed',
            additionalInfo: 'Result: $result');
        print('📱 iOS permission result: $result');
      } else {
        print('📱 iOS plugin not available');
        await _logStep('ios_permission_request', 'service',
            status: 'skipped', additionalInfo: 'iOS plugin not available');
      }

      AnalyticsService.logEvent(
        name: 'notification_categories',
        params: {'status': 'configured'},
      );

      await _logStep('channel_config_complete', 'service', status: 'success');
      print('✅ Notification channels configured');
    } catch (e) {
      print('💥 Channel config error: $e');
      await _logStep('channel_config_failed', 'service',
          status: 'error', additionalInfo: 'Error: ${e.toString()}');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    User? user;
    try {
      print('💾 Saving token to Firestore...');
      await _logStep('token_save_start', 'service',
          additionalInfo: 'Token: ${token.substring(0, 6)}...');

      user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('👤 Saving token for user: ${user.uid}');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));

        await _logStep('token_save_success', 'service',
            targetUserId: user.uid,
            additionalInfo: 'Saved for user ${user.uid}');

        AnalyticsService.logEvent(
          name: 'fcm_token_saved',
          params: {'userId': user.uid},
        );
      } else {
        print('👤 No user logged in, storing pending token');
        await _logStep('token_save_skipped', 'service',
            status: 'skipped', additionalInfo: 'No user logged in');
        await _storePendingToken(token);
      }
    } catch (e, st) {
      print('💥 Token save error: $e\n$st');
      await _logStep('token_save_failed', 'service',
          status: 'error', additionalInfo: 'Error: ${e.toString()}');
    }
  }

  Future<void> _storePendingToken(String token) async {
    try {
      print('⏳ Storing pending token: ${token.substring(0, 6)}...');
      await _logStep('pending_token_store', 'service',
          additionalInfo: 'Storing token for later association');

      await FirebaseFirestore.instance
          .collection('pending_tokens')
          .doc(token)
          .set({
            'token': token,
            'createdAt': FieldValue.serverTimestamp(),
            'associated': false,
          }, SetOptions(merge: true));
    } catch (e, st) {
      print('💥 Pending token error: $e\n$st');
      await _logStep('pending_token_store_failed', 'service',
          status: 'error', additionalInfo: 'Error: ${e.toString()}');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final String? rawTargetUserId = message.data['targetUserId'];
    final String targetUserId = rawTargetUserId ?? 'unknown';
    final String notificationType = message.data['type'] ?? 'fcm';
    final String? messageId = message.messageId;

    print('📬 Received foreground message: $messageId');
    print('📦 Message data: ${message.data}');
    print('🔔 Notification: ${message.notification}');

    try {
      await _logStep('foreground_message_received', notificationType,
          targetUserId: targetUserId,
          additionalInfo: 'Message ID: $messageId, Data: ${_truncateData(message.data, 200)}');

      AnalyticsService.logEvent(
        name: 'fcm_foreground',
        params: {'message_id': messageId ?? 'unknown'},
      );

      // Extract title/body from data payload
      final title = message.data['title'] ?? message.notification?.title ?? '';
      final body = message.data['body'] ?? message.notification?.body ?? '';
      
      print('📝 Extracted title: "$title"');
      print('📝 Extracted body: "$body"');

      if (title.isNotEmpty || body.isNotEmpty) {
        await _showNotification(
          title: title,
          body: body,
          data: message.data,
        );
      } else {
        print('⚠️ No notification payload in foreground message');
        await _logStep('foreground_no_notification', notificationType,
            targetUserId: targetUserId,
            additionalInfo: 'No notification payload');
      }
    } catch (e, st) {
      print('💥 Foreground message error: $e\n$st');
      await _logStep('foreground_message_failed', notificationType,
          targetUserId: targetUserId,
          status: 'error',
          additionalInfo: 'Error: ${e.toString()}');
    }
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    final String? rawTargetUserId = message.data['targetUserId'];
    final String targetUserId = rawTargetUserId ?? 'unknown';
    final String notificationType = message.data['type'] ?? 'fcm';
    final String? messageId = message.messageId;

    print('📬 Received background message: $messageId');
    print('📦 Message data: ${message.data}');
    print('🔔 Notification: ${message.notification}');

    try {
      await Firebase.initializeApp();
      print('🔥 Firebase initialized for background message');

      await FirebaseFirestore.instance.collection('notification_logs').add({
            'timestamp': FieldValue.serverTimestamp(),
            'step': 'background_message_received',
            'notification_type': notificationType,
            'target_user_id': targetUserId,
            'status': 'in_progress',
            'additional_info': 'Message ID: $messageId, Data: ${_truncateData(message.data, 200)}',
            'platform': 'ios',
          });

      AnalyticsService.logEvent(
        name: 'fcm_background',
        params: {'message_id': messageId ?? 'unknown'},
      );

      // Extract title/body from data payload
      final title = message.data['title'] ?? message.notification?.title ?? '';
      final body = message.data['body'] ?? message.notification?.body ?? '';
      
      print('📝 Extracted title: "$title"');
      print('📝 Extracted body: "$body"');

      if (title.isNotEmpty || body.isNotEmpty) {
        print('🔄 Processing background notification');
        await FirebaseFirestore.instance.collection('notification_logs').add({
              'timestamp': FieldValue.serverTimestamp(),
              'step': 'background_show_notification',
              'notification_type': notificationType,
              'target_user_id': targetUserId,
              'status': 'in_progress',
              'additional_info': 'Title: ${title.isNotEmpty ? title : "No title"}',
              'platform': 'ios',
            });

        final NotificationService service = NotificationService();
        await service._showNotification(
          title: title,
          body: body,
          data: message.data,
        );
      } else {
        print('⚠️ No notification payload in background message');
        await FirebaseFirestore.instance.collection('notification_logs').add({
              'timestamp': FieldValue.serverTimestamp(),
              'step': 'background_no_notification',
              'notification_type': notificationType,
              'target_user_id': targetUserId,
              'status': 'skipped',
              'additional_info': 'No notification payload',
              'platform': 'ios',
            });
      }
    } catch (e, st) {
      print('💥 Background message error: $e\n$st');
      await FirebaseFirestore.instance.collection('notification_logs').add({
            'timestamp': FieldValue.serverTimestamp(),
            'step': 'background_message_failed',
            'notification_type': notificationType,
            'target_user_id': targetUserId,
            'status': 'error',
            'additional_info': 'Error: ${e.toString()}',
            'platform': 'ios',
          });
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

    print('💫 Preparing to show notification: $notificationType');
    print('📝 Title: "$title"');
    print('📝 Body: "$body"');
    print('📦 Payload data: $data');

    try {
      await _logStep('show_notification_start', notificationType,
          targetUserId: targetUserId,
          additionalInfo: 'Title: ${title ?? "No title"}, Data: ${_truncateData(data, 200)}');

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

      print('🆔 Notification ID: $notificationId');
      print('📝 Final title: "$finalTitle"');
      print('📝 Final body: "$finalBody"');

      print('🚀 Showing notification...');
      await _notifications.show(
        notificationId,
        finalTitle,
        finalBody,
        const NotificationDetails(iOS: iosDetails),
        payload: jsonEncode(data),
      );

      print('✅ Notification displayed successfully');
      await _logStep('notification_shown', notificationType,
          targetUserId: targetUserId,
          status: 'success',
          additionalInfo: 'ID: $notificationId, Type: $notificationType, Target: $targetUserId');

      AnalyticsService.logNotificationDisplay(
        type: notificationType,
        source: 'server',
      );
    } catch (e, st) {
      print('💥 Notification show error: $e\n$st');
      await _logStep('notification_show_failed', notificationType,
          targetUserId: targetUserId,
          status: 'error',
          additionalInfo: 'Error: ${e.toString()}');
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
      print('🧪 Starting test notification...');
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

      print('✅ Test notification shown');
      await _logStep('test_notification_shown', type, status: 'success');

      AnalyticsService.logNotificationDisplay(
        type: type,
        source: 'local',
      );
    } catch (e, st) {
      print('💥 Test notification error: $e\n$st');
      await _logStep('test_notification_failed', type,
          status: 'error', additionalInfo: 'Error: ${e.toString()}');
    }
  }

  Future<void> triggerServerNotification({
    required String type,
    required String targetUserId,
    String? title,
    String? body,
    Map<String, dynamic>? customData,
  }) async {
    try {
      print('🚀 Triggering server notification: $type');
      await _logStep('server_notification_trigger', type,
          targetUserId: targetUserId,
          additionalInfo: 'Triggering server notification');

      final notificationData = {
        'type': type,
        'targetUserId': targetUserId,
        'title': title ?? 'New Notification',
        'body': body ?? 'You have a new notification',
        'customData': customData ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      };

      print('📝 Notification data: $notificationData');
      await FirebaseFirestore.instance.collection('notifications').add(notificationData);

      print('✅ Server notification triggered');
      await _logStep('server_notification_triggered', type,
          targetUserId: targetUserId, status: 'success');
    } catch (e, st) {
      print('💥 Server notification error: $e\n$st');
      await _logStep('server_notification_trigger_failed', type,
          targetUserId: targetUserId,
          status: 'error',
          additionalInfo: 'Error: ${e.toString()}');
    }
  }
}
