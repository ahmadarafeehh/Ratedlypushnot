import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:Ratedly/resources/storage_methods.dart';
import 'package:Ratedly/services/notification_service.dart';
import 'package:Ratedly/services/error_log_service.dart';

class FireStoreProfileMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Helper method to record push notifications
  Future<void> _recordPushNotification({
    required String type,
    required String targetUserId,
    required String title,
    required String body,
    required Map<String, dynamic> customData,
  }) async {
    try {
      await _firestore.collection('Push Not').add({
        'type': type,
        'targetUserId': targetUserId,
        'title': title,
        'body': body,
        'customData': customData,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error recording push notification: $e');
      }
    }
  }

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

      // ADD: Get requester's data
      final requesterSnap =
          await _firestore.collection('users').doc(requesterId).get();
      final requesterData = requesterSnap.data() as Map<String, dynamic>?;

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

      // ADD requesterUsername here
      batch.set(
        _firestore.collection('notifications').doc(acceptNotificationId),
        {
          'type': 'follow_request_accepted',
          'targetUserId': requesterId,
          'senderId': userId,
          'senderUsername': userData['username'],
          'requesterUsername': requesterData?['username'] ?? 'User', // Added
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

      // 1. Remove from currentUser’s "followers"
      final currentUserDoc = await currentUserRef.get();
      final followers = (currentUserDoc.data()?['followers'] as List?) ?? [];
      final followerEntry = followers.firstWhere(
        (e) => e['userId'] == followerId,
        orElse: () => null,
      );
      if (followerEntry != null) {
        batch.update(currentUserRef, {
          'followers': FieldValue.arrayRemove([followerEntry]),
        });
      }

      // 2. Also clear any stale followRequests on currentUser side
      batch.update(currentUserRef, {
        'followRequests': FieldValue.arrayRemove([
          {'userId': followerId}
        ])
      });

      // 3. Remove from follower’s "following"
      final followerDoc = await followerRef.get();
      final following = (followerDoc.data()?['following'] as List?) ?? [];
      final followingEntry = following.firstWhere(
        (e) => e['userId'] == currentUserId,
        orElse: () => null,
      );
      if (followingEntry != null) {
        batch.update(followerRef, {
          'following': FieldValue.arrayRemove([followingEntry]),
        });
      }

      // 4. Also clear any stale followRequests on follower side
      batch.update(followerRef, {
        'followRequests': FieldValue.arrayRemove([
          {'userId': currentUserId}
        ])
      });

      // 5. Delete any “follow” notifications
      final followNotifs = await _firestore
          .collection('notifications')
          .where('type', isEqualTo: 'follow')
          .where('followerId', isEqualTo: followerId)
          .where('targetUserId', isEqualTo: currentUserId)
          .get();
      for (final doc in followNotifs.docs) {
        batch.delete(doc.reference);
      }

      // 6. **Delete any “follow_request_accepted” notifications**
      //    so that followerId no longer sees "xyz approved your request"
      final acceptNotifs = await _firestore
          .collection('notifications')
          .where('type', isEqualTo: 'follow_request_accepted')
          .where('targetUserId', isEqualTo: followerId)
          .where('senderId', isEqualTo: currentUserId)
          .get();
      for (final doc in acceptNotifs.docs) {
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

    try {
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

        // Get requester info for notifications
        final requesterDoc = await userRef.get();
        final requesterUsername = requesterDoc['username'] ?? 'Someone';

        // Send server push notification
        _notificationService.triggerServerNotification(
          type: 'follow_request',
          targetUserId: followId,
          title: 'New Follow Request',
          body: '$requesterUsername wants to follow you',
          customData: {'requesterId': uid},
        );

        // Record push notification
        await _recordPushNotification(
          type: 'follow_request',
          targetUserId: followId,
          title: 'New Follow Request',
          body: '$requesterUsername wants to follow you',
          customData: {'requesterId': uid},
        );

        // Create in-app notification
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

        // Get follower info for notifications
        final followerDoc = await userRef.get();
        final followerUsername = followerDoc['username'] ?? 'Someone';

        // Send server push notification
        _notificationService.triggerServerNotification(
          type: 'follow',
          targetUserId: followId,
          title: 'New Follower',
          body: '$followerUsername started following you',
          customData: {'followerId': uid},
        );

        // Record push notification
        await _recordPushNotification(
          type: 'follow',
          targetUserId: followId,
          title: 'New Follower',
          body: '$followerUsername started following you',
          customData: {'followerId': uid},
        );

        // Create in-app notification
        await createFollowNotification(uid, followId);
      }
    } catch (e) {
      // Enhanced error logging
      ErrorLogService.logNotificationError(
        type: 'follow',
        targetUserId: followId,
        exception: e,
        additionalInfo: 'Follower: $uid',
      );
      rethrow;
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

      // Create in-app notifications
      await _createFollowRequestAcceptedNotification(
        approverUid: targetUid, // The approver is targetUid
        requesterUid: requesterUid,
      );

      await createFollowNotification(
        requesterUid, // Follower UID
        targetUid, // Followed UID
      );

      // ADDED: Push notification to requester about approval
      try {
        final approverSnapshot =
            await _firestore.collection('users').doc(targetUid).get();
        final approverUsername = approverSnapshot['username'] ?? 'Someone';

        // Trigger server push notification
        _notificationService.triggerServerNotification(
          type: 'follow_request_accepted',
          targetUserId: requesterUid,
          title: 'Follow Request Approved',
          body: '$approverUsername approved your follow request',
          customData: {'approverId': targetUid},
        );

        // Record push notification in Firestore
        await _recordPushNotification(
          type: 'follow_request_accepted',
          targetUserId: requesterUid,
          title: 'Follow Request Approved',
          body: '$approverUsername approved your follow request',
          customData: {'approverId': targetUid},
        );
      } catch (e) {
        ErrorLogService.logNotificationError(
          type: 'follow_request_accepted',
          targetUserId: requesterUid,
          exception: e,
          additionalInfo: 'Approver: $targetUid',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _createFollowRequestAcceptedNotification({
    required String approverUid,
    required String requesterUid,
  }) async {
    try {
      final notificationId = 'follow_accept_${requesterUid}_$approverUid';
      // Fetch approver and requester
      final approverSnapshot =
          await _firestore.collection('users').doc(approverUid).get();
      final requesterSnapshot =
          await _firestore.collection('users').doc(requesterUid).get();

      final approverData = approverSnapshot.data() ?? {};
      final requesterData = requesterSnapshot.data() ?? {};

      final senderUsername = approverData['username'] ?? 'User';
      final fetchedRequesterUsername = requesterData['username'] ?? 'User';

      final payload = {
        'type': 'follow_request_accepted',
        'targetUserId': requesterUid,
        'senderId': approverUid,
        'senderUsername': senderUsername,
        'requesterUsername': fetchedRequesterUsername,
        'senderProfilePic': approverData['photoUrl'],
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .set(payload);
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
    String followerUid,
    String followedUid,
  ) async {
    final followerSnap =
        await _firestore.collection('users').doc(followerUid).get();

    final notificationData = {
      'type': 'follow',
      'targetUserId': followedUid,
      'followerId': followerUid,
      'followerUsername': followerSnap['username'],
      'followerProfilePic': followerSnap['photoUrl'],
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };

    await _firestore
        .collection('notifications')
        .doc('follow_${followedUid}_$followerUid')
        .set(notificationData, SetOptions(merge: true));
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
