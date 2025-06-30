import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Ratedly/models/user.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:Ratedly/resources/storage_methods.dart';

class AuthMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<AppUser> getUserDetails() async {
    firebase_auth.User currentUser = _auth.currentUser!;
    DocumentSnapshot documentSnapshot =
        await _firestore.collection('users').doc(currentUser.uid).get();

    if (!documentSnapshot.exists) {
      throw Exception('User document not found');
    }

    return AppUser.fromSnap(documentSnapshot);
  }

  Future<String> signUpUser({
    required String email,
    required String password,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        return "Please fill all required fields";
      }

      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user == null) {
        return "Registration failed - please try again";
      }

      // UNCOMMENT THIS TO ENABLE EMAIL VERIFICATION
      await cred.user!.sendEmailVerification();

      return "success";
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Registration failed";
    } catch (err) {
      return err.toString();
    }
  }

  Future<String> completeProfile({
    required String username,
    required String bio,
    Uint8List? file,
    required bool isPrivate,
    required String region,
    required int age,
    required String gender,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return "User not authenticated";

      await user.reload();
      if (!user.emailVerified) return "Email not verified";

      final processedUsername = username.trim();

      if (processedUsername.isEmpty) {
        return "Username cannot be empty";
      }
      if (processedUsername.length < 3) {
        return "Username must be at least 3 characters";
      }
      if (processedUsername.length > 20) {
        return "Username cannot exceed 20 characters";
      }

      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(processedUsername)) {
        return "Username can only contain letters, numbers, and underscores";
      }

      final usernameQuery = await _firestore
          .collection("users")
          .where("username", isEqualTo: processedUsername)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        return "Username '$processedUsername' is already taken";
      }

      String photoUrl = 'default';
      if (file != null) {
        photoUrl = await StorageMethods()
            .uploadImageToStorage('profilePics', file, false);
      }

      await _firestore.collection("users").doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'username': processedUsername,
        'bio': bio,
        'photoUrl': photoUrl,
        'isPrivate': isPrivate,
        'followers': [],
        'following': [],
        'followRequests': [],
        'ratings': [],
        'onboardingComplete': true,
        'createdAt': FieldValue.serverTimestamp(),
        'region': region,
        'age': age,
        'gender': gender,
      });

      return "success";
    } on FirebaseException catch (e) {
      return e.message ?? "Profile completion failed";
    } catch (err) {
      return err.toString();
    }
  }

  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(cred.user!.uid).get();

      if (!userDoc.exists) {
        return "onboarding_required";
      }

      return "success";
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        return "Please enter a valid email address";
      } else if (e.code == 'wrong-password' || e.code == 'user-not-found') {
        return "Incorrect email or password";
      } else if (e.code == 'user-disabled') {
        return "Account disabled";
      } else if (e.code == 'too-many-requests') {
        return "Too many attempts. Try again later";
      } else {
        return "Incorrect email or password";
      }
    } catch (e) {
      return "An unexpected error occurred";
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
