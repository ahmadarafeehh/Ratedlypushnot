import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:Ratedly/screens/feed/feed_screen.dart';
import 'package:Ratedly/screens/Profile_page/profile_page.dart';
import 'package:Ratedly/screens/search_screen.dart';
import 'package:Ratedly/screens/notification_screen.dart';

const webScreenSize = 600;

List<Widget> homeScreenItems = [
  const FeedScreen(),
  const SearchScreen(),
  const NotificationScreen(),
  //const AddPostScreen(),

  // Create ProfileScreen dynamically, ensuring the current logged-in user's UID is used

  Builder(
    builder: (context) {
      final String currentUserUid = FirebaseAuth.instance.currentUser!.uid;
      return ProfileScreen(
          uid: currentUserUid); // Get current user's UID dynamically
    },
  ),
];
