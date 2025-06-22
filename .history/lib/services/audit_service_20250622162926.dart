// lib/services/audit_service.dart

class AuditService {
  AuditService._();

  /// Writes a new entry into the top‐level "audit_logs" collection.
  /// `details` can be any JSON‐serializable map of extra fields.
  static Future<void> logAction({
    required String action,
    Map<String, dynamic>? details,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = user.displayName ?? user.email ?? user.uid;
    final col = FirebaseFirestore.instance.collection('audit_logs');
    await col.add({
      'userId': user.uid,
      'userName': name,
      'action': action,
      'details': details, // <-- store map directly
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
