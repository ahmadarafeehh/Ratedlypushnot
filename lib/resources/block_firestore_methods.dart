import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Ratedly/resources/messages_firestore_methods.dart';

class FirestoreBlockMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FireStoreMessagesMethods _messagesMethods = FireStoreMessagesMethods();

  Future<void> blockUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      final usersRef = _firestore.collection('users');
      final batch = _firestore.batch();
      final currentUserRef = usersRef.doc(currentUserId);
      final targetUserRef = usersRef.doc(targetUserId); // Add this back

      // Add blocking only to current user's list
      batch.update(currentUserRef, {
        'blockedUsers': FieldValue.arrayUnion([targetUserId]),
      });

      // Keep targetUserRef for data access but don't update their blocked list
      final currentUserSnap = await currentUserRef.get();
      final targetUserSnap = await targetUserRef.get();

      // Remove follow relationships
      _removeFollowRelationships(
        currentUserSnap: currentUserSnap,
        targetUserSnap: targetUserSnap,
        currentUserId: currentUserId,
        targetUserId: targetUserId,
        batch: batch,
      );

      // Delete notifications
      await _deleteMutualNotifications(currentUserId, targetUserId, batch);

      // Remove profile ratings
      await _removeMutualProfileRatings(currentUserId, targetUserId, batch);

      // Remove post ratings
      await _removeMutualPostRatings(currentUserId, targetUserId, batch);

      // Delete comments
      await _deleteMutualComments(currentUserId, targetUserId, batch);

      // Delete chat history
      final chatId =
          await _messagesMethods.getOrCreateChat(currentUserId, targetUserId);
      await _deleteChatMessages(chatId, batch);

      await batch.commit();
    } catch (e) {
      throw Exception("Block failed: $e");
    }
  }

  Future<void> unblockUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    final currentUserRef =
        FirebaseFirestore.instance.collection('users').doc(currentUserId);

    // Remove targetUserId from current user's blocked list
    batch.update(currentUserRef, {
      'blockedUsers': FieldValue.arrayRemove([targetUserId])
    });

    await batch.commit();
  }

  Future<bool> isUserBlocked({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      final targetUserDoc =
          await _firestore.collection('users').doc(targetUserId).get();
      final data = targetUserDoc.data();

      // Handle missing blockedUsers field with default empty list
      final blockedUsers = List<String>.from(data?['blockedUsers'] ?? []);
      return blockedUsers.contains(currentUserId);
    } catch (e) {
      return false;
    }
  }

  void _removeFollowRelationships({
    required DocumentSnapshot currentUserSnap,
    required DocumentSnapshot targetUserSnap,
    required String currentUserId,
    required String targetUserId,
    required WriteBatch batch,
  }) {
    // Corrected typo: 'followers' instead of 'followers'

    // Remove target user from current user's following
    final currentFollowing = (currentUserSnap['following'] as List?) ?? [];
    final targetFollowEntry = currentFollowing.firstWhere(
      (entry) => entry['userId'] == targetUserId,
      orElse: () => null,
    );

    if (targetFollowEntry != null) {
      final Map<String, dynamic> exactEntry = {
        'userId': targetUserId,
        'timestamp': targetFollowEntry['timestamp']
      };
      batch.update(currentUserSnap.reference, {
        'following': FieldValue.arrayRemove([exactEntry])
      });
    }

    // Remove current user from target user's followers
    final targetFollowers = (targetUserSnap['followers'] as List?) ?? [];
    final currentFollowerEntry = targetFollowers.firstWhere(
      (entry) => entry['userId'] == currentUserId,
      orElse: () => null,
    );

    if (currentFollowerEntry != null) {
      batch.update(targetUserSnap.reference, {
        'followers': FieldValue.arrayRemove([currentFollowerEntry])
      });
    }

    // Get timestamps from the actual entries
    final currentUserFollowingTimestamp = targetFollowEntry?['timestamp'];
    final targetUserFollowersTimestamp = currentFollowerEntry?['timestamp'];

    // Direct mutual follow removal with null checks
    final currentUserUpdate = <String, dynamic>{};
    final targetUserUpdate = <String, dynamic>{};

    if (currentUserFollowingTimestamp != null) {
      currentUserUpdate['following'] = FieldValue.arrayRemove([
        {'userId': targetUserId, 'timestamp': currentUserFollowingTimestamp}
      ]);
    }

    if (targetUserFollowersTimestamp != null) {
      // Corrected typo: 'followers' instead of 'followers'
      currentUserUpdate['followers'] = FieldValue.arrayRemove([
        {'userId': targetUserId, 'timestamp': targetUserFollowersTimestamp}
      ]);
    }

    if (currentUserFollowingTimestamp != null) {
      // Corrected typo: 'followers' instead of 'followers'
      targetUserUpdate['followers'] = FieldValue.arrayRemove([
        {'userId': currentUserId, 'timestamp': currentUserFollowingTimestamp}
      ]);
    }

    if (targetUserFollowersTimestamp != null) {
      targetUserUpdate['following'] = FieldValue.arrayRemove([
        {'userId': currentUserId, 'timestamp': targetUserFollowersTimestamp}
      ]);
    }

    if (currentUserUpdate.isNotEmpty) {
      batch.update(currentUserSnap.reference, currentUserUpdate);
    }

    if (targetUserUpdate.isNotEmpty) {
      batch.update(targetUserSnap.reference, targetUserUpdate);
    }

    // Additional code from old implementation to handle all follow directions
    final usersRef = _firestore.collection('users');

    // Remove current user's followers entries where target is following current
    final currentUserFollowers = (currentUserSnap['followers'] as List?) ?? [];
    for (var follower in currentUserFollowers) {
      if (follower['userId'] == targetUserId) {
        // Remove current user from target's following
        final targetFollowingRef = usersRef.doc(targetUserId);
        batch.update(targetFollowingRef, {
          'following': FieldValue.arrayRemove([
            {'userId': currentUserId, 'timestamp': follower['timestamp']}
          ])
        });
        // Remove target user from current's followers
        batch.update(currentUserSnap.reference, {
          'followers': FieldValue.arrayRemove([follower])
        });
      }
    }

    // Remove current user's following entries where current is following target
    final currentUserFollowing = (currentUserSnap['following'] as List?) ?? [];
    for (var followed in currentUserFollowing) {
      if (followed['userId'] == targetUserId) {
        // Remove current user from target's followers
        final targetFollowersRef = usersRef.doc(targetUserId);
        batch.update(targetFollowersRef, {
          'followers': FieldValue.arrayRemove([
            {'userId': currentUserId, 'timestamp': followed['timestamp']}
          ])
        });
        // Remove target user from current's following
        batch.update(currentUserSnap.reference, {
          'following': FieldValue.arrayRemove([followed])
        });
      }
    }

    // Remove target user's followers entries where current is following target
    final targetUserFollowers = (targetUserSnap['followers'] as List?) ?? [];
    for (var follower in targetUserFollowers) {
      if (follower['userId'] == currentUserId) {
        // Remove target user from current's following
        final currentFollowingRef = usersRef.doc(currentUserId);
        batch.update(currentFollowingRef, {
          'following': FieldValue.arrayRemove([
            {'userId': targetUserId, 'timestamp': follower['timestamp']}
          ])
        });
        // Remove current user from target's followers
        batch.update(targetUserSnap.reference, {
          'followers': FieldValue.arrayRemove([follower])
        });
      }
    }

    // Remove target user's following entries where target is following current
    final targetUserFollowing = (targetUserSnap['following'] as List?) ?? [];
    for (var followed in targetUserFollowing) {
      if (followed['userId'] == currentUserId) {
        // Remove target user from current's followers
        final currentFollowersRef = usersRef.doc(currentUserId);
        batch.update(currentFollowersRef, {
          'followers': FieldValue.arrayRemove([
            {'userId': targetUserId, 'timestamp': followed['timestamp']}
          ])
        });
        // Remove current user from target's following
        batch.update(targetUserSnap.reference, {
          'following': FieldValue.arrayRemove([followed])
        });
      }
    }
  }

  Future<bool> isBlockInitiator({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final data = currentUserDoc.data(); // Get document data
      final blockedUsers = List<String>.from(
          data?['blockedUsers'] ?? []); // Access field from data
      return blockedUsers.contains(targetUserId);
    } catch (e) {
      return false;
    }
  }

  Future<void> _deleteMutualNotifications(
    String currentUserId,
    String targetUserId,
    WriteBatch batch,
  ) async {
    const notificationTypes = [
      'follow',
      'user_rating',
      'post_rating',
      'comment',
      'message',
      'comment_like', // Added
      'follow_request', // Added
      'follow_request_accepted' // Added
    ];

    for (final type in notificationTypes) {
      Query query =
          _firestore.collection('notifications').where('type', isEqualTo: type);

      switch (type) {
        case 'follow':
          query = query.where('followerId', whereIn: [
            currentUserId,
            targetUserId
          ]).where('targetUserId', whereIn: [currentUserId, targetUserId]);
          break;
        case 'user_rating':
          query = query.where('raterUserId', whereIn: [
            currentUserId,
            targetUserId
          ]).where('targetUserId', whereIn: [currentUserId, targetUserId]);
          break;
        case 'post_rating':
          query = query.where('raterUid', whereIn: [
            currentUserId,
            targetUserId
          ]).where('targetUserId', whereIn: [currentUserId, targetUserId]);
          break;
        case 'comment':
          query = query.where('commenterUid', whereIn: [
            currentUserId,
            targetUserId
          ]).where('targetUserId', whereIn: [currentUserId, targetUserId]);
          break;
        case 'message':
          query = query.where('senderId', whereIn: [
            currentUserId,
            targetUserId
          ]).where('receiverId', whereIn: [currentUserId, targetUserId]);
          break;
        // New cases for additional notification types
        case 'comment_like':
          query = query.where('likerUid', whereIn: [
            currentUserId,
            targetUserId
          ]).where('targetUserId', whereIn: [currentUserId, targetUserId]);
          break;
        case 'follow_request':
          query = query.where('requesterId', whereIn: [
            currentUserId,
            targetUserId
          ]).where('targetUserId', whereIn: [currentUserId, targetUserId]);
          break;
        case 'follow_request_accepted':
          query = query.where('senderId', whereIn: [
            currentUserId,
            targetUserId
          ]).where('targetUserId', whereIn: [currentUserId, targetUserId]);
          break;
      }

      final snapshot = await query.get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
    }
  }

  Future<void> _removeMutualProfileRatings(
    String currentUserId,
    String targetUserId,
    WriteBatch batch,
  ) async {
    // Current user's ratings on target
    final targetUserRatingsSnap =
        await _firestore.collection('users').doc(targetUserId).get();
    final targetRatings = (targetUserRatingsSnap['ratings'] as List? ?? [])
        .where((r) => r['raterUserId'] != currentUserId)
        .toList();
    if (targetRatings.length <
        (targetUserRatingsSnap['ratings']?.length ?? 0)) {
      batch.update(targetUserRatingsSnap.reference, {'ratings': targetRatings});
    }

    // Target's ratings on current user
    final currentUserRatingsSnap =
        await _firestore.collection('users').doc(currentUserId).get();
    final currentRatings = (currentUserRatingsSnap['ratings'] as List? ?? [])
        .where((r) => r['raterUserId'] != targetUserId)
        .toList();
    if (currentRatings.length <
        (currentUserRatingsSnap['ratings']?.length ?? 0)) {
      batch.update(
          currentUserRatingsSnap.reference, {'ratings': currentRatings});
    }
  }

  Future<void> _removeMutualPostRatings(
    String currentUserId,
    String targetUserId,
    WriteBatch batch,
  ) async {
    // Current user's ratings on target's posts
    final targetPosts = await _firestore
        .collection('posts')
        .where('uid', isEqualTo: targetUserId)
        .get();
    for (final post in targetPosts.docs) {
      final filtered = (post['rate'] as List? ?? [])
          .where((r) => r['userId'] != currentUserId)
          .toList();
      if (filtered.length < (post['rate']?.length ?? 0)) {
        batch.update(post.reference, {'rate': filtered});
      }
    }

    // Target's ratings on current user's posts
    final currentPosts = await _firestore
        .collection('posts')
        .where('uid', isEqualTo: currentUserId)
        .get();
    for (final post in currentPosts.docs) {
      final filtered = (post['rate'] as List? ?? [])
          .where((r) => r['userId'] != targetUserId)
          .toList();
      if (filtered.length < (post['rate']?.length ?? 0)) {
        batch.update(post.reference, {'rate': filtered});
      }
    }
  }

  Future<void> _deleteMutualComments(
    String currentUserId,
    String targetUserId,
    WriteBatch batch,
  ) async {
    // Delete current user's comments on target's posts
    final targetPosts = await _firestore
        .collection('posts')
        .where('uid', isEqualTo: targetUserId)
        .get();
    for (final post in targetPosts.docs) {
      final comments = await post.reference
          .collection('comments')
          .where('uid', isEqualTo: currentUserId)
          .get();
      for (final comment in comments.docs) {
        batch.delete(comment.reference);
      }
    }

    // Delete target's comments on current user's posts
    final currentPosts = await _firestore
        .collection('posts')
        .where('uid', isEqualTo: currentUserId)
        .get();
    for (final post in currentPosts.docs) {
      final comments = await post.reference
          .collection('comments')
          .where('uid', isEqualTo: targetUserId)
          .get();
      for (final comment in comments.docs) {
        batch.delete(comment.reference);
      }
    }
  }

  Future<void> _deleteChatMessages(String chatId, WriteBatch batch) async {
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_firestore.collection('chats').doc(chatId));
  }

  Future<List<String>> getBlockedUsers(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      // Check if document exists first
      if (!doc.exists) return [];

      // Safely access data with null coalescing
      final data = doc.data() ?? {};

      // Handle missing field with default empty list
      return List<String>.from(data['blockedUsers'] ?? []);
    } catch (e) {
      return [];
    }
  }

  // In FirestoreBlockMethods
  Future<bool> isMutuallyBlocked(String userId1, String userId2) async {
    final results = await Future.wait([
      isUserBlocked(currentUserId: userId1, targetUserId: userId2),
      isUserBlocked(currentUserId: userId2, targetUserId: userId1)
    ]);
    return results[0] || results[1];
  }
}
