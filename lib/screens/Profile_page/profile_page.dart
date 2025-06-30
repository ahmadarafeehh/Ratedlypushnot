// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Ratedly/screens/Profile_page/current_profile_screen.dart';
import 'package:Ratedly/screens/Profile_page/other_user_profile.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;
  const ProfileScreen({Key? key, required this.uid}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  }

  @override
  Widget build(BuildContext context) {
    return widget.uid == _currentUserId
        ? CurrentUserProfileScreen(uid: widget.uid)
        : OtherUserProfileScreen(uid: widget.uid);
  }
}
