import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:Ratedly/providers/user_provider.dart';
import 'package:Ratedly/screens/signup/auth_wrapper.dart';
import 'package:Ratedly/utils/colors.dart';
import 'package:provider/provider.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize notifications
  await NotificationService().init();

  runApp(const MyApp());
}


class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Platform-specific initialization
    final InitializationSettings settings;

    if (Platform.isAndroid) {
      // Android-specific settings
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      settings = const InitializationSettings(android: android);
    } else if (Platform.isIOS) {
      // iOS-specific settings
      const iOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      settings = const InitializationSettings(iOS: iOS);
    } else {
      // Fallback for other platforms
      settings = const InitializationSettings();
    }

    await _notifications.initialize(settings);
  }

  // Add this test notification method
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

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Ratedly.',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: mobileBackgroundColor,
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: mobileBackgroundColor,
            selectedItemColor: primaryColor,
            unselectedItemColor: Colors.grey[600],
            selectedLabelStyle: const TextStyle(color: primaryColor),
            unselectedLabelStyle: TextStyle(color: Colors.grey[600]),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
          ),
        ),
        home: const AuthWrapperWithNotificationTest(),
      ),
    );
  }
}

class AuthWrapperWithNotificationTest extends StatelessWidget {
  const AuthWrapperWithNotificationTest({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const AuthWrapper(),

        // Test notification button (visible in debug mode)
        if (kDebugMode)
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: primaryColor,
              onPressed: () => NotificationService().showTestNotification(),
              child: const Icon(Icons.notifications),
            ),
          ),
      ],
    );
  }
}
