// lib/services/analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'error_log_service.dart'; // Add this import

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  static final Logger _logger = Logger();

  static Future<void> init() async {
    await _crashlytics.setCrashlyticsCollectionEnabled(true);
    await _analytics.setAnalyticsCollectionEnabled(true);
    if (kDebugMode) {
      _logger.i("Analytics service initialized");
    }
  }

  static void logEvent({
    required String name,
    required Map<String, Object> params,
  }) {
    try {
      _analytics.logEvent(name: name, parameters: params);
      _logger.i('[$name] ${params.toString()}');
    } catch (e) {
      _logger.e("Analytics error: $e");
    }
  }

  static void logNotificationAttempt({
    required String type,
    required String targetUserId,
    required String trigger,
    String? error,
  }) {
    final params = <String, Object>{
      'notification_type': type,
      'target_user': targetUserId,
      'trigger': trigger,
      'status': error != null ? 'failed' : 'attempted',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (error != null) {
      params['error'] = error;
    }

    logEvent(name: 'notification_attempt', params: params);
  }

  static void logNotificationError({
    required String type,
    required String targetUserId,
    required Object exception,
    StackTrace? stack,
  }) {
    _crashlytics.recordError(
      exception,
      stack,
      reason: 'Notification Failed: $type',
      information: ['target_user: $targetUserId'],
    );

    logEvent(
      name: 'notification_error',
      params: {
        'type': type,
        'target_user': targetUserId,
        'exception': exception.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    _logger.e(
      '[NOTIFICATION ERROR] $type to $targetUserId',
      error: exception,
      stackTrace: stack,
    );

    // Add Firestore error logging
    ErrorLogService.logNotificationError(
      type: type,
      targetUserId: targetUserId,
      exception: exception,
      stackTrace: stack,
    );
  }

  static void logFcmToken(String token) {
    logEvent(
      name: 'fcm_token_received',
      params: {'token': '${token.substring(0, 6)}...'},
    );
    _logger.i('[FCM TOKEN] ${token.substring(0, 6)}...');
  }

  static void logNotificationDisplay({
    required String type,
    required String source,
  }) {
    logEvent(
      name: 'notification_displayed',
      params: {
        'type': type,
        'source': source,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    _logger.i('[NOTIFICATION DISPLAYED] $type from $source');
  }
} // Only ONE closing brace here
