import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Ratedly/screens/login.dart';
import 'package:Ratedly/screens/signup/age_screen.dart';
import 'package:Ratedly/screens/signup/verify_email_screen.dart'; // Add this import
import 'package:Ratedly/responsive/mobile_screen_layout.dart';
import 'package:Ratedly/responsive/responsive_layout.dart';

class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const LoginScreen();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Handle errors
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final userDocExists = snapshot.hasData && snapshot.data!.exists;

        // NEW: Check if user document exists and email is verified
        if (!userDocExists) {
          // First check if email is verified
          if (user.emailVerified) {
            return const AgeVerificationScreen();
          } else {
            return const VerifyEmailScreen();
          }
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;

        // Handle existing users
        if (userData['onboardingComplete'] == true) {
          return const ResponsiveLayout(
            mobileScreenLayout: MobileScreenLayout(),
          );
        }

        // Final fallback to age screen
        return const AgeVerificationScreen();
      },
    );
  }
}
