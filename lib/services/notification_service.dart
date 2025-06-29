// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(iOS: iOS);
    await _notifications.initialize(settings);
  }

  Future<void> showTestNotification() async {
    const iOSDetails = DarwinNotificationDetails();
    const details = NotificationDetails(iOS: iOSDetails);

    await _notifications.show(
      0,
      'Test Notification',
      'This is a test notification from Ratedly!',
      details,
    );
  }

  Future<void> showPostRatingNotification({
    required String raterId,
    required String raterUsername,
    required double rating,
    required String targetUserId,
  }) async {
    const iOSDetails = DarwinNotificationDetails();
    const details = NotificationDetails(iOS: iOSDetails);

    await _notifications.show(
      0,
      'New Rating',
      '$raterUsername rated your post: $rating',
      details,
      payload: 'post_rating::$raterId',
    );
  }

  Future<void> showCommentNotification({
    required String commenterId,
    required String commenterUsername,
    required String commentText,
    required String targetUserId,
  }) async {
    const iOSDetails = DarwinNotificationDetails();
    const details = NotificationDetails(iOS: iOSDetails);

    // Truncate long comments
    final truncatedComment = commentText.length > 50
        ? commentText.substring(0, 47) + '...'
        : commentText;

    await _notifications.show(
      0,
      'New Comment',
      '$commenterUsername commented: $truncatedComment',
      details,
      payload: 'post_comment::$commenterId',
    );
  }

  Future<void> showCommentLikeNotification({
    required String likerId,
    required String likerUsername,
    required String commentText,
    required String targetUserId,
  }) async {
    const iOSDetails = DarwinNotificationDetails();
    const details = NotificationDetails(iOS: iOSDetails);

    // Truncate long comments
    final truncatedComment = commentText.length > 50
        ? commentText.substring(0, 47) + '...'
        : commentText;

    await _notifications.show(
      0,
      'Comment Liked',
      '$likerUsername liked your comment: $truncatedComment',
      details,
      payload: 'comment_like::$likerId',
    );
  }

  Future<void> showFollowNotification({
    required String followerId,
    required String followerUsername,
    required String targetUserId,
  }) async {
    const iOSDetails = DarwinNotificationDetails();
    const details = NotificationDetails(iOS: iOSDetails);

    await _notifications.show(
      0,
      'New Follower',
      '$followerUsername started following you',
      details,
      payload: 'user_profile::$followerId',
    );
  }

  Future<void> showFollowRequestNotification({
    required String requesterId,
    required String requesterUsername,
    required String targetUserId,
  }) async {
    const iOSDetails = DarwinNotificationDetails();
    const details = NotificationDetails(iOS: iOSDetails);

    await _notifications.show(
      0,
      'Follow Request',
      '$requesterUsername wants to follow you',
      details,
      payload: 'follow_requests',
    );
  }
}
