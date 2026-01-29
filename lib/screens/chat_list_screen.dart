// screens/chat_list_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/models/chat.dart';
import 'package:strefa_ciszy/screens/chat_thread_screen.dart';
import 'package:strefa_ciszy/services/chat_service.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    ChatService.instance.ensureGlobalChat();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return AppScaffold(
      title: 'Chat',
      showBackOnMobile: true,
      showPersistentDrawerOnWeb: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // const Text(
              //   'Chat',
              //   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              // ),
              // const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: Image.asset(
                    'assets/favicon/Icon-512.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  title: const Text('Strefa Ciszy'),
                  subtitle: const Text('ogolne chat'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChatThreadScreen(
                        chatId: ChatService.globalChatId,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: uid == null
                    ? const Center(child: Text('Nie jesteś zalogowany.'))
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: ChatService.instance.watchChatsForUser(uid),
                        builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final docs = snap.data?.docs ?? [];
                          final chats = docs
                              .map((d) => Chat.fromDoc(d))
                              .toList();

                          return ListView.builder(
                            itemCount: chats.length,
                            itemBuilder: (_, i) {
                              final c = chats[i];
                              final title = c.title?.trim().isNotEmpty == true
                                  ? c.title!.trim()
                                  : (c.type == 'dm'
                                        ? 'Wiadomość prywatna'
                                        : 'Grupa');

                              return Card(
                                child: ListTile(
                                  leading: Icon(
                                    c.type == 'dm' ? Icons.person : Icons.group,
                                  ),
                                  title: Text(title),
                                  subtitle: Text(
                                    c.lastMessageText?.trim().isNotEmpty == true
                                        ? c.lastMessageText!.trim()
                                        : '—',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ChatThreadScreen(chatId: c.id),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
