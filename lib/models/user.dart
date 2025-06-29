import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String email;
  final String uid;
  final String photoUrl;
  final String username;
  final String bio;
  final List followers;
  final List following;
  final bool isPrivate;
  final List followRequests;
  final bool onboardingComplete;
  final Timestamp? createdAt;
  final Timestamp? completedAt;
  final String region;
  final int? age;
  final String gender;

  const AppUser({
    required this.username,
    required this.uid,
    required this.photoUrl,
    required this.email,
    required this.bio,
    required this.followers,
    required this.following,
    required this.isPrivate,
    required this.followRequests,
    required this.onboardingComplete,
    this.createdAt,
    this.completedAt,
    required this.region,
    this.age,
    required this.gender,
  });

  factory AppUser.fromSnap(DocumentSnapshot snap) {
    try {
      final snapshot = snap.data() as Map<String, dynamic>;

      // Add validation for required fields
      if (snapshot['uid'] == null || (snapshot['uid'] as String).isEmpty) {
        throw const FormatException('Invalid user document: missing uid');
      }

      return AppUser(
        username: snapshot["username"] ?? 'Unknown User',
        uid: snapshot["uid"] as String,
        email: snapshot["email"] ?? '',
        photoUrl: snapshot["photoUrl"] ?? '',
        bio: snapshot["bio"] ?? '',
        followers: snapshot["followers"] ?? [],
        following: snapshot["following"] ?? [],
        isPrivate: snapshot["isPrivate"] ?? false,
        followRequests: snapshot["followRequests"] ?? [],
        onboardingComplete: snapshot["onboardingComplete"] ?? false,
        createdAt: snapshot["createdAt"],
        completedAt: snapshot["completedAt"],
        region: snapshot["region"] ?? '',
        age: snapshot["age"] as int? ?? 0,
        gender: snapshot["gender"] ?? '',
      );
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        "username": username,
        "uid": uid,
        "email": email,
        "photoUrl": photoUrl,
        "bio": bio,
        "followers": followers,
        "following": following,
        "isPrivate": isPrivate,
        "followRequests": followRequests,
        "onboardingComplete": onboardingComplete,
        "createdAt": createdAt,
        "completedAt": completedAt,
        "region": region,
        "age": age,
        "gender": gender,
      };
}
