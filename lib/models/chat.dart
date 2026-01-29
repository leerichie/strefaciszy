// models/chat.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final String type;  
  final String? title;
  final List<String> members;
  final String createdBy;
  final DateTime createdAt;
  final String? lastMessageText;
  final DateTime? lastMessageAt;

  const Chat({
    required this.id,
    required this.type,
    required this.title,
    required this.members,
    required this.createdBy,
    required this.createdAt,
    required this.lastMessageText,
    required this.lastMessageAt,
  });

  factory Chat.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAtTs = data['createdAt'] as Timestamp?;
    final lastAtTs = data['lastMessageAt'] as Timestamp?;

    return Chat(
      id: doc.id,
      type: (data['type'] as String?) ?? 'group',
      title: data['title'] as String?,
      members: List<String>.from((data['members'] as List?) ?? const []),
      createdBy: (data['createdBy'] as String?) ?? '',
      createdAt:
          (createdAtTs?.toDate()) ?? DateTime.fromMillisecondsSinceEpoch(0),
      lastMessageText: data['lastMessageText'] as String?,
      lastMessageAt: lastAtTs?.toDate(),
    );
  }
}
