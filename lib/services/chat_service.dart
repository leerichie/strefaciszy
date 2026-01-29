// services/chat_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final _db = FirebaseFirestore.instance;

  static const String globalChatId = 'global';

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    String? text,
    List<Map<String, dynamic>> attachments = const [],
    List<Map<String, dynamic>> mentions = const [],
  }) async {
    final clean = (text ?? '').trim();
    final hasText = clean.isNotEmpty;
    final hasAttachments = attachments.isNotEmpty;

    if (!hasText && !hasAttachments) return;

    final chatRef = _db.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    final preview = hasText
        ? clean
        : (attachments.length == 1
              ? '📎 Załącznik'
              : '📎 Załączniki (${attachments.length})');

    final batch = _db.batch();

    batch.set(msgRef, {
      'senderId': senderId,
      'text': hasText ? clean : '',
      'createdAt': FieldValue.serverTimestamp(),
      'mentions': <dynamic>[],
      'refs': <dynamic>[],
      'attachments': attachments,
      'mentions': mentions,
    });

    batch.update(chatRef, {
      'lastMessageText': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> ensureGlobalChat() async {
    final ref = _db.collection('chats').doc(globalChatId);
    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'type': 'global',
      'title': 'Ogólny',
      'members': <String>[],
      'createdBy': 'system',
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageText': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchChatsForUser(String uid) {
    return _db
        .collection('chats')
        .where('members', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(100)
        .snapshots();
  }

  Future<String> getOrCreateDm({
    required String uidA,
    required String uidB,
  }) async {
    final a = uidA.trim();
    final b = uidB.trim();
    if (a.isEmpty || b.isEmpty) throw Exception('Invalid uid');
    if (a == b) throw Exception('Cannot DM yourself');

    final sorted = [a, b]..sort();
    final dmKey = '${sorted[0]}_${sorted[1]}';

    final q = await _db
        .collection('chats')
        .where('type', isEqualTo: 'dm')
        .where('dmKey', isEqualTo: dmKey)
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) return q.docs.first.id;

    final ref = _db.collection('chats').doc();
    await ref.set({
      'type': 'dm',
      'title': null,
      'members': sorted,
      'dmKey': dmKey,
      'createdBy': a,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageText': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }
}
