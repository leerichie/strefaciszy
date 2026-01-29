// models/chat_message.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final List<Map<String, dynamic>> attachments;
  final List<Map<String, dynamic>> mentions;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.attachments,
    required this.mentions,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['createdAt'] as Timestamp?;

    final raw = (data['attachments'] as List?) ?? const [];
    final attachments = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final rawMentions = (data['mentions'] as List?) ?? const [];
    final mentions = rawMentions
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      createdAt: ts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      attachments: attachments,
      mentions: mentions,
    );
  }
}
