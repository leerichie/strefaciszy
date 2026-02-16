// screens/chat_thread_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:strefa_ciszy/models/chat_message.dart';
import 'package:strefa_ciszy/screens/_tag_picker_sheet.dart';
import 'package:strefa_ciszy/screens/_user_picker_sheet.dart';
import 'package:strefa_ciszy/screens/customer_detail_screen.dart';
import 'package:strefa_ciszy/screens/project_editor_screen.dart';
import 'package:strefa_ciszy/services/chat_service.dart';
import 'package:strefa_ciszy/services/presence_service.dart';
import 'package:strefa_ciszy/services/storage_service.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatThreadScreen extends StatefulWidget {
  final String chatId;

  const ChatThreadScreen({super.key, required this.chatId});

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final StorageService _storage = StorageService();
  final List<Map<String, dynamic>> _pendingMentions = [];
  final ScrollController _scroll = ScrollController();
  final GlobalKey _composerKey = GlobalKey();

  OverlayEntry? _mentionOverlay;
  OverlayEntry? _tagOverlay;

  TextSpan _buildMessageTextSpan(ChatMessage m, {required bool mine}) {
    final baseStyle = TextStyle(color: mine ? Colors.white : Colors.black87);

    final mentionStyle = baseStyle.copyWith(
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );

    final linkStyle = baseStyle.copyWith(
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );

    final Map<String, Map<String, dynamic>> tokenToMention = {};

    for (final mm in m.mentions) {
      final map = Map<String, dynamic>.from(mm);

      final uid = (map['uid'] ?? '').toString().trim();
      final display = (map['display'] ?? '').toString().trim();
      if (uid.isNotEmpty && display.isNotEmpty) {
        tokenToMention['@$display'] = {
          'type': 'user',
          'uid': uid,
          'label': display,
        };
        continue;
      }

      final type = (map['type'] ?? '').toString().trim();
      final label = (map['label'] ?? map['display'] ?? '').toString().trim();
      final token = (map['token'] ?? '').toString().trim();

      if (type == 'client' || type == 'project') {
        final key = token.isNotEmpty
            ? '#$token'
            : (label.isNotEmpty ? '#$label' : '');
        if (key.isNotEmpty) tokenToMention[key] = map;
      }
    }

    List<InlineSpan> linkify(String text) {
      if (text.isEmpty) return const [];

      final urlRe = RegExp(
        r'((https?:\/\/)|(www\.))[^\s]+',
        caseSensitive: false,
      );

      final spans = <InlineSpan>[];
      int i = 0;

      for (final match in urlRe.allMatches(text)) {
        if (match.start > i) {
          spans.add(
            TextSpan(text: text.substring(i, match.start), style: baseStyle),
          );
        }

        final rawUrl = text.substring(match.start, match.end);

        spans.add(
          TextSpan(
            text: rawUrl,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                _openUrl(rawUrl);
              },
          ),
        );

        i = match.end;
      }

      if (i < text.length) {
        spans.add(TextSpan(text: text.substring(i), style: baseStyle));
      }

      return spans;
    }

    if (tokenToMention.isEmpty) {
      return TextSpan(children: linkify(m.text), style: baseStyle);
    }

    final tokens = tokenToMention.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final spans = <InlineSpan>[];
    String remaining = m.text;

    while (remaining.isNotEmpty) {
      int hitIndex = -1;
      String? hitToken;

      for (final t in tokens) {
        final idx = remaining.indexOf(t);
        if (idx >= 0 && (hitIndex == -1 || idx < hitIndex)) {
          hitIndex = idx;
          hitToken = t;
        }
      }

      if (hitIndex == -1 || hitToken == null) {
        spans.addAll(linkify(remaining));
        break;
      }

      if (hitIndex > 0) {
        spans.addAll(linkify(remaining.substring(0, hitIndex)));
      }

      final data = tokenToMention[hitToken] ?? const <String, dynamic>{};
      final type = (data['type'] ?? 'user').toString();

      spans.add(
        TextSpan(
          text: hitToken,
          style: mentionStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (type == 'user') {
                final uid = (data['uid'] ?? '').toString();
                if (uid.isNotEmpty) _openDmFor(uid);
                return;
              }

              if (type == 'client') {
                final customerId = (data['id'] ?? '').toString();
                if (customerId.isNotEmpty) _openClient(customerId);
                return;
              }

              if (type == 'project') {
                final customerId = (data['customerId'] ?? '').toString();
                final projectId = (data['projectId'] ?? '').toString();
                if (customerId.isNotEmpty && projectId.isNotEmpty) {
                  _openProject(customerId, projectId);
                }
                return;
              }
            },
        ),
      );

      remaining = remaining.substring(hitIndex + hitToken.length);
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  String _currentTagQuery() {
    final value = _controller.value;
    final text = value.text;
    final cursor = value.selection.baseOffset;
    if (cursor < 0) return '';

    final uptoCursor = text.substring(0, cursor);
    final hash = uptoCursor.lastIndexOf('#');
    if (hash == -1) return '';

    if (hash > 0 && uptoCursor[hash - 1].trim().isNotEmpty) return '';

    final afterHash = uptoCursor.substring(hash + 1);
    if (afterHash.contains(' ')) return '';

    return afterHash.trim().toLowerCase();
  }

  void _closeTagOverlay() {
    _tagOverlay?.remove();
    _tagOverlay = null;
  }

  void _refreshTagOverlay() {
    _tagOverlay?.markNeedsBuild();
  }

  Future<void> _openTagPicker() async {
    _focusNode.requestFocus();

    if (_tagOverlay != null) {
      _refreshTagOverlay();
      return;
    }

    final box = _composerKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;

    final pos = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final size = box.size;

    _tagOverlay = OverlayEntry(
      builder: (ctx) {
        final q = _currentTagQuery();

        if (q.isEmpty && !_controller.text.endsWith('#')) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _closeTagOverlay(),
          );
          return const SizedBox.shrink();
        }

        final double left = pos.dx + 12;
        final double width = (size.width - 24).clamp(240.0, 360.0);
        final double bottomFromOverlayTop = overlayBox.size.height - pos.dy + 8;

        return Positioned(
          left: left,
          bottom: bottomFromOverlayTop,
          width: width,
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: TagPickerSheet(
                  compact: true,
                  query: q,
                  onPick: (picked) {
                    final type = (picked['type'] ?? '').toString().trim();
                    final label = (picked['label'] ?? '').toString().trim();
                    final token = (picked['token'] ?? '').toString().trim();

                    if (type.isEmpty || label.isEmpty || token.isEmpty) return;

                    final value = _controller.value;
                    final text = value.text;
                    final sel = value.selection;
                    final cursor = sel.baseOffset >= 0
                        ? sel.baseOffset
                        : text.length;

                    // find the last "#" before cursor and replace "#query" with "#token "
                    final uptoCursor = text.substring(0, cursor);
                    final hash = uptoCursor.lastIndexOf('#');
                    if (hash == -1) return;

                    // boundary: start or whitespace before '#'
                    if (hash > 0 && uptoCursor[hash - 1].trim().isNotEmpty) {
                      return;
                    }

                    final insert = '#$token ';
                    final newText = text.replaceRange(hash, cursor, insert);
                    final newCursorPos = hash + insert.length;

                    _controller.value = value.copyWith(
                      text: newText,
                      selection: TextSelection.collapsed(offset: newCursorPos),
                      composing: TextRange.empty,
                    );

                    // store a clean mention payload (keep ids + label + token)
                    final mm = <String, dynamic>{
                      'type': type,
                      'label': label,
                      'token': token,
                    };

                    if (type == 'client') {
                      final id = (picked['id'] ?? '').toString().trim();
                      if (id.isEmpty) return;
                      mm['id'] = id;
                    }

                    if (type == 'project') {
                      final customerId = (picked['customerId'] ?? '')
                          .toString()
                          .trim();
                      final projectId = (picked['projectId'] ?? '')
                          .toString()
                          .trim();
                      if (customerId.isEmpty || projectId.isEmpty) return;
                      mm['customerId'] = customerId;
                      mm['projectId'] = projectId;
                    }

                    _pendingMentions.add(mm);

                    _closeTagOverlay();
                    _focusNode.requestFocus();
                    _scrollToBottom();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_tagOverlay!);
  }

  String _currentMentionQuery() {
    final value = _controller.value;
    final text = value.text;
    final cursor = value.selection.baseOffset;
    if (cursor < 0) return '';

    final uptoCursor = text.substring(0, cursor);
    final at = uptoCursor.lastIndexOf('@');
    if (at == -1) return '';

    if (at > 0 && uptoCursor[at - 1].trim().isNotEmpty) return '';

    final afterAt = uptoCursor.substring(at + 1);

    if (afterAt.contains(' ')) return '';

    return afterAt.trim().toLowerCase();
  }

  void _closeMentionOverlay() {
    _mentionOverlay?.remove();
    _mentionOverlay = null;
  }

  void _refreshMentionOverlay() {
    _mentionOverlay?.markNeedsBuild();
  }

  Future<void> _openDmFor(String otherUid) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final dmId = await ChatService.instance.getOrCreateDm(
      uidA: myUid,
      uidB: otherUid,
    );

    if (!mounted) return;

    if (kIsWeb) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ChatThreadScreen(chatId: dmId),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ChatThreadScreen(chatId: dmId)));
    }
  }

  void _openClient(String customerId) {
    if (customerId.trim().isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CustomerDetailScreen(customerId: customerId.trim(), isAdmin: false),
      ),
    );
  }

  void _openProject(String customerId, String projectId) {
    if (customerId.trim().isEmpty || projectId.trim().isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectEditorScreen(
          customerId: customerId.trim(),
          projectId: projectId.trim(),
          isAdmin: false,
        ),
      ),
    );
  }

  Future<void> _openMentionPicker() async {
    _focusNode.requestFocus();

    if (_mentionOverlay != null) {
      _refreshMentionOverlay();
      return;
    }

    final box = _composerKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;

    final pos = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final size = box.size;

    _mentionOverlay = OverlayEntry(
      builder: (ctx) {
        final q = _currentMentionQuery();

        if (q.isEmpty && !_controller.text.endsWith('@')) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _closeMentionOverlay(),
          );
          return const SizedBox.shrink();
        }

        final double left = pos.dx + 12;
        final double width = (size.width - 24).clamp(240.0, 360.0);
        final double bottomFromOverlayTop = overlayBox.size.height - pos.dy + 8;

        return Positioned(
          left: left,
          bottom: bottomFromOverlayTop,
          width: width,
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: UserPickerSheet(
                  compact: true,
                  showSearch: false,
                  query: q,
                  onPick: (picked) {
                    final uid = (picked['uid'] ?? '').toString();
                    final display = (picked['display'] ?? '').toString().trim();
                    if (uid.isEmpty || display.isEmpty) return;

                    final value = _controller.value;
                    final text = value.text;
                    final sel = value.selection;

                    final insert = '@$display ';
                    final cursor = sel.baseOffset >= 0
                        ? sel.baseOffset
                        : text.length;

                    final hasAtBeforeCursor =
                        cursor > 0 && text[cursor - 1] == '@';
                    final replaceStart = hasAtBeforeCursor
                        ? cursor - 1
                        : cursor;
                    final replaceEnd = (sel.extentOffset >= 0)
                        ? sel.extentOffset
                        : cursor;

                    final newText = text.replaceRange(
                      replaceStart,
                      replaceEnd,
                      insert,
                    );
                    final newCursorPos = replaceStart + insert.length;

                    _controller.value = value.copyWith(
                      text: newText,
                      selection: TextSelection.collapsed(offset: newCursorPos),
                      composing: TextRange.empty,
                    );

                    _pendingMentions.add({'uid': uid, 'display': display});

                    _closeMentionOverlay();
                    _focusNode.requestFocus();
                    _scrollToBottom();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_mentionOverlay!);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    _closeMentionOverlay();
    _closeTagOverlay();

    _focusNode.requestFocus();

    if (widget.chatId == ChatService.globalChatId) {
      await ChatService.instance.ensureGlobalChat();
    }

    final mentionsToSend = List<Map<String, dynamic>>.from(_pendingMentions);
    _pendingMentions.clear();

    await ChatService.instance.sendMessage(
      chatId: widget.chatId,
      senderId: uid,
      text: text,
      mentions: mentionsToSend,
    );
    _scrollToBottom();
  }

  Future<void> _openAttachMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Zrób fota'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Wybierz z galerii'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Dodaj plik'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;

    if (choice == 'camera') {
      await _sendImage(ImageSource.camera);
    } else if (choice == 'gallery') {
      await _sendImage(ImageSource.gallery);
    } else if (choice == 'file') {
      await _sendFile();
    }
  }

  void _openImageViewer(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _sendImage(ImageSource source) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final xfile = await _storage.pickImage(source: source);
      if (xfile == null) return;

      if (widget.chatId == ChatService.globalChatId) {
        await ChatService.instance.ensureGlobalChat();
      }

      final url = await _storage.uploadChatImage(widget.chatId, xfile);

      await ChatService.instance.sendMessage(
        chatId: widget.chatId,
        senderId: uid,
        text: null,
        attachments: [
          {'type': 'image', 'url': url, 'name': xfile.name},
        ],
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd załącznika: $e')));
    }
  }

  Future<void> _sendFile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final xfile = await _storage.pickFile();
      if (xfile == null) return;

      if (widget.chatId == ChatService.globalChatId) {
        await ChatService.instance.ensureGlobalChat();
      }

      final url = await _storage.uploadChatFile(widget.chatId, xfile);

      await ChatService.instance.sendMessage(
        chatId: widget.chatId,
        senderId: uid,
        text: null,
        attachments: [
          {'type': 'file', 'url': url, 'name': xfile.name},
        ],
      );

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd pliku: $e')));
    }
  }

  Future<void> _deleteMessage(ChatMessage m) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (m.senderId != uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Możesz usunąć tylko swoje wiadomości')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń wiadomość?'),
        content: const Text('Ta operacja jest nieodwracalna.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(m.id)
          .delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd usuwania: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    PresenceService.instance.setActiveChat(widget.chatId);
    _markAsRead();
  }

  @override
  void dispose() {
    PresenceService.instance.clearActiveChat(widget.chatId);

    _closeMentionOverlay();
    _closeTagOverlay();

    _scroll.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatThreadScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.chatId != widget.chatId) {
      PresenceService.instance.clearActiveChat(oldWidget.chatId);
      PresenceService.instance.setActiveChat(widget.chatId);

      _markAsRead();
    }
  }

  Future<void> _openUrl(String raw) async {
    final s = raw.trim();
    if (s.isEmpty) return;

    final url = s.startsWith('http://') || s.startsWith('https://')
        ? s
        : 'https://$s';

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _markAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({'unread_$uid': 0});
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _two(int n) => n.toString().padLeft(2, '0');

  String _fmtTime(DateTime dt) {
    if (dt.year <= 1970) return '';
    return '${_two(dt.hour)}:${_two(dt.minute)}';
  }

  String _fmtDateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(d).inDays;

    if (diffDays == 0) return 'Dzisiaj';
    if (diffDays == 1) return 'Wczoraj';

    const months = [
      'sty',
      'lut',
      'mar',
      'kwi',
      'maj',
      'cze',
      'lip',
      'sie',
      'wrz',
      'paź',
      'lis',
      'gru',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  final Map<String, String> _userNameCache = {};

  Future<String> _getUserName(String uid) async {
    if (_userNameCache.containsKey(uid)) return _userNameCache[uid]!;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final name = (snap.data()?['name'] as String?)?.trim();
    final firstName = (name?.isNotEmpty == true)
        ? name!.split(' ').first
        : 'Użytkownik';

    _userNameCache[uid] = firstName;
    return firstName;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isGlobal = widget.chatId == ChatService.globalChatId;

    return AppScaffold(
      title: isGlobal ? 'Ogólny' : 'Chat',
      showBackOnMobile: true,
      showPersistentDrawerOnWeb: true,

      bottomNavigationBar: KeyedSubtree(
        key: _composerKey,
        child: _ChatComposerBar(
          controller: _controller,
          focusNode: _focusNode,
          onSend: _send,
          onAttach: _openAttachMenu,
          onTap: _scrollToBottom,
          onChanged: (v) {
            if (_mentionOverlay != null) _refreshMentionOverlay();
            if (_tagOverlay != null) _refreshTagOverlay();

            final sel = _controller.selection;
            final cursor = sel.baseOffset;
            if (cursor < 1 || cursor > v.length) return;

            final last = v[cursor - 1];

            if (last == '@') {
              final beforeAt = cursor - 2;
              final okBoundary = beforeAt < 0 || v[beforeAt].trim().isEmpty;
              if (!okBoundary) return;
              _openMentionPicker();
              return;
            }

            if (last == '#') {
              final beforeHash = cursor - 2;
              final okBoundary = beforeHash < 0 || v[beforeHash].trim().isEmpty;
              if (!okBoundary) return;
              _openTagPicker();
              return;
            }
          },
        ),
      ),

      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(12),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: uid == null
                    ? const Center(child: Text('Nie jesteś zalogowany.'))
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: ChatService.instance.watchMessages(
                          widget.chatId,
                        ),
                        builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snap.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return const Center(
                              child: Text('Brak wiadomości.'),
                            );
                          }

                          final msgs = docs
                              .map((d) => ChatMessage.fromDoc(d))
                              .toList();

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!_scroll.hasClients) return;
                            _scroll.jumpTo(_scroll.position.maxScrollExtent);
                          });

                          return ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.only(bottom: 12),

                            itemCount: msgs.length,
                            itemBuilder: (_, i) {
                              final m = msgs[i];
                              final mine = m.senderId == uid;

                              final prev = i > 0 ? msgs[i - 1] : null;
                              final next = i < msgs.length - 1
                                  ? msgs[i + 1]
                                  : null;

                              final showDateDivider =
                                  prev == null ||
                                  !_isSameDay(prev.createdAt, m.createdAt);

                              final showSenderName =
                                  !mine &&
                                  (prev == null ||
                                      prev.senderId != m.senderId ||
                                      showDateDivider);

                              final showTime =
                                  next == null || next.senderId != m.senderId;
                              final timeLabel = _fmtTime(m.createdAt);

                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: mine
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (showDateDivider)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black12,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              _fmtDateLabel(m.createdAt),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    if (showSenderName)
                                      FutureBuilder<String>(
                                        future: _getUserName(m.senderId),
                                        builder: (_, snap) {
                                          if (!snap.hasData) {
                                            return const SizedBox(height: 12);
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              left: 6,
                                              bottom: 2,
                                            ),
                                            child: Text(
                                              snap.data!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment: mine
                                          ? MainAxisAlignment.end
                                          : MainAxisAlignment.start,

                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (mine) ...[
                                          IconButton(
                                            tooltip: 'Usuń',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 25,
                                            ),
                                            color: Colors.red,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                            onPressed: () => _deleteMessage(m),
                                          ),
                                          const SizedBox(width: 6),
                                        ],

                                        Flexible(
                                          child: Container(
                                            constraints: const BoxConstraints(
                                              maxWidth: 520,
                                            ),
                                            margin: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                              horizontal: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: mine
                                                  ? Colors.blueGrey.shade700
                                                  : Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: SelectionArea(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (m.text.trim().isNotEmpty)
                                                    SelectableText.rich(
                                                      _buildMessageTextSpan(
                                                        m,
                                                        mine: mine,
                                                      ),
                                                    ),

                                                  if (m
                                                      .attachments
                                                      .isNotEmpty) ...[
                                                    if (m.text
                                                        .trim()
                                                        .isNotEmpty)
                                                      const SizedBox(height: 8),
                                                    ...m.attachments.map((a) {
                                                      final type =
                                                          (a['type'] ?? '')
                                                              .toString();
                                                      final url =
                                                          (a['url'] ?? '')
                                                              .toString();
                                                      final name =
                                                          (a['name'] ?? 'plik')
                                                              .toString();

                                                      if (url.isEmpty)
                                                        return const SizedBox.shrink();

                                                      if (type == 'image') {
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                bottom: 8,
                                                              ),
                                                          child: GestureDetector(
                                                            onTap: () =>
                                                                _openImageViewer(
                                                                  url,
                                                                ),
                                                            child: ClipRRect(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                              child:
                                                                  Image.network(
                                                                    url,
                                                                    height: 160,
                                                                    fit: BoxFit
                                                                        .cover,
                                                                  ),
                                                            ),
                                                          ),
                                                        );
                                                      }

                                                      if (type == 'file') {
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                bottom: 8,
                                                              ),
                                                          child: InkWell(
                                                            onTap: () =>
                                                                _openUrl(url),
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    10,
                                                                  ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                    color: Colors
                                                                        .black12,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                  ),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .insert_drive_file,
                                                                    size: 20,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Flexible(
                                                                    child: Text(
                                                                      name,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      }

                                                      return const SizedBox.shrink();
                                                    }),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    if (showTime && timeLabel.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 2,
                                          left: 6,
                                          right: 6,
                                        ),
                                        child: Text(
                                          timeLabel,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ),
                                  ],
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

class _ChatComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final Future<void> Function() onAttach;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  const _ChatComposerBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onAttach,
    required this.onTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    final bottomInset = mq.viewInsets.bottom;

    final applySafeArea = bottomInset == 0;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: applySafeArea,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 8,
          bottom: bottomInset,
        ),
        child: Material(
          color: Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onTap: onTap,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Pisz coś...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueGrey),
                  onPressed: onSend,
                ),
              ),
              IconButton(
                tooltip: 'Dodaj',
                onPressed: onAttach,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
