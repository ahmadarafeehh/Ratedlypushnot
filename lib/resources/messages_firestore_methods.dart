import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:Ratedly/services/notification_service.dart';

class FireStoreMessagesMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Send a chat message, send FCM push, and log it in “Push Not”.
  Future<String> sendMessage(
    String chatId,
    String senderId,
    String receiverId,
    String message,
  ) async {
    try {
      // 1) Add the message to the chat subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'message': message,
        'senderId': senderId,
        'receiverId': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // 2) Update the parent chat’s lastMessage & lastUpdated
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': message,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // 3) Trigger an FCM push via your Cloud Function pipeline
      final senderUsername = await _getUsername(senderId);
      await _notificationService.triggerServerNotification(
        type: 'message',
        targetUserId: receiverId,
        title: senderUsername,
        body: message,
        customData: {
          'senderId': senderId,
          'chatId': chatId,
        },
      );

      // 4) Record the push notification in “Push Not” so the Cloud Function fires
      await _firestore.collection('Push Not').add({
        'type': 'message',
        'targetUserId': receiverId,
        'title': senderUsername,
        'body': message,
        'customData': {
          'senderId': senderId,
          'chatId': chatId,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });

      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  /// Helper to fetch a user’s username
  Future<String> _getUsername(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data()?['username'] as String? ?? 'Unknown';
  }

  /// Stream all messages in a chat, sorted ascending by timestamp
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Find or create a one‑to‑one chat between two users
  Future<String> getOrCreateChat(String user1, String user2) async {
    try {
      final chatQuery = await _firestore
          .collection('chats')
          .where('participants', arrayContains: user1)
          .get();

      for (var doc in chatQuery.docs) {
        final participants = List<String>.from(doc['participants']);
        if (participants.contains(user2)) {
          return doc.id;
        }
      }

      final newChatId = const Uuid().v1();
      await _firestore.collection('chats').doc(newChatId).set({
        'chatId': newChatId,
        'participants': [user1, user2],
        'lastMessage': '',
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return newChatId;
    } catch (e) {
      return e.toString();
    }
  }

  /// Total unread messages across all chats
  Stream<int> getTotalUnreadCount(String currentUserId) {
    return _firestore
        .collectionGroup('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length)
        .handleError((_) => 0);
  }

  /// Unread messages for a specific chat
  Stream<int> getUnreadCount(String chatId, String currentUserId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Mark all messages in a chat as read
  Future<void> markMessagesAsRead(
    String chatId,
    String currentUserId,
  ) async {
    final unreadSnaps = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in unreadSnaps.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Delete all chats & messages for a user
  Future<void> deleteAllUserMessages(String uid) async {
    final chatsQuery = await _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();

    final batch = _firestore.batch();
    for (final chatDoc in chatsQuery.docs) {
      final messages = await chatDoc.reference.collection('messages').get();
      for (final msg in messages.docs) {
        batch.delete(msg.reference);
      }
      batch.delete(chatDoc.reference);
    }
    await batch.commit();
  }
}
