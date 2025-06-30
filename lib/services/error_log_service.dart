// lib/services/error_log_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ErrorLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'notification_errors';

  static Future<void> logNotificationError({
    required String type,
    required String targetUserId,
    required dynamic exception,
    StackTrace? stackTrace,
    String? additionalInfo,
  }) async {
    try {
      await _firestore.collection(_collectionName).add({
        'type': type,
        'target_user_id': targetUserId,
        'exception': exception.toString(),
        'stack_trace': stackTrace?.toString() ?? 'No stack trace',
        'additional_info': additionalInfo ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('🔥 FAILED TO LOG ERROR: $e');
    }
  }
}
