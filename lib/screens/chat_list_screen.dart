// screens/chat_list_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/models/chat.dart';
import 'package:strefa_ciszy/screens/_user_picker_sheet.dart';
import 'package:strefa_ciszy/screens/chat_thread_screen.dart';
import 'package:strefa_ciszy/services/chat_service.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';

class _AvChatPalette {
  static const headlineFont = 'Bose-Headline (Bold)';
  static const bodyFont = 'Bose (Regular)';
  static const graphite = Color(0xFF263238);
  static const control = Color(0xFF202124);
  static const controlAlt = Color(0xFF4A5156);
  static const headerStart = Color(0xFFFFFFFF);
  static const headerMid = Color(0xFFE9ECEF);
  static const headerEnd = Color(0xFFA9C6D8);
  static const panel = Color(0xFFF4F6F7);
  static const panelAlt = Color(0xFFE8EEF1);
  static const surface = Colors.white;
  static const line = Color(0xFFD4DCE0);
  static const text = Color(0xFF1E2B2F);
  static const muted = Color(0xFF607176);
  static const bubbleTop = Color(0xFF2574A9);
  static const cyan = Color(0xFF0097A7);
  static const cyanDark = Color(0xFF006D78);
  static const amber = Color(0xFFFFD200);
  static const danger = Color(0xFFE04747);
}

class _ChatHeaderGradient extends StatelessWidget {
  const _ChatHeaderGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _AvChatPalette.headerStart,
            _AvChatPalette.headerMid,
            _AvChatPalette.headerEnd,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }
}

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

    return _UnreadBadge(count: unread);
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatChatTime(DateTime? dt) {
    if (dt == null || dt.year <= 1970) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(d).inDays;
    if (diffDays == 0) return '${_two(dt.hour)}:${_two(dt.minute)}';
    if (diffDays == 1) return 'wczoraj';
    return '${_two(dt.day)}.${_two(dt.month)}';
  }

  Widget _chatAvatar({required IconData icon, required List<Color> colors}) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }

  Widget _chatTile({
    required Widget title,
    required String subtitle,
    required Widget leading,
    required VoidCallback onTap,
    Widget? trailing,
    Widget? adminAction,
    String timeLabel = '',
  }) {
    final meta = <Widget>[
      if (timeLabel.isNotEmpty)
        Text(
          timeLabel,
          style: const TextStyle(fontSize: 12, color: _AvChatPalette.muted),
        ),
      if (trailing != null) trailing,
      if (adminAction != null) adminAction,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _AvChatPalette.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DefaultTextStyle(
                        style: const TextStyle(
                          color: _AvChatPalette.text,
                          fontSize: 15,
                          fontFamily: _AvChatPalette.headlineFont,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child: title,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _AvChatPalette.muted,
                          fontSize: 13,
                          fontFamily: _AvChatPalette.bodyFont,
                        ),
                      ),
                    ],
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final item in meta) ...[
                        item,
                        if (item != meta.last) const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gradientCircleAction({
    required String tooltip,
    required Icon icon,
    required VoidCallback onPressed,
    required double size,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_AvChatPalette.control, _AvChatPalette.controlAlt],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Icon(icon.icon, size: icon.size, color: Colors.white),
            ),
          ),
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
      backgroundColor: _AvChatPalette.surface,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ZACZNIJ NOWY CZAT',
                    style: TextStyle(
                      fontFamily: _AvChatPalette.headlineFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 1.2,
                      color: _AvChatPalette.muted,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1, color: _AvChatPalette.bubbleTop),
                title: const Text('Prywatna', style: TextStyle(fontFamily: _AvChatPalette.bodyFont, color: _AvChatPalette.text)),
                onTap: () => Navigator.pop(context, 'dm'),
              ),
              ListTile(
                leading: const Icon(Icons.group_add, color: _AvChatPalette.bubbleTop),
                title: const Text('Grupa', style: TextStyle(fontFamily: _AvChatPalette.bodyFont, color: _AvChatPalette.text)),
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
        backgroundColor: _AvChatPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          fontFamily: _AvChatPalette.headlineFont,
          fontWeight: FontWeight.w800,
          color: _AvChatPalette.text,
          fontSize: 17,
          letterSpacing: 0,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: _AvChatPalette.bodyFont,
          color: _AvChatPalette.muted,
          fontSize: 14,
        ),
        title: const Text('Skasować czat?'),
        content: Text('Na pewno usunąć: "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: _AvChatPalette.muted),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AvChatPalette.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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
        backgroundColor: _AvChatPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          fontFamily: _AvChatPalette.headlineFont,
          fontWeight: FontWeight.w800,
          color: _AvChatPalette.text,
          fontSize: 17,
          letterSpacing: 0,
        ),
        title: const Text('Nazwa grupy'),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(fontFamily: _AvChatPalette.bodyFont, color: _AvChatPalette.text),
          decoration: InputDecoration(
            hintText: 'Np. Zebranie / Klient / Projekty',
            hintStyle: const TextStyle(fontFamily: _AvChatPalette.bodyFont, color: _AvChatPalette.muted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _AvChatPalette.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _AvChatPalette.bubbleTop, width: 1.5),
            ),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _AvChatPalette.muted),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AvChatPalette.bubbleTop,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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

        return _UnreadBadge(count: unread);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Theme(
      data: Theme.of(context).copyWith(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: _AvChatPalette.text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: _AvChatPalette.text,
            fontSize: 19,
            fontFamily: _AvChatPalette.headlineFont,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: _AvChatPalette.cyan,
          secondary: _AvChatPalette.cyanDark,
        ),
      ),
      child: AppScaffold(
        floatingActionButton: (uid == null || !_adminChecked || !_isAdmin)
            ? null
            : _gradientCircleAction(
                tooltip: 'Nowy czat',
                onPressed: () => _showCreateMenu(myUid: uid, isAdmin: true),
                icon: const Icon(Icons.add, size: 26),
                size: 56,
              ),

        title: 'Chat',
        titleWidget: const Text('CHAT'),
        centreTitle: true,
        showBackOnMobile: true,
        showBackOnWeb: true,
        showPersistentDrawerOnWeb: true,
        appBarFlexibleSpace: const _ChatHeaderGradient(),

        body: SafeArea(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_AvChatPalette.panel, _AvChatPalette.panelAlt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
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
                  _chatTile(
                    leading: Container(
                      width: 46,
                      height: 46,
                      padding: const EdgeInsets.all(9),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            _AvChatPalette.graphite,
                            _AvChatPalette.cyanDark,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Image.asset(
                        'assets/favicon/Icon-512.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    title: const Text('Strefa Ciszy'),
                    subtitle: 'Czat ogólny',
                    trailing: uid == null ? null : _globalUnreadBadge(uid),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChatThreadScreen(
                          chatId: ChatService.globalChatId,
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
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final docs = snap.data?.docs ?? [];

                              final chats = docs
                                  .where(
                                    (d) => d.id != ChatService.globalChatId,
                                  )
                                  .map((d) => Chat.fromDoc(d))
                                  .toList();

                              return ListView.builder(
                                itemCount: chats.length,
                                itemBuilder: (_, i) {
                                  final c = chats[i];
                                  final title =
                                      c.title?.trim().isNotEmpty == true
                                      ? c.title!.trim()
                                      : (c.type == 'dm'
                                            ? 'Wiadomość prywatna'
                                            : 'Grupa');

                                  final unreadBadge = _buildUnreadBadge(c);
                                  final lastText =
                                      c.lastMessageText?.trim().isNotEmpty ==
                                          true
                                      ? c.lastMessageText!.trim()
                                      : 'Brak wiadomości';

                                  return _chatTile(
                                    leading: _chatAvatar(
                                      icon: c.type == 'dm'
                                          ? Icons.person_rounded
                                          : Icons.groups_rounded,
                                      colors: c.type == 'dm'
                                          ? const [
                                              _AvChatPalette.graphite,
                                              _AvChatPalette.cyanDark,
                                            ]
                                          : const [
                                              _AvChatPalette.graphite,
                                              _AvChatPalette.amber,
                                            ],
                                    ),
                                    title: c.type == 'dm'
                                        ? _dmTitle(uid, c)
                                        : Text(title),
                                    subtitle: lastText,
                                    timeLabel: _formatChatTime(c.lastMessageAt),
                                    trailing: unreadBadge,
                                    adminAction:
                                        _isAdmin &&
                                            c.id != ChatService.globalChatId
                                        ? _gradientCircleAction(
                                            tooltip: 'Usuń czat',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                            ),
                                            size: 34,
                                            onPressed: () async {
                                              final messenger =
                                                  ScaffoldMessenger.of(context);
                                              final ok =
                                                  await _confirmDeleteChat(
                                                    title,
                                                  );
                                              if (!ok) return;

                                              try {
                                                await ChatService.instance
                                                    .deleteChat(c.id);
                                              } catch (e) {
                                                if (!mounted) return;
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Błąd usuwania: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          )
                                        : null,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ChatThreadScreen(chatId: c.id),
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
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _AvChatPalette.danger,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
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
                      style: TextStyle(
                        fontFamily: _AvChatPalette.headlineFont,
                        fontWeight: FontWeight.w800,
                        color: _AvChatPalette.text,
                        fontSize: 15,
                        letterSpacing: 0,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: _AvChatPalette.muted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                TextField(
                  style: const TextStyle(fontFamily: _AvChatPalette.bodyFont, color: _AvChatPalette.text),
                  decoration: InputDecoration(
                    hintText: 'Szukaj...',
                    hintStyle: const TextStyle(fontFamily: _AvChatPalette.bodyFont, color: _AvChatPalette.muted),
                    prefixIcon: const Icon(Icons.search, color: _AvChatPalette.muted, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _AvChatPalette.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _AvChatPalette.bubbleTop, width: 1.5),
                    ),
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
                            activeColor: _AvChatPalette.bubbleTop,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(uid);
                                } else {
                                  _selected.remove(uid);
                                }
                              });
                            },
                            title: Text(
                              full,
                              style: const TextStyle(
                                fontFamily: _AvChatPalette.bodyFont,
                                color: _AvChatPalette.text,
                              ),
                            ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AvChatPalette.bubbleTop,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _AvChatPalette.line,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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
