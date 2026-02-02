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

    final members = <String>{uidA, uidB}.toList()..sort();

    await ref.set({
      'type': 'dm',
      'dmKey': dmKey,
      'title': null,
      'members': members,
      'createdBy': uidA,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageText': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<String> createGroupChat({
    required String title,
    required String createdBy,
    required List<String> memberUids,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw Exception('Group title required');

    final members = <String>{
      createdBy.trim(),
      ...memberUids.map((e) => e.trim()).where((e) => e.isNotEmpty),
    }.toList()..sort();

    final ref = _db.collection('chats').doc();

    await ref.set({
      'type': 'group',
      'title': cleanTitle,
      'members': members,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageText': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<void> deleteChat(String chatId) async {
    if (chatId == globalChatId) {
      throw Exception('Cannot delete global chat');
    }

    final chatRef = _db.collection('chats').doc(chatId);
    final msgs = await chatRef.collection('messages').get();
    final batch = _db.batch();

    for (final d in msgs.docs) {
      batch.delete(d.reference);
    }

    batch.delete(chatRef);

    await batch.commit();
  }
}
