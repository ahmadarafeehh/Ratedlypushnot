// lib/services/analytics_service.dart
import 'dart:ui' as ui;
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Initializes analytics and sets the user's country once.
  static Future<void> init() async {
    final country = ui.PlatformDispatcher.instance.locale.countryCode;
    if (country != null) {
      await _analytics.setUserProperty(
        name: 'country',
        value: country,
      );
    }
  }

  /// Log a custom event with optional params. Avoid frequent calls.
  static Future<void> logEvent(
    String name, {
    Map<String, Object>? params,
  }) async {
    await _analytics.logEvent(
      name: name,
      parameters: params,
    );
  }
}
