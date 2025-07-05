import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:Ratedly/models/post.dart';
import 'package:Ratedly/resources/storage_methods.dart';
import 'package:uuid/uuid.dart';
import 'package:Ratedly/services/notification_service.dart';
import 'package:Ratedly/services/error_log_service.dart';

class FireStorePostsMethods {
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

  // Upload a post
  Future<String> uploadPost(
    String description,
    Uint8List file,
    String uid,
    String username,
    String profImage,
    String region,
    int age,
    String gender,
  ) async {
    String res = "Some error occurred";
    try {
      String photoUrl =
          await StorageMethods().uploadImageToStorage('posts', file, true);
      String postId = const Uuid().v1();

      Post post = Post(
        description: description,
        uid: uid,
        username: username,
        rate: [],
        postId: postId,
        datePublished: DateTime.now(),
        postUrl: photoUrl,
        profImage: profImage,
        region: region,
        age: age,
        gender: gender,
      );

      await _firestore.collection('posts').doc(postId).set(post.toJson());
      res = "success";
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  // Like a comment
  Future<String> likeComment(
      String postId, String commentId, String uid) async {
    String res = "Some error occurred";
    try {
      DocumentReference commentRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      String? commentOwnerId;
      final commentSnapshot = await commentRef.get();
      if (commentSnapshot.exists) {
        commentOwnerId = commentSnapshot['uid'];
      }

      final result = await _firestore.runTransaction<Map<String, dynamic>>(
        (transaction) async {
          final snapshot = await transaction.get(commentRef);
          if (!snapshot.exists) throw Exception("Comment does not exist");

          List<dynamic> likes = snapshot['likes'] ?? [];
          int likeCount = snapshot['likeCount'] ?? 0;
          final Map<String, dynamic> result = {
            'wasLikeRemoved': false,
            'commentText': '',
          };

          if (likes.contains(uid)) {
            // Remove like
            transaction.update(commentRef, {
              'likes': FieldValue.arrayRemove([uid]),
              'likeCount': likeCount - 1,
              'lastLiked': FieldValue.serverTimestamp(),
            });
            result['wasLikeRemoved'] = true;
          } else {
            // Add like
            transaction.update(commentRef, {
              'likes': FieldValue.arrayUnion([uid]),
              'likeCount': likeCount + 1,
              'lastLiked': FieldValue.serverTimestamp(),
            });
            result['commentText'] = snapshot['text'];
          }
          return result;
        },
      );

      // Handle notifications after transaction
      if (result['wasLikeRemoved']) {
        await deleteCommentLikeNotification(postId, commentId, uid);
      } else if (commentOwnerId != null && uid != commentOwnerId) {
        // Get liker's username for notification
        final likerSnapshot =
            await _firestore.collection('users').doc(uid).get();
        final likerUsername = likerSnapshot['username'] ?? 'Someone';

        // Create in-app notification
        await createCommentLikeNotification(
          postId,
          commentId,
          commentOwnerId,
          uid,
          result['commentText']!,
        );

        // Record push notification
        await _recordPushNotification(
          type: 'comment_like',
          targetUserId: commentOwnerId,
          title: 'New Like',
          body: '$likerUsername liked your comment: ${result['commentText']}',
          customData: {
            'likerId': uid,
            'postId': postId,
            'commentId': commentId,
          },
        );

        // Trigger server notification
        _notificationService.triggerServerNotification(
          type: 'comment_like',
          targetUserId: commentOwnerId,
          title: 'New Like',
          body: '$likerUsername liked your comment: ${result['commentText']}',
          customData: {
            'likerId': uid,
            'postId': postId,
            'commentId': commentId,
          },
        );
      }
      res = 'success';
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  Future<void> createCommentLikeNotification(
    String postId,
    String commentId,
    String commentOwnerId,
    String likerUid,
    String commentText,
  ) async {
    try {
      // Create descriptive document ID
      final notificationId = 'comment_like_${commentId}_$likerUid';

      // Get liker's information
      final likerSnapshot =
          await _firestore.collection('users').doc(likerUid).get();

      // Create notification data
      final notificationData = {
        'type': 'comment_like',
        'targetUserId': commentOwnerId,
        'likerUid': likerUid,
        'likerUsername': likerSnapshot['username'],
        'likerProfilePic': likerSnapshot['photoUrl'],
        'postId': postId,
        'commentId': commentId,
        'commentText': commentText,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      // Set document with explicit ID
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .set(notificationData, SetOptions(merge: true));

      if (kDebugMode) {}
    } catch (err) {
      if (kDebugMode) {}
    }
  }

  // Create notification for rating
  Future<void> createNotification(
    String postId,
    String postOwnerUid,
    String raterUid,
    double rating,
  ) async {
    try {
      // Skip self-rating notifications
      if (raterUid == postOwnerUid) {
        if (kDebugMode) {}
        return;
      }

      // Create descriptive document ID
      final notificationId = 'post_rating_${postId}_$raterUid';
      final notificationsRef = _firestore.collection('notifications');

      // Get rater information
      final raterSnapshot =
          await _firestore.collection('users').doc(raterUid).get();

      // Prepare notification data
      final notificationData = {
        'type': 'post_rating',
        'postId': postId,
        'targetUserId': postOwnerUid,
        'raterUid': raterUid,
        'raterUsername': raterSnapshot['username'],
        'raterProfilePic': raterSnapshot['photoUrl'],
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      // Set/update the notification directly using known ID format
      await notificationsRef
          .doc(notificationId)
          .set(notificationData, SetOptions(merge: true));

      if (kDebugMode) {}
    } catch (err) {
      if (kDebugMode) {}
    }
  }

  // For for you feed
  Future<List<String>> getViewedPostIds(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collectionGroup('views')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp')
          .get();

      final reversedDocs = querySnapshot.docs.reversed;

      return reversedDocs
          .map((doc) => doc.reference.parent.parent?.id ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return [];
    }
  }

  Future<String> deleteComment(String postId, String commentId) async {
    String res = "Some error occurred";
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .delete();

      await _firestore.collection('posts').doc(postId).update({
        'commentsCount': FieldValue.increment(-1),
      });

      final notificationsQuery = await _firestore
          .collection('notifications')
          .where('commentId', isEqualTo: commentId)
          .get();

      final batch = _firestore.batch();
      for (var doc in notificationsQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      res = 'success';
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  Future<void> deleteCommentLikeNotification(
    String postId,
    String commentId,
    String likerUid,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('type', isEqualTo: 'comment_like')
          .where('postId', isEqualTo: postId)
          .where('commentId', isEqualTo: commentId)
          .where('likerUid', isEqualTo: likerUid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await _firestore
            .collection('notifications')
            .doc(querySnapshot.docs.first.id)
            .delete();
      }
    } catch (err) {
      if (kDebugMode) print(err);
    }
  }

  // Rate a post
  Future<String> ratePost(String postId, String uid, double rating) async {
    String res = "Some error occurred";
    String postOwnerUid = '';

    try {
      double roundedRating = double.parse(rating.toStringAsFixed(1));
      DocumentSnapshot postSnapshot =
          await _firestore.collection('posts').doc(postId).get();
      List<dynamic> ratings = postSnapshot['rate'];
      postOwnerUid = postSnapshot['uid'];
      bool isSelfRating = (uid == postOwnerUid);
      bool hasRated = ratings.any((entry) => entry['userId'] == uid);
      final timestamp = DateTime.now();

      if (hasRated) {
        ratings = ratings.map((entry) {
          if (entry['userId'] == uid) {
            return {
              ...entry,
              'rating': roundedRating,
              'timestamp': timestamp,
            };
          }
          return entry;
        }).toList();
      } else {
        ratings.add({
          'userId': uid,
          'rating': roundedRating,
          'timestamp': timestamp,
        });
      }

      await _firestore.collection('posts').doc(postId).update({
        'rate': ratings,
      });

      // Handle notifications for non-self ratings
      if (!isSelfRating) {
        // Create in-app notification
        await createNotification(postId, postOwnerUid, uid, roundedRating);

        final raterSnapshot =
            await _firestore.collection('users').doc(uid).get();
        final raterUsername = raterSnapshot['username'] ?? 'Someone';

        // Record push notification
        await _recordPushNotification(
          type: 'rating',
          targetUserId: postOwnerUid,
          title: 'New Rating',
          body:
              '$raterUsername rated your post: ${roundedRating.toStringAsFixed(1)}/10',
          customData: {
            'raterId': uid,
            'postId': postId,
          },
        );

        // Trigger server notification
        _notificationService.triggerServerNotification(
          type: 'rating',
          targetUserId: postOwnerUid,
          title: 'New Rating',
          body:
              '$raterUsername rated your post: ${roundedRating.toStringAsFixed(1)}★',
          customData: {
            'raterId': uid,
            'postId': postId,
          },
        );
      }
      res = 'success';
    } catch (err) {
      res = err.toString();
      ErrorLogService.logNotificationError(
        type: 'post_rating',
        targetUserId: postOwnerUid,
        exception: err,
        additionalInfo: 'Post: $postId, Rater: $uid, Rating: $rating',
      );
    }
    return res;
  }

  Future<void> createCommentNotification(
    String postId,
    String commenterUid,
    String commenterName,
    String commenterProfilePic,
    String commentText,
    String commentId,
  ) async {
    try {
      if (kDebugMode) {}

      // Fetch post owner UID
      final postSnapshot =
          await _firestore.collection('posts').doc(postId).get();
      final postOwnerUid = postSnapshot['uid'];

      // Skip self-comment notifications
      if (commenterUid == postOwnerUid) {
        if (kDebugMode) {}
        return;
      }

      // Create descriptive document ID
      final notificationId = 'comment_${postId}_$commentId';
      final notificationData = {
        'type': 'comment',
        'targetUserId': postOwnerUid,
        'commenterUid': commenterUid,
        'commenterName': commenterName,
        'commenterProfilePic': commenterProfilePic,
        'commentText': commentText,
        'postId': postId,
        'commentId': commentId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      // Set notification directly with known ID
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .set(notificationData);

      if (kDebugMode) {}
    } catch (err) {
      if (kDebugMode) {}
    }
  }

  // Post a comment
  Future<String> postComment(
    String postId,
    String text,
    String uid,
    String name,
    String profilePic,
  ) async {
    String res = "Some error occurred";
    try {
      if (text.isNotEmpty) {
        String commentId = const Uuid().v1();

        await _firestore
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .doc(commentId)
            .set({
          'profilePic': profilePic,
          'name': name,
          'uid': uid,
          'text': text,
          'commentId': commentId,
          'datePublished': DateTime.now(),
          'likes': [],
          'likeCount': 0,
          'lastLiked': null,
        });

        res = 'success';

        await _firestore.collection('posts').doc(postId).update({
          'commentsCount': FieldValue.increment(1),
        });

        DocumentSnapshot postSnapshot =
            await _firestore.collection('posts').doc(postId).get();
        String postOwnerUid = postSnapshot['uid'];

        if (uid != postOwnerUid) {
          // Create in-app notification
          await createCommentNotification(
            postId,
            uid,
            name,
            profilePic,
            text,
            commentId,
          );

          // Record push notification
          await _recordPushNotification(
            type: 'comment',
            targetUserId: postOwnerUid,
            title: 'New Comment',
            body: '$name commented: $text',
            customData: {
              'commenterId': uid,
              'postId': postId,
              'commentId': commentId,
            },
          );

          // Trigger server notification
          _notificationService.triggerServerNotification(
            type: 'comment',
            targetUserId: postOwnerUid,
            title: 'New Comment',
            body: '$name commented: $text',
            customData: {
              'commenterId': uid,
              'postId': postId,
              'commentId': commentId,
            },
          );
        }
      } else {
        res = "Please enter text";
      }
    } catch (err) {
      res = err.toString();
      if (kDebugMode) {}
    }
    return res;
  }

  // Share a post through chat
  Future<String> sharePostThroughChat({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String postId,
    required String postImageUrl,
    required String postCaption,
    required String postOwnerId,
    String? postOwnerUsername,
    String? postOwnerPhotoUrl,
  }) async {
    try {
      // Use original caption without modifications
      final safeCaption = postCaption;
      final safeOwnerUsername = postOwnerUsername ?? 'Unknown User';
      final safeOwnerPhotoUrl = postOwnerPhotoUrl ?? '';

      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      await messageRef.set({
        'senderId': senderId,
        'receiverId': receiverId,
        'message': safeCaption,
        'type': 'post',
        'postId': postId,
        'postImageUrl': postImageUrl,
        'postCaption': safeCaption,
        'postOwnerId': postOwnerId,
        'postOwnerUsername': safeOwnerUsername,
        'postOwnerPhotoUrl': safeOwnerPhotoUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isDirectOwner': senderId == postOwnerId,
      });

      // Create preview without "Post:" prefix
      final previewText = safeCaption.length > 20
          ? '${safeCaption.substring(0, 17)}...'
          : safeCaption;

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': previewText,
        'lastMessageType': 'post',
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      return 'success';
    } catch (err) {
      return err.toString();
    }
  }

  // Post views
  Future<void> recordPostView(String postId, String userId) async {
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('views')
          .doc(userId)
          .set({
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  // For post share
  Future<bool> checkMutualBlock(String userId1, String userId2) async {
    final user1Doc = await _firestore.collection('users').doc(userId1).get();
    final user2Doc = await _firestore.collection('users').doc(userId2).get();

    final user1Blocked = List<String>.from(user1Doc['blockedUsers'] ?? []);
    final user2Blocked = List<String>.from(user2Doc['blockedUsers'] ?? []);

    return user1Blocked.contains(userId2) && user2Blocked.contains(userId1);
  }

  // Delete a post
  Future<String> deletePost(String postId) async {
    String res = "Some error occurred";
    try {
      // 1. Get the post data first
      DocumentSnapshot postSnapshot =
          await _firestore.collection('posts').doc(postId).get();
      if (!postSnapshot.exists) {
        throw Exception('Post does not exist');
      }

      // 2. Extract the image URL
      String imageUrl = postSnapshot['postUrl'];

      // 3. Delete the image from Storage
      await StorageMethods().deleteImage(imageUrl);

      // 4. Delete the Firestore document
      await _firestore.collection('posts').doc(postId).delete();

      res = 'success';
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  // Report a post
  Future<String> reportPost(String postId, String reason) async {
    String res = "Some error occurred";
    try {
      await _firestore.collection('reports').add({
        'postId': postId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'post',
      });
      res = 'success';
    } catch (err) {
      res = err.toString();
    }
    return res;
  }
}
