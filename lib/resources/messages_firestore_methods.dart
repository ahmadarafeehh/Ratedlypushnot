import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:Ratedly/services/notification_service.dart'; // Add this import

class FireStoreMessagesMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService =
      NotificationService(); // Add this

  // Send a message
  Future<String> sendMessage(
      String chatId, String senderId, String receiverId, String message) async {
    try {
      // Send message
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

      // Update chat last message
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': message,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Trigger notification
      await _notificationService.showMessageNotification(
        senderId: senderId,
        senderUsername: await _getUsername(senderId), // Implement this
        message: message,
        chatId: chatId,
        targetUserId: receiverId,
      );

      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  // Helper to get username
  Future<String> _getUsername(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc['username'] ?? 'Unknown';
  }

  // Get messages from a chat
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Create or retrieve a chat ID between two users
  Future<String> getOrCreateChat(String user1, String user2) async {
    try {
      QuerySnapshot chatQuery = await _firestore
          .collection('chats')
          .where('participants', arrayContains: user1)
          .get();

      for (var doc in chatQuery.docs) {
        List participants = doc['participants'];
        if (participants.contains(user2)) {
          return doc.id;
        }
      }

      // If no chat exists, create a new one
      String newChatId = const Uuid().v1();
      await _firestore.collection('chats').doc(newChatId).set({
        'chatId': newChatId,
        'participants': [user1, user2],
        'lastMessage': "",
        'lastUpdated': DateTime.now(),
      });
      return newChatId;
    } catch (err) {
      return err.toString();
    }
  }

  // Unread messages (total count)
  Stream<int> getTotalUnreadCount(String currentUserId) {
    return _firestore
        .collectionGroup('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isNotEmpty) {}
      return snapshot.docs.length;
    }).handleError((error) {
      return 0;
    });
  }

  // Unread count for a specific chat
  Stream<int> getUnreadCount(String chatId, String currentUserId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String currentUserId) async {
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in messages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // In FireStoreMessagesMethods
  Future<void> deleteAllUserMessages(String uid) async {
    // Get all chats where user is a participant
    final chatsQuery = await _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();

    final batch = _firestore.batch();

    for (final chatDoc in chatsQuery.docs) {
      // Delete messages in each chat
      final messages = await chatDoc.reference.collection('messages').get();
      for (final messageDoc in messages.docs) {
        batch.delete(messageDoc.reference);
      }
      // Delete chat document
      batch.delete(chatDoc.reference);
    }

    await batch.commit();
  }
}
