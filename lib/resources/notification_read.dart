import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static Future<void> markNotificationsAsRead(String userId) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('notifications')
          .where('targetUserId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (query.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }
}
