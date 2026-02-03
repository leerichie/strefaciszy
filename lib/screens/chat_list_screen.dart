// screens/chat_list_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/models/chat.dart';
import 'package:strefa_ciszy/screens/_user_picker_sheet.dart';
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
    _loadAdminFlag();
  }

  bool _isAdmin = false;
  bool _adminChecked = false;

  bool _isAdminFromUserDoc(Map<String, dynamic> data) {
    final v1 = data['isAdmin'];
    final v2 = data['is_admin'];
    final role = (data['role'] ?? '').toString().toLowerCase();
    return v1 == true || v2 == true || role == 'admin';
  }

  Future<bool> _isCurrentUserAdmin(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!snap.exists) return false;
    return _isAdminFromUserDoc(snap.data() ?? {});
  }

  Future<void> _loadAdminFlag() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    bool isAdmin = false;

    try {
      await ChatService.instance.joinGlobalChat(uid);
      isAdmin = await _isCurrentUserAdmin(uid);
    } catch (e, st) {
      debugPrint('ChatListScreen: admin load failed: $e');
      debugPrint('$st');
    }

    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _adminChecked = true;
    });
  }

  int _readUnreadCount(Chat c, String uid) {
    final v = c.rawData['unread_$uid'];
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return 0;
  }

  Widget? _buildUnreadBadge(Chat c) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final unread = _readUnreadCount(c, uid);
    if (unread <= 0) return null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        unread > 99 ? '99+' : unread.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _showCreateMenu({
    required String myUid,
    required bool isAdmin,
  }) async {
    if (!isAdmin) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Zacznij nowy czat')),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1),
                title: const Text('Prywatna'),
                onTap: () => Navigator.pop(context, 'dm'),
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: const Text('Grupa'),
                onTap: () => Navigator.pop(context, 'group'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'dm') {
      await _createDmFlow(myUid);
    } else if (action == 'group') {
      await _createGroupFlow(myUid);
    }
  }

  Future<bool> _confirmDeleteChat(String title) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Skasować czat?'),
        content: Text('Na pewno usunąć: "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _createDmFlow(String myUid) async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const UserPickerSheet(),
    );

    if (!mounted || picked == null) return;

    final otherUid = (picked['uid'] ?? '').toString();
    if (otherUid.isEmpty) return;

    final dmId = await ChatService.instance.getOrCreateDm(
      uidA: myUid,
      uidB: otherUid,
    );

    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChatThreadScreen(chatId: dmId)));
  }

  Future<void> _createGroupFlow(String myUid) async {
    final title = await _askGroupTitle();
    if (!mounted || title == null) return;

    final pickedUids = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GroupMembersPickerSheet(myUid: myUid),
    );

    if (!mounted || pickedUids == null || pickedUids.isEmpty) return;

    final groupId = await ChatService.instance.createGroupChat(
      title: title,
      createdBy: myUid,
      memberUids: pickedUids,
    );

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatThreadScreen(chatId: groupId)),
    );
  }

  Future<String?> _askGroupTitle() async {
    final c = TextEditingController();

    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nazwa grupy'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Np. Zebranie / Klient / Projekty',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Utwórz'),
          ),
        ],
      ),
    );

    final t = res?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  Widget _dmTitle(String myUid, Chat c) {
    final otherUid = c.members.firstWhere((m) => m != myUid, orElse: () => '');

    if (otherUid.isEmpty) return const Text('Prywatny chat');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUid)
          .snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data();
        final name = (data?['name'] as String?)?.trim();

        return Text(
          (name != null && name.isNotEmpty) ? name : 'Prywatny chat',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  Widget _globalUnreadBadge(String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(ChatService.globalChatId)
          .snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data();
        final v = data?['unread_$uid'];
        final unread = (v is num) ? v.toInt() : 0;

        if (unread <= 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            unread > 99 ? '99+' : unread.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    print('FAB gate: uid=$uid adminChecked=$_adminChecked isAdmin=$_isAdmin');

    return AppScaffold(
      floatingActionButton: (uid == null || !_adminChecked || !_isAdmin)
          ? null
          : FloatingActionButton(
              onPressed: () => _showCreateMenu(myUid: uid, isAdmin: true),
              child: const Icon(Icons.add),
            ),

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
                  trailing: uid == null ? null : _globalUnreadBadge(uid),
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
                              .where((d) => d.id != ChatService.globalChatId)
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
                                  title: c.type == 'dm'
                                      ? _dmTitle(uid, c)
                                      : Text(title),
                                  subtitle: Text(
                                    c.lastMessageText?.trim().isNotEmpty == true
                                        ? c.lastMessageText!.trim()
                                        : '—',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_buildUnreadBadge(c) != null)
                                        _buildUnreadBadge(c)!,

                                      if (_isAdmin &&
                                          c.id != ChatService.globalChatId)
                                        IconButton(
                                          tooltip: 'Usuń czat',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () async {
                                            final ok = await _confirmDeleteChat(
                                              title,
                                            );
                                            if (!ok) return;

                                            try {
                                              await ChatService.instance
                                                  .deleteChat(c.id);
                                            } catch (e) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Błąd usuwania: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                    ],
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

class _GroupMembersPickerSheet extends StatefulWidget {
  final String myUid;

  const _GroupMembersPickerSheet({required this.myUid});

  @override
  State<_GroupMembersPickerSheet> createState() =>
      _GroupMembersPickerSheetState();
}

class _GroupMembersPickerSheetState extends State<_GroupMembersPickerSheet> {
  final Set<String> _selected = {};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: SizedBox(
          height: 460,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: 8,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Wybierz osoby do grupy',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Szukaj...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .snapshots(),
                    builder: (_, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snap.data?.docs ?? [];
                      final items =
                          docs
                              .where((d) => d.id != widget.myUid)
                              .map((d) {
                                final data = d.data();
                                final name =
                                    (data['name'] as String?)?.trim() ?? '';
                                final first = name.isNotEmpty
                                    ? name.split(' ').first
                                    : 'User';
                                return {
                                  'uid': d.id,
                                  'full': name.isEmpty ? first : name,
                                };
                              })
                              .where((u) {
                                if (_q.isEmpty) return true;
                                final full = (u['full'] as String)
                                    .toLowerCase();
                                return full.contains(_q);
                              })
                              .toList()
                            ..sort(
                              (a, b) => (a['full'] as String).compareTo(
                                (b['full'] as String),
                              ),
                            );

                      if (items.isEmpty) {
                        return const Center(child: Text('Brak wyników.'));
                      }

                      return ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final u = items[i];
                          final uid = u['uid'] as String;
                          final full = u['full'] as String;
                          final checked = _selected.contains(uid);

                          return CheckboxListTile(
                            value: checked,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(uid);
                                } else {
                                  _selected.remove(uid);
                                }
                              });
                            },
                            title: Text(full),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: Text('Dodaj (${_selected.length})'),
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selected.toList()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
