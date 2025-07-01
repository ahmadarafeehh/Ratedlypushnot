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

  // Helper to log detailed steps
  Future<void> _logStep(String stepName, String notificationType,
      {String? targetUserId, String? status, String? additionalInfo}) async {
    try {
      await FirebaseFirestore.instance.collection('notification_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'step': stepName,
        'notification_type': notificationType,
        'target_user_id': targetUserId,
        'status': status ?? 'in_progress',
        'additional_info': additionalInfo,
        'platform': 'ios',
      });
    } catch (e) {
      print('🔥 Failed to log step: $e');
    }
  }

  // iOS-safe notification ID generator
  int _getNotificationId() {
    return DateTime.now().millisecondsSinceEpoch % 2147483647;
  }

  Future<void> init() async {
    try {
      await _logStep('init_started', 'service');

      // 1. Request notification permissions
      await _logStep('permission_request', 'service',
          additionalInfo: 'Requesting permissions');

      final NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true, // Enable critical alerts
        provisional: true, // Allow provisional notifications
        sound: true,
      );

      // Log permission status
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

      // 2. Configure foreground presentation
      await _logStep('foreground_config', 'service');
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Set up FCM message handlers
      await _logStep('handlers_setup', 'service');
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // 4. Get and save FCM token
      await _logStep('token_retrieval', 'service');
      _firebaseMessaging.getToken().then((token) async {
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
      });

      // Handle token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        await _logStep('token_refresh', 'service',
            additionalInfo: 'New token: ${newToken.substring(0, 6)}...');
        AnalyticsService.logFcmToken(newToken);
        await _saveTokenToFirestore(newToken);
      });

      // 5. Initialize local notifications
      await _logStep('local_init_start', 'service');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentSound: true,          // Handle local notification tap
      
      );

      await _notifications.initialize(
        const InitializationSettings(iOS: initializationSettingsIOS),
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
      await _logStep('local_init_complete', 'service', status: 'success');

      // 6. Configure notification categories
      await _logStep('channel_config', 'service');
      await _configureNotificationChannels();

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

  Future<void> _configureNotificationChannels() async {
    try {
      await _logStep('channel_config_start', 'service');

      final iOSPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      if (iOSPlugin != null) {
        await _logStep('ios_permission_request', 'service');
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
            .update({'fcmToken': token});

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

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    String? targetUserId = message.data['targetUserId'] ?? 'unknown';

    try {
      await _logStep(
          'foreground_message_received', message.data['type'] ?? 'fcm',
targetUserId: targetUserId ?? 'unknown_user',
          additionalInfo: 'Message ID: ${message.messageId}');

      AnalyticsService.logEvent(
        name: 'fcm_foreground',
        params: {
          'message_id': message.messageId ?? 'unknown',
          'sent_time': message.sentTime?.toIso8601String() ?? 'unknown',
          'data': message.data,
        },
      );

      if (message.notification != null) {
        await _logStep(
            'foreground_show_notification', message.data['type'] ?? 'fcm',
targetUserId: targetUserId ?? 'unknown_user',
            additionalInfo: 'Title: ${message.notification!.title}');

        await _showNotification(
          title: message.notification!.title,
          body: message.notification!.body,
          data: message.data,
        );
      } else {
        await _logStep('foreground_no_notification', 'fcm',
targetUserId: targetUserId ?? 'unknown_user',
            additionalInfo: 'No notification payload');
      }
    } catch (e, st) {
      await _logStep('foreground_message_failed', 'fcm',
targetUserId: targetUserId ?? 'unknown_user',
          status: 'error',
          additionalInfo: 'Error: ${e.toString()}');

      AnalyticsService.logNotificationError(
        type: 'foreground_message',
targetUserId: targetUserId ?? 'unknown_user',
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: 'foreground_message',
targetUserId: targetUserId ?? 'unknown_user',
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
    String? targetUserId = message.data['targetUserId'] ?? 'unknown';

    try {
      await Firebase.initializeApp();

      // Logging through static method requires different approach
      await FirebaseFirestore.instance.collection('notification_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'step': 'background_message_received',
        'notification_type': message.data['type'] ?? 'fcm',
        'target_user_id': targetUserId,
        'status': 'in_progress',
        'additional_info': 'Message ID: ${message.messageId}',
        'platform': 'ios',
      });

      AnalyticsService.logEvent(
        name: 'fcm_background',
        params: {
          'message_id': message.messageId ?? 'unknown',
          'sent_time': message.sentTime?.toIso8601String() ?? 'unknown',
          'data': message.data,
        },
      );

      if (message.notification != null) {
        await FirebaseFirestore.instance.collection('notification_logs').add({
          'timestamp': FieldValue.serverTimestamp(),
          'step': 'background_show_notification',
          'notification_type': message.data['type'] ?? 'fcm',
          'target_user_id': targetUserId,
          'status': 'in_progress',
          'additional_info': 'Title: ${message.notification!.title}',
          'platform': 'ios',
        });

        final NotificationService service = NotificationService();
        await service._showNotification(
          title: message.notification!.title,
          body: message.notification!.body,
          data: message.data,
        );
      } else {
        await FirebaseFirestore.instance.collection('notification_logs').add({
          'timestamp': FieldValue.serverTimestamp(),
          'step': 'background_no_notification',
          'notification_type': 'fcm',
          'target_user_id': targetUserId,
          'status': 'skipped',
          'additional_info': 'No notification payload',
          'platform': 'ios',
        });
      }
    } catch (e, st) {
      await FirebaseFirestore.instance.collection('notification_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'step': 'background_message_failed',
        'notification_type': 'fcm',
        'target_user_id': targetUserId,
        'status': 'error',
        'additional_info': 'Error: ${e.toString()}',
        'platform': 'ios',
      });

      AnalyticsService.logNotificationError(
        type: 'background_message',
targetUserId: targetUserId ?? 'unknown_user',
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: 'background_message',
targetUserId: targetUserId ?? 'unknown_user',
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
    final String notificationType = data['type'] ?? 'unknown';
    final String targetUserId = data['targetUserId'] ?? 'unknown';

    try {
      await _logStep('show_notification_start', notificationType,
          targetUserId: targetUserId, additionalInfo: 'Title: $title');

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        categoryIdentifier: 'ratedly_actions',
        threadIdentifier: 'ratedly_notifications',
      );

      final notificationId = _getNotificationId();
      await _logStep('notification_show', notificationType,
          targetUserId: targetUserId,
          additionalInfo: 'ID: $notificationId, Title: $title');

      await _notifications.show(
        notificationId,
        title ?? 'New Activity',
        body ?? 'You have new activity in Ratedly',
        const NotificationDetails(iOS: iosDetails),
        payload: jsonEncode(data),
      );

      await _logStep('notification_shown', notificationType,
          targetUserId: targetUserId,
          status: 'success',
          additionalInfo: 'ID: $notificationId');

      AnalyticsService.logNotificationDisplay(
        type: notificationType,
        source: 'foreground',
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

  Future<void> showMessageNotification({
    required String senderId,
    required String senderUsername,
    required String message,
    required String chatId,
    required String targetUserId,
  }) async {
    const type = 'message';
    try {
      await _logStep('message_notification_start', type,
          targetUserId: targetUserId,
          additionalInfo: 'Sender: $senderUsername');

      AnalyticsService.logNotificationAttempt(
        type: type,
        targetUserId: targetUserId,
        trigger: 'app',
      );

      final truncatedMessage =
          message.length > 50 ? '${message.substring(0, 47)}...' : message;

      await _notifications.show(
        _getNotificationId(),
        'Message from $senderUsername',
        truncatedMessage,
        const NotificationDetails(
            iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        )),
        payload: jsonEncode({
          'type': type,
          'senderId': senderId,
          'chatId': chatId,
          'targetUserId': targetUserId,
        }),
      );

      await _logStep('message_notification_shown', type,
          targetUserId: targetUserId, status: 'success');

      AnalyticsService.logNotificationDisplay(
        type: type,
        source: 'local',
      );
    } catch (e, st) {
      await _logStep('message_notification_failed', type,
          targetUserId: targetUserId,
          status: 'error',
          additionalInfo: 'Error: ${e.toString()}');

      AnalyticsService.logNotificationError(
        type: type,
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: type,
        targetUserId: targetUserId,
        exception: e,
        stackTrace: st,
        additionalInfo: 'Sender: $senderId ($senderUsername)\n'
            'Message: ${message.length > 100 ? message.substring(0, 100) + '...' : message}',
      );
    }
  }

  Future<void> showFollowNotification({
    required String followerId,
    required String followerUsername,
    required String targetUserId,
  }) async {
    const type = 'follow';
    try {
      await _logStep('follow_notification_start', type,
          targetUserId: targetUserId,
          additionalInfo: 'Follower: $followerUsername');

      AnalyticsService.logNotificationAttempt(
        type: type,
        targetUserId: targetUserId,
        trigger: 'app',
      );

      await _notifications.show(
        _getNotificationId(),
        'New Follower',
        '$followerUsername started following you',
        const NotificationDetails(iOS: DarwinNotificationDetails()),
        payload: jsonEncode({
          'type': type,
          'followerId': followerId,
          'targetUserId': targetUserId,
        }),
      );

      await _logStep('follow_notification_shown', type,
          targetUserId: targetUserId, status: 'success');

      AnalyticsService.logNotificationDisplay(
        type: type,
        source: 'local',
      );
    } catch (e, st) {
      await _logStep('follow_notification_failed', type,
          targetUserId: targetUserId,
          status: 'error',
          additionalInfo: 'Error: ${e.toString()}');

      AnalyticsService.logNotificationError(
        type: type,
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: type,
        targetUserId: targetUserId,
        exception: e,
        stackTrace: st,
        additionalInfo: 'Follower: $followerId ($followerUsername)',
      );
    }
  }

  Future<void> showFollowRequestNotification({
    required String requesterId,
    required String requesterUsername,
    required String targetUserId,
  }) async {
    const type = 'follow_request';
    try {
      await _logStep('follow_request_start', type,
          targetUserId: targetUserId,
          additionalInfo: 'Requester: $requesterUsername');

      AnalyticsService.logNotificationAttempt(
        type: type,
        targetUserId: targetUserId,
        trigger: 'app',
      );

      await _notifications.show(
        _getNotificationId(),
        'Follow Request',
        '$requesterUsername wants to follow you',
        const NotificationDetails(
            iOS: DarwinNotificationDetails(
          categoryIdentifier: 'ratedly_actions',
        )),
        payload: jsonEncode({
          'type': type,
          'requesterId': requesterId,
          'targetUserId': targetUserId,
        }),
      );

      await _logStep('follow_request_shown', type,
          targetUserId: targetUserId, status: 'success');

      AnalyticsService.logNotificationDisplay(
        type: type,
        source: 'local',
      );
    } catch (e, st) {
      await _logStep('follow_request_failed', type,
          targetUserId: targetUserId,
          status: 'error',
          additionalInfo: 'Error: ${e.toString()}');

      AnalyticsService.logNotificationError(
        type: type,
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: type,
        targetUserId: targetUserId,
        exception: e,
        stackTrace: st,
        additionalInfo: 'Requester: $requesterId ($requesterUsername)',
      );
    }
  }

  Future<void> showPostRatingNotification({
    required String raterId,
    required String raterUsername,
    required double rating,
    required String targetUserId,
  }) async {
    const type = 'rating';
    try {
      await _logStep('rating_notification_start', type,
          targetUserId: targetUserId,
          additionalInfo: 'Rater: $raterUsername, Rating: $rating');

      AnalyticsService.logNotificationAttempt(
        type: type,
        targetUserId: targetUserId,
        trigger: 'app',
      );

      await _notifications.show(
        _getNotificationId(),
        'New Rating',
        '$raterUsername rated your post: $rating',
        const NotificationDetails(iOS: DarwinNotificationDetails()),
        payload: jsonEncode({
          'type': type,
          'raterId': raterId,
          'targetUserId': targetUserId,
        }),
      );

      await _logStep('rating_notification_shown', type,
          targetUserId: targetUserId, status: 'success');

      AnalyticsService.logNotificationDisplay(
        type: type,
        source: 'local',
      );
    } catch (e, st) {
      await _logStep('rating_notification_failed', type,
          targetUserId: targetUserId,
          status: 'error',
          additionalInfo: 'Error: ${e.toString()}');

      AnalyticsService.logNotificationError(
        type: type,
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: type,
        targetUserId: targetUserId,
        exception: e,
        stackTrace: st,
        additionalInfo: 'Rater: $raterId ($raterUsername), Rating: $rating',
      );
    }
  }

  Future<void> showCommentNotification({
    required String commenterId,
    required String commenterUsername,
    required String commentText,
    required String targetUserId,
  }) async {
    const type = 'comment';
    try {
      await _logStep('comment_notification_start', type,
          targetUserId: targetUserId,
          additionalInfo: 'Commenter: $commenterUsername');

      AnalyticsService.logNotificationAttempt(
        type: type,
        targetUserId: targetUserId,
        trigger: 'app',
      );

      final truncatedComment = commentText.length > 50
          ? '${commentText.substring(0, 47)}...'
          : commentText;

      await _notifications.show(
        _getNotificationId(),
        'New Comment',
        '$commenterUsername commented: $truncatedComment',
        const NotificationDetails(iOS: DarwinNotificationDetails()),
        payload: jsonEncode({
          'type': type,
          'commenterId': commenterId,
          'targetUserId': targetUserId,
        }),
      );

      await _logStep('comment_notification_shown', type,
          targetUserId: targetUserId, status: 'success');

      AnalyticsService.logNotificationDisplay(
        type: type,
        source: 'local',
      );
    } catch (e, st) {
      await _logStep('comment_notification_failed', type,
          targetUserId: targetUserId,
          status: 'error',
          additionalInfo: 'Error: ${e.toString()}');

      AnalyticsService.logNotificationError(
        type: type,
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: type,
        targetUserId: targetUserId,
        exception: e,
        stackTrace: st,
        additionalInfo: 'Commenter: $commenterId ($commenterUsername)\n'
            'Comment: ${commentText.length > 100 ? commentText.substring(0, 100) + '...' : commentText}',
      );
    }
  }

  Future<void> showCommentLikeNotification({
    required String likerId,
    required String likerUsername,
    required String commentText,
    required String targetUserId,
  }) async {
    const type = 'comment_like';
    try {
      await _logStep('comment_like_start', type,
          targetUserId: targetUserId, additionalInfo: 'Liker: $likerUsername');

      AnalyticsService.logNotificationAttempt(
        type: type,
        targetUserId: targetUserId,
        trigger: 'app',
      );

      final truncatedComment = commentText.length > 50
          ? '${commentText.substring(0, 47)}...'
          : commentText;

      await _notifications.show(
        _getNotificationId(),
        'Comment Liked',
        '$likerUsername liked your comment: $truncatedComment',
        const NotificationDetails(iOS: DarwinNotificationDetails()),
        payload: jsonEncode({
          'type': type,
          'likerId': likerId,
          'targetUserId': targetUserId,
        }),
      );

      await _logStep('comment_like_shown', type,
          targetUserId: targetUserId, status: 'success');

      AnalyticsService.logNotificationDisplay(
        type: type,
        source: 'local',
      );
    } catch (e, st) {
      await _logStep('comment_like_failed', type,
          targetUserId: targetUserId,
          status: 'error',
          additionalInfo: 'Error: ${e.toString()}');

      AnalyticsService.logNotificationError(
        type: type,
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: type,
        targetUserId: targetUserId,
        exception: e,
        stackTrace: st,
        additionalInfo: 'Liker: $likerId ($likerUsername)\n'
            'Comment: ${commentText.length > 100 ? commentText.substring(0, 100) + '...' : commentText}',
      );
    }
  }
}
