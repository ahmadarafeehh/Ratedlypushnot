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

  // iOS-safe notification ID generator
  int _getNotificationId() {
    return DateTime.now().millisecondsSinceEpoch % 2147483647;
  }

  Future<void> init() async {
    try {
      // 1. Request notification permissions
      final NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Log permission status
      AnalyticsService.logEvent(
        name: 'notification_permission',
        params: {
          'status': settings.authorizationStatus.name,
          'alert':
              '${settings.authorizationStatus == AuthorizationStatus.authorized}',
        },
      );

      // 2. Set up FCM message handlers
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // 3. Get and save FCM token
      _firebaseMessaging.getToken().then((token) {
        if (token != null) {
          AnalyticsService.logFcmToken(token);
          _saveTokenToFirestore(token);
        }
      });

      // Handle token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        AnalyticsService.logFcmToken(newToken);
        _saveTokenToFirestore(newToken);
      });

      // 4. Initialize local notifications
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentSound: true, // ← And this
      );

      await _notifications.initialize(
        const InitializationSettings(iOS: initializationSettingsIOS),
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            try {
              final data = jsonDecode(response.payload!);
              AnalyticsService.logNotificationDisplay(
                type: data['type']?.toString() ?? 'local',
                source: 'tap',
              );
            } catch (e) {
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

      // 5. Configure notification categories
      await _configureNotificationChannels();

      AnalyticsService.logEvent(
        name: 'notification_service_init',
        params: {'status': 'success'},
      );
    } catch (e, st) {
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
    final iOSPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (iOSPlugin != null) {
      await iOSPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    AnalyticsService.logEvent(
      name: 'notification_categories',
      params: {'status': 'skipped'},
    );
  }

  Future<void> _saveTokenToFirestore(String token) async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});

        AnalyticsService.logEvent(
          name: 'fcm_token_saved',
          params: {
            'userId': user.uid,
            'token_snippet': token.substring(0, 6),
          },
        );
      }
    } catch (e, st) {
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
    try {
      AnalyticsService.logEvent(
        name: 'fcm_foreground',
        params: {
          'message_id': message.messageId ?? 'unknown',
          'sent_time': message.sentTime?.toIso8601String() ?? 'unknown',
          'data': message.data,
        },
      );

      if (message.notification != null) {
        await _showNotification(
          title: message.notification!.title,
          body: message.notification!.body,
          data: message.data,
        );
      }
    } catch (e, st) {
      final targetUserId = message.data['targetUserId'] ?? 'unknown';
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
    try {
      await Firebase.initializeApp();

      AnalyticsService.logEvent(
        name: 'fcm_background',
        params: {
          'message_id': message.messageId ?? 'unknown',
          'sent_time': message.sentTime?.toIso8601String() ?? 'unknown',
          'data': message.data,
        },
      );

      if (message.notification != null) {
        final NotificationService service = NotificationService();
        await service._showNotification(
          title: message.notification!.title,
          body: message.notification!.body,
          data: message.data,
        );
      }
    } catch (e, st) {
      final targetUserId = message.data['targetUserId'] ?? 'unknown';
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
    try {
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true, // ← THIS IS CRUCIAL
        sound: 'default', // ← Use default system sound
        categoryIdentifier: 'ratedly_actions',
        threadIdentifier: 'ratedly_notifications',
      );

      await _notifications.show(
        _getNotificationId(),
        title ?? 'New Activity',
        body ?? 'You have new activity in Ratedly',
        const NotificationDetails(iOS: iosDetails),
        payload: jsonEncode(data),
      );

      AnalyticsService.logNotificationDisplay(
        type: data['type'] ?? 'local',
        source: 'foreground',
      );
    } catch (e, st) {
      final targetUserId = data['targetUserId'] ?? 'unknown';
      final notificationType = data['type'] ?? 'unknown_type';

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
    try {
      AnalyticsService.logNotificationAttempt(
        type: 'test',
        targetUserId: 'test',
        trigger: 'manual',
      );

      await _notifications.show(
        _getNotificationId(),
        'Test Notification',
        'This is a test notification from Ratedly!',
        const NotificationDetails(iOS: DarwinNotificationDetails()),
        payload: jsonEncode({
          'type': 'test',
          'source': 'debug',
        }),
      );

      AnalyticsService.logNotificationDisplay(
        type: 'test',
        source: 'local',
      );
    } catch (e, st) {
      AnalyticsService.logNotificationError(
        type: 'test',
        targetUserId: 'test',
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: 'test',
        targetUserId: 'test',
        exception: e,
        stackTrace: st,
        additionalInfo: 'Test notification failed',
      );
    }
  }

// Add to NotificationService class
  Future<void> showMessageNotification({
    required String senderId,
    required String senderUsername,
    required String message,
    required String chatId,
    required String targetUserId,
  }) async {
    try {
      AnalyticsService.logNotificationAttempt(
        type: 'message',
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
          'type': 'message',
          'senderId': senderId,
          'chatId': chatId,
          'targetUserId': targetUserId,
        }),
      );

      AnalyticsService.logNotificationDisplay(
        type: 'message',
        source: 'local',
      );
    } catch (e, st) {
      AnalyticsService.logNotificationError(
        type: 'message',
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: 'message',
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
    try {
      AnalyticsService.logNotificationAttempt(
        type: 'follow',
        targetUserId: targetUserId,
        trigger: 'app',
      );

      await _notifications.show(
        _getNotificationId(),
        'New Follower',
        '$followerUsername started following you',
        const NotificationDetails(iOS: DarwinNotificationDetails()),
        payload: jsonEncode({
          'type': 'follow',
          'followerId': followerId,
          'targetUserId': targetUserId,
        }),
      );

      AnalyticsService.logNotificationDisplay(
        type: 'follow',
        source: 'local',
      );
    } catch (e, st) {
      AnalyticsService.logNotificationError(
        type: 'follow',
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: 'follow',
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
    try {
      AnalyticsService.logNotificationAttempt(
        type: 'follow_request',
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
          'type': 'follow_request',
          'requesterId': requesterId,
          'targetUserId': targetUserId,
        }),
      );

      AnalyticsService.logNotificationDisplay(
        type: 'follow_request',
        source: 'local',
      );
    } catch (e, st) {
      AnalyticsService.logNotificationError(
        type: 'follow_request',
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: 'follow_request',
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
    try {
      AnalyticsService.logNotificationAttempt(
        type: 'rating',
        targetUserId: targetUserId,
        trigger: 'app',
      );

      await _notifications.show(
        _getNotificationId(),
        'New Rating',
        '$raterUsername rated your post: $rating',
        const NotificationDetails(iOS: DarwinNotificationDetails()),
        payload: jsonEncode({
          'type': 'rating',
          'raterId': raterId,
          'targetUserId': targetUserId,
        }),
      );

      AnalyticsService.logNotificationDisplay(
        type: 'rating',
        source: 'local',
      );
    } catch (e, st) {
      AnalyticsService.logNotificationError(
        type: 'rating',
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: 'rating',
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
    try {
      AnalyticsService.logNotificationAttempt(
        type: 'comment',
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
          'type': 'comment',
          'commenterId': commenterId,
          'targetUserId': targetUserId,
        }),
      );

      AnalyticsService.logNotificationDisplay(
        type: 'comment',
        source: 'local',
      );
    } catch (e, st) {
      AnalyticsService.logNotificationError(
        type: 'comment',
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: 'comment',
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
    try {
      AnalyticsService.logNotificationAttempt(
        type: 'comment_like',
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
          'type': 'comment_like',
          'likerId': likerId,
          'targetUserId': targetUserId,
        }),
      );

      AnalyticsService.logNotificationDisplay(
        type: 'comment_like',
        source: 'local',
      );
    } catch (e, st) {
      AnalyticsService.logNotificationError(
        type: 'comment_like',
        targetUserId: targetUserId,
        exception: e,
        stack: st,
      );
      ErrorLogService.logNotificationError(
        type: 'comment_like',
        targetUserId: targetUserId,
        exception: e,
        stackTrace: st,
        additionalInfo: 'Liker: $likerId ($likerUsername)\n'
            'Comment: ${commentText.length > 100 ? commentText.substring(0, 100) + '...' : commentText}',
      );
    }
  }
}
