import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Ratedly/resources/storage_methods.dart';
import 'package:Ratedly/services/notification_service.dart'; // Add this import

class FireStoreProfileMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // private or public account
  Future<void> toggleAccountPrivacy(String uid, bool isPrivate) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'isPrivate': isPrivate});
  }

  Future<void> approveAllFollowRequests(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final batch = _firestore.batch();

    final userDoc = await userRef.get();
    final followRequests =
        (userDoc.data()?['followRequests'] as List? ?? []).toList();

    if (followRequests.isEmpty) return;

    for (final request in followRequests) {
      final requesterId = request['userId'];
      final timestamp = request['timestamp'] ?? FieldValue.serverTimestamp();

      batch.update(userRef, {
        'followers': FieldValue.arrayUnion([
          {'userId': requesterId, 'timestamp': timestamp}
        ])
      });

      final requesterRef = _firestore.collection('users').doc(requesterId);
      batch.update(requesterRef, {
        'following': FieldValue.arrayUnion([
          {'userId': userId, 'timestamp': timestamp}
        ])
      });

      final notificationId = 'follow_request_${userId}_$requesterId';
      batch.delete(_firestore.collection('notifications').doc(notificationId));

      final userData = userDoc.data() as Map<String, dynamic>;
      final acceptNotificationId = 'follow_accept_${requesterId}_$userId';
      batch.set(
        _firestore.collection('notifications').doc(acceptNotificationId),
        {
          'type': 'follow_request_accepted',
          'targetUserId': requesterId,
          'senderId': userId,
          'senderUsername': userData['username'],
          'senderProfilePic': userData['photoUrl'],
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        },
      );
    }

    batch.update(userRef, {'followRequests': []});

    await batch.commit();
  }

  Future<void> removeFollower(String currentUserId, String followerId) async {
    try {
      final batch = _firestore.batch();
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final followerRef = _firestore.collection('users').doc(followerId);

      final currentUserDoc = await currentUserRef.get();
      final followers = (currentUserDoc.data()?['followers'] as List?) ?? [];
      final followerEntry = followers.firstWhere(
        (entry) => entry['userId'] == followerId,
        orElse: () => null,
      );

      if (followerEntry != null) {
        batch.update(currentUserRef, {
          'followers': FieldValue.arrayRemove([followerEntry])
        });
      }

      final followerDoc = await followerRef.get();
      final following = (followerDoc.data()?['following'] as List?) ?? [];
      final followingEntry = following.firstWhere(
        (entry) => entry['userId'] == currentUserId,
        orElse: () => null,
      );

      if (followingEntry != null) {
        batch.update(followerRef, {
          'following': FieldValue.arrayRemove([followingEntry])
        });
      }

      final notificationsQuery = await _firestore
          .collection('notifications')
          .where('type', isEqualTo: 'follow')
          .where('followerId', isEqualTo: followerId)
          .where('targetUserId', isEqualTo: currentUserId)
          .get();

      for (final doc in notificationsQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> unfollowUser(String uid, String unfollowId) async {
    try {
      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(uid);
      final targetUserRef = _firestore.collection('users').doc(unfollowId);

      final userDoc = await userRef.get();
      final following = (userDoc.data()!)['following'] ?? [];
      final followingToRemove = following.firstWhere(
        (f) => f['userId'] == unfollowId,
        orElse: () => null,
      );

      if (followingToRemove != null) {
        batch.update(userRef, {
          'following': FieldValue.arrayRemove([followingToRemove])
        });
      }

      final targetDoc = await targetUserRef.get();
      final followers = (targetDoc.data()!)['followers'] ?? [];
      final followRequests = (targetDoc.data()!)['followRequests'] ?? [];

      final followerToRemove = followers.firstWhere(
        (f) => f['userId'] == uid,
        orElse: () => null,
      );

      if (followerToRemove != null) {
        batch.update(targetUserRef, {
          'followers': FieldValue.arrayRemove([followerToRemove])
        });
      }

      final requestToRemove = followRequests.firstWhere(
        (r) => r['userId'] == uid,
        orElse: () => null,
      );

      if (requestToRemove != null) {
        batch.update(targetUserRef, {
          'followRequests': FieldValue.arrayRemove([requestToRemove])
        });
      }

      final notificationQuery = await _firestore
          .collection('notifications')
          .where('type', isEqualTo: 'follow')
          .where('followerId', isEqualTo: uid)
          .where('targetUserId', isEqualTo: unfollowId)
          .limit(1)
          .get();

      if (notificationQuery.docs.isNotEmpty) {
        batch.delete(notificationQuery.docs.first.reference);
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> followUser(String uid, String followId) async {
    final userRef = _firestore.collection('users').doc(uid);
    final targetUserRef = _firestore.collection('users').doc(followId);
    final timestamp = DateTime.now();

    final isPrivate = (await targetUserRef.get())['isPrivate'] ?? false;
    final hasPending = await hasPendingRequest(uid, followId);

    final currentUserDoc = await userRef.get();
    final following = (currentUserDoc.data()!)['following'] ?? [];
    final isAlreadyFollowing =
        following.any((entry) => entry['userId'] == followId);

    if (hasPending || isAlreadyFollowing) {
      await declineFollowRequest(followId, uid);
      return;
    }

    if (isPrivate) {
      final requestData = {'userId': uid, 'timestamp': timestamp};
      await targetUserRef.update({
        'followRequests': FieldValue.arrayUnion([requestData])
      });

      // Trigger follow request notification
      final followerData = await userRef.get();
      await _notificationService.showFollowRequestNotification(
        requesterId: uid,
        requesterUsername: followerData['username'],
        targetUserId: followId,
      );

      await _createFollowRequestNotification(uid, followId);
    } else {
      final batch = _firestore.batch();

      final followerData = {'userId': uid, 'timestamp': timestamp};
      final followingData = {'userId': followId, 'timestamp': timestamp};

      batch.update(targetUserRef, {
        'followers': FieldValue.arrayUnion([followerData])
      });

      batch.update(userRef, {
        'following': FieldValue.arrayUnion([followingData])
      });

      await batch.commit();

      // Trigger follow notification
      final followerDataDoc = await userRef.get();
      await _notificationService.showFollowNotification(
        followerId: uid,
        followerUsername: followerDataDoc['username'],
        targetUserId: followId,
      );

      await createFollowNotification(uid, followId);
    }
  }

  Future<void> _createFollowRequestNotification(
      String requesterUid, String targetUid) async {
    final notificationId = 'follow_request_${targetUid}_$requesterUid';
    final requesterSnapshot =
        await _firestore.collection('users').doc(requesterUid).get();

    await _firestore.collection('notifications').doc(notificationId).set({
      'type': 'follow_request',
      'targetUserId': targetUid,
      'requesterId': requesterUid,
      'requesterUsername': requesterSnapshot['username'],
      'requesterProfilePic': requesterSnapshot['photoUrl'],
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<void> acceptFollowRequest(
      String targetUid, String requesterUid) async {
    try {
      final batch = _firestore.batch();
      final targetUserRef = _firestore.collection('users').doc(targetUid);
      final requesterRef = _firestore.collection('users').doc(requesterUid);
      final notificationRef = _firestore
          .collection('notifications')
          .doc('follow_request_${targetUid}_$requesterUid');

      final targetUserDoc = await targetUserRef.get();
      final followRequests =
          (targetUserDoc.data()?['followRequests'] as List?) ?? [];
      final requestToRemove = followRequests.firstWhere(
        (req) => req['userId'] == requesterUid,
        orElse: () => null,
      );

      if (requestToRemove != null) {
        batch.update(targetUserRef, {
          'followRequests': FieldValue.arrayRemove([requestToRemove])
        });
      }

      final timestamp = DateTime.now();
      batch.update(targetUserRef, {
        'followers': FieldValue.arrayUnion([
          {'userId': requesterUid, 'timestamp': timestamp}
        ])
      });

      batch.update(requesterRef, {
        'following': FieldValue.arrayUnion([
          {'userId': targetUid, 'timestamp': timestamp}
        ])
      });

      batch.delete(notificationRef);
      await batch.commit();

      final targetUserSnapshot = await targetUserRef.get();
      final targetUsername = targetUserSnapshot['username'];
      final targetProfilePic = targetUserSnapshot['photoUrl'];

      await _createFollowRequestAcceptedNotification(
        targetUid: targetUid,
        requesterUid: requesterUid,
        targetUsername: targetUsername,
        targetProfilePic: targetProfilePic,
      );

      await createFollowNotification(requesterUid, targetUid);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _createFollowRequestAcceptedNotification({
    required String targetUid,
    required String requesterUid,
    required String targetUsername,
    required String targetProfilePic,
  }) async {
    try {
      final notificationId = 'follow_accept_${requesterUid}_$targetUid';

      await _firestore.collection('notifications').doc(notificationId).set({
        'type': 'follow_request_accepted',
        'targetUserId': requesterUid,
        'senderId': targetUid,
        'senderUsername': targetUsername,
        'senderProfilePic': targetProfilePic,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (err) {
      rethrow;
    }
  }

  Future<void> declineFollowRequest(
      String targetUid, String requesterUid) async {
    try {
      final batch = _firestore.batch();
      final targetUserRef = _firestore.collection('users').doc(targetUid);
      final requesterRef = _firestore.collection('users').doc(requesterUid);

      final targetUserDoc = await targetUserRef.get();
      final followRequests = targetUserDoc['followRequests'] ?? [];
      final requestToRemove = followRequests.firstWhere(
        (req) => req['userId'] == requesterUid,
        orElse: () => null,
      );

      if (requestToRemove != null) {
        batch.update(targetUserRef, {
          'followRequests': FieldValue.arrayRemove([requestToRemove])
        });
      }

      final requesterDoc = await requesterRef.get();
      final following = requesterDoc['following'] ?? [];
      final followingToRemove = following.firstWhere(
        (f) => f['userId'] == targetUid,
        orElse: () => null,
      );

      if (followingToRemove != null) {
        batch.update(requesterRef, {
          'following': FieldValue.arrayRemove([followingToRemove])
        });
      }

      final notificationRef = _firestore
          .collection('notifications')
          .doc('follow_request_${targetUid}_$requesterUid');
      batch.delete(notificationRef);

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Future<String> reportProfile(String userId, String reason) async {
    String res = "Some error occurred";
    try {
      await _firestore.collection('reports').add({
        'userId': userId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'profile',
      });
      res = 'success';
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  Future<bool> hasPendingRequest(String requesterUid, String targetUid) async {
    final targetUserDoc =
        await _firestore.collection('users').doc(targetUid).get();
    final followRequests = targetUserDoc['followRequests'] ?? [];
    return followRequests.any((req) => req['userId'] == requesterUid);
  }

  Future<void> createFollowNotification(
      String followerUid, String followedUid) async {
    try {
      final notificationsRef = _firestore.collection('notifications');

      final notificationId = 'follow_${followedUid}_$followerUid';

      final followerSnapshot =
          await _firestore.collection('users').doc(followerUid).get();

      final notificationData = {
        'type': 'follow',
        'targetUserId': followedUid,
        'followerId': followerUid,
        'followerUsername': followerSnapshot['username'],
        'followerProfilePic': followerSnapshot['photoUrl'],
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      await notificationsRef
          .doc(notificationId)
          .set(notificationData, SetOptions(merge: true));
    } catch (err) {
      rethrow;
    }
  }

  Future<String> deleteEntireUserAccount(
      String uid, AuthCredential credential) async {
    String res = "Some error occurred";
    String? profilePicUrl;

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != uid) {
        throw Exception("User not authenticated or UID mismatch");
      }

      await currentUser.reauthenticateWithCredential(credential);
      DocumentSnapshot userSnap =
          await _firestore.collection('users').doc(uid).get();

      if (userSnap.exists) {
        Map<String, dynamic> data = userSnap.data() as Map<String, dynamic>;
        profilePicUrl = data['photoUrl'] as String?;
        WriteBatch batch = _firestore.batch();

        // Clean up followers/following relationships
        List<dynamic> followers = data['followers'] ?? [];
        List<dynamic> following = data['following'] ?? [];

        // Clean up followers' following lists
        for (var follower in followers) {
          if (follower['userId'] != null) {
            DocumentReference followerRef =
                _firestore.collection('users').doc(follower['userId']);
            batch.update(followerRef, {
              'following': FieldValue.arrayRemove([
                {'userId': uid, 'timestamp': follower['timestamp']}
              ])
            });
          }
        }

        // Clean up following's followers lists
        for (var followed in following) {
          if (followed['userId'] != null) {
            DocumentReference followedRef =
                _firestore.collection('users').doc(followed['userId']);
            batch.update(followedRef, {
              'followers': FieldValue.arrayRemove([
                {'userId': uid, 'timestamp': followed['timestamp']}
              ])
            });
          }
        }

        Future<void> _deletePostSubcollections(
            DocumentReference postRef) async {
          try {
            // Delete comments subcollection
            final comments = await postRef.collection('comments').get();
            for (DocumentSnapshot comment in comments.docs) {
              await comment.reference.delete();
            }

            // Delete views subcollection
            final views = await postRef.collection('views').get();
            for (DocumentSnapshot view in views.docs) {
              await view.reference.delete();
            }
          } catch (e) {
            rethrow;
          }
        }

        await _deleteAllUserChatsAndMessages(uid, batch); // Add this line
        // Delete user's posts and their storage
        QuerySnapshot postsSnap = await _firestore
            .collection('posts')
            .where('uid', isEqualTo: uid)
            .get();

// Delete in chunks to avoid batch limits
        const batchSize = 400;
        for (int i = 0; i < postsSnap.docs.length; i += batchSize) {
          WriteBatch postBatch = _firestore.batch();
          final postsChunk = postsSnap.docs.sublist(
              i,
              i + batchSize > postsSnap.docs.length
                  ? postsSnap.docs.length
                  : i + batchSize);

          for (DocumentSnapshot doc in postsChunk) {
            // 1. Delete post document
            postBatch.delete(doc.reference);

            // 2. Delete image from storage
            await StorageMethods().deleteImage(doc['postUrl']);

            // 3. Delete post subcollections (comments, views)
            await _deletePostSubcollections(doc.reference);
          }

          await postBatch.commit();
        }
        // Delete all comments by the user
        QuerySnapshot commentsSnap = await _firestore
            .collectionGroup('comments')
            .where('uid', isEqualTo: uid)
            .get();
        for (DocumentSnapshot commentDoc in commentsSnap.docs) {
          batch.delete(commentDoc.reference);
        }

        // Remove user's ratings from all posts
        QuerySnapshot allPosts = await _firestore.collection('posts').get();
        for (DocumentSnapshot postDoc in allPosts.docs) {
          List<dynamic> ratings = postDoc['rate'] ?? [];
          List<dynamic> updatedRatings =
              ratings.where((rating) => rating['userId'] != uid).toList();
          if (updatedRatings.length < ratings.length) {
            batch.update(postDoc.reference, {'rate': updatedRatings});
          }
        }

        // Delete user document
        DocumentReference userDocRef = _firestore.collection('users').doc(uid);
        batch.delete(userDocRef);

        await batch.commit();

        // Delete all notifications
        Query notificationsQuery =
            _firestore.collection('notifications').where(Filter.or(
                  Filter('targetUserId', isEqualTo: uid),
                  Filter('senderId', isEqualTo: uid),
                  Filter('followerId', isEqualTo: uid),
                  Filter('raterUid', isEqualTo: uid),
                  Filter('likerUid', isEqualTo: uid),
                  Filter('commenterUid', isEqualTo: uid),
                  Filter('requesterId', isEqualTo: uid),
                ));

        QuerySnapshot notifSnap = await notificationsQuery.get();
        while (notifSnap.docs.isNotEmpty) {
          WriteBatch notifBatch = _firestore.batch();
          for (DocumentSnapshot doc in notifSnap.docs) {
            notifBatch.delete(doc.reference);
          }
          await notifBatch.commit();
          notifSnap = await notificationsQuery
              .startAfterDocument(notifSnap.docs.last)
              .get();
        }

        // Delete profile image
        if (profilePicUrl != null &&
            profilePicUrl.isNotEmpty &&
            profilePicUrl != 'default') {
          // ← Add this validation
          await StorageMethods().deleteImage(profilePicUrl);
        }

        await currentUser.delete();
        res = "success";
      }
    } on FirebaseAuthException catch (e) {
      res = e.code == 'requires-recent-login'
          ? "Re-authentication required. Please sign in again."
          : e.message ?? "Authentication error";
    } catch (e) {
      res = e.toString();
    }
    return res;
  }

  Future<void> _deleteAllUserChatsAndMessages(
      String uid, WriteBatch batch) async {
    try {
      // Use existing participants index
      final chatsQuery = await _firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();

      for (final chatDoc in chatsQuery.docs) {
        // Delete messages using existing timestamp index
        final messages = await chatDoc.reference
            .collection('messages')
            .orderBy('timestamp')
            .get();

        for (final messageDoc in messages.docs) {
          batch.delete(messageDoc.reference);
        }
        batch.delete(chatDoc.reference);
      }
    } catch (e) {
      rethrow;
    }
  }
}
