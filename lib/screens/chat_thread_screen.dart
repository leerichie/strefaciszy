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

class _AvChatPalette {
  static const headlineFont = 'Bose-Headline (Bold)';
  static const bodyFont = 'Bose (Regular)';
  static const ink = Color(0xFF101820);
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
  static const bubbleBottom = Color(0xFF1E5D88);
  static const cyan = Color(0xFF0097A7);
  static const cyanDark = Color(0xFF006D78);
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

class ChatThreadScreen extends StatefulWidget {
  final String chatId;

  const ChatThreadScreen({super.key, required this.chatId});

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  static const List<Map<String, dynamic>> _broadcastMentions = [
    {
      'type': 'broadcast',
      'token': 'all',
      'label': 'Wszyscy',
      'icon': Icons.campaign,
    },
    {
      'type': 'broadcast',
      'token': 'here',
      'label': 'Wszyscy tutaj',
      'icon': Icons.notifications_active,
    },
    {
      'type': 'broadcast',
      'token': 'sc',
      'label': 'Strefa Ciszy',
      'icon': Icons.groups,
    },
    {
      'type': 'broadcast',
      'token': 'chat',
      'label': 'Ten chat',
      'icon': Icons.forum,
    },
  ];

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final StorageService _storage = StorageService();
  final List<Map<String, dynamic>> _pendingMentions = [];
  final ScrollController _scroll = ScrollController();
  final GlobalKey _composerKey = GlobalKey();
  int _lastMessageCount = 0;
  String? _lastMessageId;
  bool _didInitialMessageScroll = false;

  OverlayEntry? _mentionOverlay;
  OverlayEntry? _tagOverlay;

  TextSpan _buildMessageTextSpan(ChatMessage m, {required bool mine}) {
    final baseStyle = TextStyle(
      color: mine ? Colors.white : _AvChatPalette.text,
      fontFamily: _AvChatPalette.bodyFont,
    );

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

      if (type == 'broadcast' && token.isNotEmpty) {
        tokenToMention['@$token'] = map;
      }

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

              if (type == 'broadcast') {
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
                  specialMentions: _broadcastMentions,
                  onPick: (picked) {
                    final type = (picked['type'] ?? '').toString().trim();
                    if (type == 'broadcast') {
                      final token = (picked['token'] ?? '').toString().trim();
                      final label = (picked['label'] ?? '').toString().trim();
                      if (token.isEmpty || label.isEmpty) return;

                      final value = _controller.value;
                      final text = value.text;
                      final sel = value.selection;
                      final cursor = sel.baseOffset >= 0
                          ? sel.baseOffset
                          : text.length;
                      final uptoCursor = text.substring(0, cursor);
                      final at = uptoCursor.lastIndexOf('@');
                      if (at == -1) return;

                      if (at > 0 && uptoCursor[at - 1].trim().isNotEmpty) {
                        return;
                      }

                      final insert = '@$token ';
                      final newText = text.replaceRange(at, cursor, insert);
                      final newCursorPos = at + insert.length;

                      _controller.value = value.copyWith(
                        text: newText,
                        selection: TextSelection.collapsed(
                          offset: newCursorPos,
                        ),
                        composing: TextRange.empty,
                      );

                      _pendingMentions.add({
                        'type': 'broadcast',
                        'token': token,
                        'label': label,
                      });

                      _closeMentionOverlay();
                      _focusNode.requestFocus();
                      _scrollToBottom();
                      return;
                    }

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

                    final uptoCursor = text.substring(0, cursor);
                    final at = uptoCursor.lastIndexOf('@');
                    if (at == -1) return;

                    if (at > 0 && uptoCursor[at - 1].trim().isNotEmpty) return;

                    final newText = text.replaceRange(at, cursor, insert);
                    final newCursorPos = at + insert.length;

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

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (jump) {
        _scroll.jumpTo(target);
        return;
      }
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _scheduleMessageScroll(List<ChatMessage> msgs) {
    final newestId = msgs.isEmpty ? null : msgs.last.id;
    final changed =
        newestId != _lastMessageId || msgs.length != _lastMessageCount;
    if (!changed) return;

    final jump = !_didInitialMessageScroll;
    _lastMessageId = newestId;
    _lastMessageCount = msgs.length;
    _didInitialMessageScroll = true;

    _scrollToBottom(jump: jump);

    Future.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      _scrollToBottom(jump: jump);
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
      backgroundColor: _AvChatPalette.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'DODAJ ZAŁĄCZNIK',
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
              leading: const Icon(
                Icons.photo_camera,
                color: _AvChatPalette.bubbleTop,
              ),
              title: const Text(
                'Zrób fota',
                style: TextStyle(
                  fontFamily: _AvChatPalette.bodyFont,
                  color: _AvChatPalette.text,
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: _AvChatPalette.bubbleTop,
              ),
              title: const Text(
                'Wybierz z galerii',
                style: TextStyle(
                  fontFamily: _AvChatPalette.bodyFont,
                  color: _AvChatPalette.text,
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(
                Icons.attach_file,
                color: _AvChatPalette.bubbleTop,
              ),
              title: const Text(
                'Dodaj plik',
                style: TextStyle(
                  fontFamily: _AvChatPalette.bodyFont,
                  color: _AvChatPalette.text,
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            const SizedBox(height: 8),
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
        backgroundColor: _AvChatPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Image.network(url, fit: BoxFit.contain),
          ),
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
        title: const Text('Usuń wiadomość?'),
        content: const Text('Ta operacja jest nieodwracalna.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: _AvChatPalette.muted),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AvChatPalette.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
      _lastMessageCount = 0;
      _lastMessageId = null;
      _didInitialMessageScroll = false;

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
        title: isGlobal ? 'Ogólny' : 'Chat',
        titleWidget: Text(isGlobal ? 'OGÓLNY' : 'CHAT'),
        centreTitle: true,
        showBackOnMobile: true,
        showBackOnWeb: true,
        showPersistentDrawerOnWeb: true,
        appBarFlexibleSpace: const _ChatHeaderGradient(),

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
                final okBoundary =
                    beforeHash < 0 || v[beforeHash].trim().isEmpty;
                if (!okBoundary) return;
                _openTagPicker();
                return;
              }
            },
          ),
        ),

        body: SafeArea(
          bottom: false,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_AvChatPalette.panel, _AvChatPalette.panelAlt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
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
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
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

                            _scheduleMessageScroll(msgs);

                            return ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                18,
                              ),

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

                                return Column(
                                  children: [
                                    if (showDateDivider)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _AvChatPalette.surface
                                                  .withValues(alpha: 0.78),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: _AvChatPalette.ink
                                                    .withValues(alpha: 0.06),
                                              ),
                                            ),
                                            child: Text(
                                              _fmtDateLabel(m.createdAt),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: _AvChatPalette.muted,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Align(
                                      alignment: mine
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Column(
                                        crossAxisAlignment: mine
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        children: [
                                          if (showSenderName)
                                            FutureBuilder<String>(
                                              future: _getUserName(m.senderId),
                                              builder: (_, snap) {
                                                if (!snap.hasData) {
                                                  return const SizedBox(
                                                    height: 12,
                                                  );
                                                }
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 8,
                                                        bottom: 3,
                                                      ),
                                                  child: Text(
                                                    snap.data!,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          _AvChatPalette.muted,
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
                                                CrossAxisAlignment.end,
                                            children: [
                                              Flexible(
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    Container(
                                                      constraints:
                                                          const BoxConstraints(
                                                            maxWidth: 540,
                                                          ),
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 3,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 10,
                                                            horizontal: 13,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: mine
                                                            ? null
                                                            : _AvChatPalette
                                                                  .surface,
                                                        gradient: mine
                                                            ? const LinearGradient(
                                                                colors: [
                                                                  _AvChatPalette
                                                                      .bubbleTop,
                                                                  _AvChatPalette
                                                                      .bubbleBottom,
                                                                ],
                                                                begin: Alignment
                                                                    .topCenter,
                                                                end: Alignment
                                                                    .bottomCenter,
                                                              )
                                                            : null,
                                                        borderRadius: BorderRadius.only(
                                                          topLeft:
                                                              const Radius.circular(
                                                                18,
                                                              ),
                                                          topRight:
                                                              const Radius.circular(
                                                                18,
                                                              ),
                                                          bottomLeft:
                                                              Radius.circular(
                                                                mine ? 18 : 5,
                                                              ),
                                                          bottomRight:
                                                              Radius.circular(
                                                                mine ? 5 : 18,
                                                              ),
                                                        ),
                                                        border: mine
                                                            ? null
                                                            : Border.all(
                                                                color:
                                                                    const Color(
                                                                      0xFFD6DFE3,
                                                                    ),
                                                              ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withValues(
                                                                  alpha: 0.06,
                                                                ),
                                                            blurRadius: 10,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  3,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: SelectionArea(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            if (m.text
                                                                .trim()
                                                                .isNotEmpty)
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
                                                                const SizedBox(
                                                                  height: 8,
                                                                ),
                                                              ...m.attachments.map((
                                                                a,
                                                              ) {
                                                                final type =
                                                                    (a['type'] ??
                                                                            '')
                                                                        .toString();
                                                                final url =
                                                                    (a['url'] ??
                                                                            '')
                                                                        .toString();
                                                                final name =
                                                                    (a['name'] ??
                                                                            'plik')
                                                                        .toString();

                                                                if (url
                                                                    .isEmpty) {
                                                                  return const SizedBox.shrink();
                                                                }

                                                                if (type ==
                                                                    'image') {
                                                                  return Padding(
                                                                    padding:
                                                                        const EdgeInsets.only(
                                                                          bottom:
                                                                              8,
                                                                        ),
                                                                    child: GestureDetector(
                                                                      onTap: () =>
                                                                          _openImageViewer(
                                                                            url,
                                                                          ),
                                                                      child: ClipRRect(
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              12,
                                                                            ),
                                                                        child: Image.network(
                                                                          url,
                                                                          height:
                                                                              180,
                                                                          fit: BoxFit
                                                                              .cover,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  );
                                                                }

                                                                if (type ==
                                                                    'file') {
                                                                  return Padding(
                                                                    padding:
                                                                        const EdgeInsets.only(
                                                                          bottom:
                                                                              8,
                                                                        ),
                                                                    child: InkWell(
                                                                      onTap: () =>
                                                                          _openUrl(
                                                                            url,
                                                                          ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                      child: Container(
                                                                        padding:
                                                                            const EdgeInsets.all(
                                                                              10,
                                                                            ),
                                                                        decoration: BoxDecoration(
                                                                          color:
                                                                              mine
                                                                              ? Colors.white.withValues(
                                                                                  alpha: 0.16,
                                                                                )
                                                                              : const Color(
                                                                                  0xFFEFF3F5,
                                                                                ),
                                                                          borderRadius: BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                        ),
                                                                        child: Row(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          children: [
                                                                            Icon(
                                                                              Icons.insert_drive_file,
                                                                              size: 20,
                                                                              color: mine
                                                                                  ? Colors.white
                                                                                  : _AvChatPalette.muted,
                                                                            ),
                                                                            const SizedBox(
                                                                              width: 8,
                                                                            ),
                                                                            Flexible(
                                                                              child: Text(
                                                                                name,
                                                                                overflow: TextOverflow.ellipsis,
                                                                                style: TextStyle(
                                                                                  color: mine
                                                                                      ? Colors.white
                                                                                      : _AvChatPalette.text,
                                                                                ),
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
                                                    if (mine)
                                                      Positioned(
                                                        top: -15,
                                                        right: -15,
                                                        child: Material(
                                                          color: Colors
                                                              .transparent,
                                                          shape:
                                                              const CircleBorder(),
                                                          child: IconButton(
                                                            tooltip: 'Usuń',
                                                            icon: const Icon(
                                                              Icons.close,
                                                              size: 16,
                                                            ),
                                                            color: Colors.white,
                                                            style: IconButton.styleFrom(
                                                              backgroundColor:
                                                                  _AvChatPalette
                                                                      .ink
                                                                      .withValues(
                                                                        alpha:
                                                                            0.72,
                                                                      ),
                                                              hoverColor:
                                                                  _AvChatPalette
                                                                      .danger,
                                                              minimumSize:
                                                                  const Size(
                                                                    18,
                                                                    18,
                                                                  ),
                                                              fixedSize:
                                                                  const Size(
                                                                    18,
                                                                    18,
                                                                  ),
                                                              padding:
                                                                  EdgeInsets
                                                                      .zero,
                                                            ),
                                                            onPressed: () =>
                                                                _deleteMessage(
                                                                  m,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),

                                          if (showTime && timeLabel.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2,
                                                left: 8,
                                                right: 8,
                                                bottom: 2,
                                              ),
                                              child: Text(
                                                timeLabel,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: _AvChatPalette.muted,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
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
      child: DecoratedBox(
        decoration: const BoxDecoration(color: _AvChatPalette.surface),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 10,
            bottom: bottomInset + 10,
          ),
          child: Material(
            color: Colors.transparent,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _AvChatPalette.surface,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: _AvChatPalette.line),
                      boxShadow: [
                        BoxShadow(
                          color: _AvChatPalette.ink.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 5, 5, 5),
                          child: _GradientCircleIconButton(
                            tooltip: 'Dodaj',
                            onPressed: onAttach,
                            icon: const Icon(Icons.add, size: 20),
                            size: 36,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onTap: onTap,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => onSend(),
                            decoration: const InputDecoration(
                              hintText: 'Napisz wiadomość...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 13,
                              ),
                              hintStyle: TextStyle(
                                fontFamily: _AvChatPalette.bodyFont,
                              ),
                            ),
                            style: const TextStyle(
                              fontFamily: _AvChatPalette.bodyFont,
                            ),
                            onChanged: onChanged,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: _GradientCircleIconButton(
                    tooltip: 'Wyślij',
                    icon: const Icon(Icons.send_rounded, size: 20),
                    onPressed: onSend,
                    size: 46,
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

class _GradientCircleIconButton extends StatelessWidget {
  final String tooltip;
  final Icon icon;
  final VoidCallback onPressed;
  final double size;

  const _GradientCircleIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
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
}
