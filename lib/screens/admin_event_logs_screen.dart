// lib/screens/admin_event_logs_screen.dart
// Access: leerichie@wp.pl only

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ── Model ────────────────────────────────────────────────────────────────────

enum _Category { auth, chat, file, workday, report, app, business }

enum _Severity { low, medium, high, critical }

class _LogEntry {
  final String id;
  final String source;
  final DateTime timestamp;
  final String userName;
  final String userEmail;
  final String action;
  final Map<String, dynamic> details;
  final _Category category;
  final _Severity severity;

  const _LogEntry({
    required this.id,
    required this.source,
    required this.timestamp,
    required this.userName,
    required this.userEmail,
    required this.action,
    required this.details,
    required this.category,
    required this.severity,
  });
}

// ── Screen ───────────────────────────────────────────────────────────────────

class AdminEventLogsScreen extends StatefulWidget {
  const AdminEventLogsScreen({super.key});

  static bool isAllowed() {
    final email =
        FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim() ?? '';
    return email == 'leerichie@wp.pl';
  }

  @override
  State<AdminEventLogsScreen> createState() => _AdminEventLogsScreenState();
}

class _AdminEventLogsScreenState extends State<AdminEventLogsScreen> {
  // ── Per-collection buckets — updated independently ─────────────────────────
  List<_LogEntry> _auditEntries = [];
  List<_LogEntry> _eventEntries = [];
  List<_LogEntry> _workdayEntries = [];

  // Track which streams have errored so we can warn the user
  final Set<String> _streamErrors = {};
  bool _loading = true;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _auditSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _workdaySub;

  // ── Filters ────────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  DateTime? _filterDate;
  _Category? _categoryFilter;
  _Severity? _severityFilter;
  final Set<String> _selected = {};
  bool _isDeleting = false;

  // ── Init ───────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _subscribeAll();
  }

  void _subscribeAll() {
    // Audit logs — business events already in the app
    _auditSub = FirebaseFirestore.instance
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(400)
        .snapshots()
        .listen(
          (snap) => setState(() {
            _auditEntries = snap.docs.map(_fromAudit).toList();
            _streamErrors.remove('audit_logs');
            _loading = false;
          }),
          onError: (e) {
            debugPrint('[audit_logs] $e');
            setState(() {
              _streamErrors.add('audit_logs');
              _loading = false;
            });
          },
        );

    // Event logs — new system events (login, chat, file, workday, app)
    _eventSub = FirebaseFirestore.instance
        .collection('event_logs')
        .orderBy('timestamp', descending: true)
        .limit(400)
        .snapshots()
        .listen(
          (snap) => setState(() {
            _eventEntries = snap.docs.map(_fromEvent).toList();
            _streamErrors.remove('event_logs');
          }),
          onError: (e) {
            debugPrint('[event_logs] $e');
            setState(() => _streamErrors.add('event_logs'));
          },
        );

    // Work day logs — all users' entries
    _workdaySub = FirebaseFirestore.instance
        .collection('work_day_logs')
        .orderBy('createdAt', descending: true)
        .limit(300)
        .snapshots()
        .listen(
          (snap) => setState(() {
            _workdayEntries = snap.docs.map(_fromWorkDay).toList();
            _streamErrors.remove('work_day_logs');
          }),
          onError: (e) {
            debugPrint('[work_day_logs] $e');
            setState(() => _streamErrors.add('work_day_logs'));
          },
        );
  }

  @override
  void dispose() {
    _auditSub?.cancel();
    _eventSub?.cancel();
    _workdaySub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Merged sorted list ─────────────────────────────────────────────────────

  List<_LogEntry> get _allEntries {
    return [..._auditEntries, ..._eventEntries, ..._workdayEntries]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // ── Converters ─────────────────────────────────────────────────────────────

  static _LogEntry _fromAudit(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final action = data['action'] as String? ?? '';
    final ts = data['timestamp'] as Timestamp?;

    _Severity sev;
    if (action.startsWith('Usunięto')) {
      sev = _Severity.high;
    } else if (action.startsWith('Zamiana') || action.startsWith('Zwrot')) {
      sev = _Severity.medium;
    } else {
      sev = _Severity.low;
    }

    return _LogEntry(
      id: 'audit_${d.id}',
      source: 'audit',
      timestamp: ts?.toDate().toLocal() ?? DateTime(2000),
      userName: data['userName'] as String? ?? data['userId'] as String? ?? '—',
      userEmail: '',
      action: _translateAudit(action),
      details: (data['details'] as Map?)?.cast<String, dynamic>() ?? {},
      category: _Category.business,
      severity: sev,
    );
  }

  static String _translateAudit(String a) {
    if (a.startsWith('Usunięto notat')) return 'Note deleted';
    if (a.startsWith('Usunięto')) return a.replaceFirst('Usunięto', 'Deleted');
    if (a.startsWith('Zamiana')) return 'Product swap';
    if (a.startsWith('Zwrot')) return 'Product return';
    if (a.startsWith('Zaktualizowano')) {
      return a.replaceFirst('Zaktualizowano', 'Updated');
    }
    if (a.startsWith('Edytowano')) return a.replaceFirst('Edytowano', 'Edited');
    if (a.startsWith('Utworzono')) {
      return a.replaceFirst('Utworzono', 'Created');
    }
    if (a.startsWith('Oznaczono')) return a.replaceFirst('Oznaczono', 'Marked');
    return a;
  }

  static _LogEntry _fromEvent(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final eventType = data['eventType'] as String? ?? '';
    final categoryStr = data['category'] as String? ?? '';
    final severityStr = data['severity'] as String? ?? 'info';
    final ts = data['timestamp'] as Timestamp?;

    final category = switch (categoryStr) {
      'auth' => _Category.auth,
      'chat' => _Category.chat,
      'file' => _Category.file,
      'workday' => _Category.workday,
      'report' => _Category.report,
      'app' => _Category.app,
      _ => _Category.business,
    };

    final severity = switch (severityStr) {
      'error' => _Severity.critical,
      'warning' => _Severity.high,
      _ => _Severity.low,
    };

    return _LogEntry(
      id: 'event_${d.id}',
      source: 'event',
      timestamp: ts?.toDate().toLocal() ?? DateTime(2000),
      userName:
          data['userName'] as String? ?? data['userEmail'] as String? ?? '—',
      userEmail: data['userEmail'] as String? ?? '',
      action: _translateEvent(eventType),
      details: (data['details'] as Map?)?.cast<String, dynamic>() ?? {},
      category: category,
      severity: severity,
    );
  }

  static String _translateEvent(String t) => switch (t) {
    'LOGIN_SUCCESS' => 'Login successful',
    'LOGIN_FAILED' => 'Failed login attempt',
    'CHAT_MESSAGE_SENT' => 'Chat message sent',
    'FILE_UPLOADED' => 'File uploaded',
    'FILE_DELETED' => 'File deleted',
    'WORKDAY_ENTRY_CREATED' => 'Work day entry added',
    'WORKDAY_ENTRY_UPDATED' => 'Work day entry updated',
    'WORKDAY_ENTRY_DELETED' => 'Work day entry deleted',
    'APP_UPDATE_ACCEPTED' => 'App update accepted',
    'APP_UPDATE_IGNORED' => 'App update dismissed',
    'REPORT_VIEWED' => 'Report opened',
    _ => t.replaceAll('_', ' ').toLowerCase(),
  };

  static _LogEntry _fromWorkDay(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final ts = (data['createdAt'] ?? data['updatedAt']) as Timestamp?;
    final start = data['startTime'] as String? ?? '';
    final end = data['endTime'] as String? ?? '';
    final dayKey = data['dayKey'] as String? ?? '';
    final project = data['projectName'] as String? ?? '';
    final note = data['description'] as String? ?? '';
    final durationMin = (data['durationMinutes'] as num?)?.toInt();

    return _LogEntry(
      id: 'workday_${d.id}',
      source: 'workday',
      timestamp: ts?.toDate().toLocal() ?? DateTime(2000),
      userName: data['userName'] as String? ?? data['userId'] as String? ?? '—',
      userEmail: data['userEmail'] as String? ?? '',
      action: 'Work day entry',
      details: {
        'date': dayKey,
        'time': '$start – $end',
        if (durationMin != null)
          'duration':
              '${durationMin ~/ 60}h ${(durationMin % 60).toString().padLeft(2, '0')}m',
        if (project.isNotEmpty) 'project': project,
        if (note.isNotEmpty) 'note': note,
      },
      category: _Category.workday,
      severity: _Severity.low,
    );
  }

  // ── Colours / labels ───────────────────────────────────────────────────────

  Color _catColor(_Category c) => switch (c) {
    _Category.auth => const Color(0xFF7B1FA2),
    _Category.chat => const Color(0xFF0288D1),
    _Category.file => const Color(0xFF00796B),
    _Category.workday => const Color(0xFF1565C0),
    _Category.report => const Color(0xFF558B2F),
    _Category.app => const Color(0xFFF57C00),
    _Category.business => const Color(0xFF455A64),
  };

  Color _catBg(_Category c) => switch (c) {
    _Category.auth => const Color(0xFFF3E5F5),
    _Category.chat => const Color(0xFFE1F5FE),
    _Category.file => const Color(0xFFE0F2F1),
    _Category.workday => const Color(0xFFE3F2FD),
    _Category.report => const Color(0xFFF1F8E9),
    _Category.app => const Color(0xFFFFF3E0),
    _Category.business => const Color(0xFFECEFF1),
  };

  String _catLabel(_Category c) => switch (c) {
    _Category.auth => 'Auth',
    _Category.chat => 'Chat',
    _Category.file => 'File',
    _Category.workday => 'Work Day',
    _Category.report => 'Report',
    _Category.app => 'App',
    _Category.business => 'Business',
  };

  IconData _catIcon(_Category c) => switch (c) {
    _Category.auth => Icons.lock_outline,
    _Category.chat => Icons.chat_bubble_outline,
    _Category.file => Icons.attach_file,
    _Category.workday => Icons.access_time_outlined,
    _Category.report => Icons.bar_chart_outlined,
    _Category.app => Icons.system_update_outlined,
    _Category.business => Icons.business_center_outlined,
  };

  Color _sevBorderColor(_Severity s) => switch (s) {
    _Severity.critical => const Color(0xFFB71C1C),
    _Severity.high => const Color(0xFFE65100),
    _Severity.medium => const Color(0xFFF9A825),
    _Severity.low => Colors.transparent,
  };

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<_LogEntry> get _filtered {
    return _allEntries.where((e) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final hit =
            e.userName.toLowerCase().contains(q) ||
            e.userEmail.toLowerCase().contains(q) ||
            e.action.toLowerCase().contains(q) ||
            e.details.values.join(' ').toLowerCase().contains(q) ||
            _catLabel(e.category).toLowerCase().contains(q);
        if (!hit) return false;
      }
      if (_filterDate != null) {
        final d = _filterDate!;
        if (e.timestamp.year != d.year ||
            e.timestamp.month != d.month ||
            e.timestamp.day != d.day) {
          return false;
        }
      }
      if (_categoryFilter != null && e.category != _categoryFilter) {
        return false;
      }
      if (_severityFilter != null && e.severity != _severityFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete selected logs?'),
        content: Text('Permanently deletes $count entries. Cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final entries = _allEntries.where((e) => _selected.contains(e.id));
      final auditRefs = <DocumentReference>[];
      final eventRefs = <DocumentReference>[];
      for (final e in entries) {
        final rawId = e.id.substring(e.source.length + 1);
        if (e.source == 'audit') {
          auditRefs.add(
            FirebaseFirestore.instance.collection('audit_logs').doc(rawId),
          );
        } else if (e.source == 'event') {
          eventRefs.add(
            FirebaseFirestore.instance.collection('event_logs').doc(rawId),
          );
        }
        // workday entries are user-owned — not deletable from admin view
      }

      Future<void> batchDelete(List<DocumentReference> refs) async {
        for (var i = 0; i < refs.length; i += 400) {
          final b = FirebaseFirestore.instance.batch();
          for (final r in refs.skip(i).take(400)) {
            b.delete(r);
          }
          await b.commit();
        }
      }

      await Future.wait([batchDelete(auditRefs), batchDelete(eventRefs)]);
      setState(() => _selected.clear());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted $count entries.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final all = _allEntries;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: _selected.isNotEmpty
            ? Text('${_selected.length} selected')
            : const Text('Event Logs'),
        actions: [
          if (_selected.isNotEmpty) ...[
            if (_isDeleting)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Delete selected',
                onPressed: _deleteSelected,
              ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _selected.clear()),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          if (_streamErrors.isNotEmpty) _buildRulesBanner(),
          const Divider(height: 1, thickness: 1),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(child: _buildList(filtered, all)),
        ],
      ),
    );
  }

  Widget _buildRulesBanner() {
    return Container(
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Color(0xFFE65100),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Some collections blocked (${_streamErrors.join(', ')}). '
              'Run: firebase deploy --only firestore:rules',
              style: const TextStyle(fontSize: 11, color: Color(0xFFBF360C)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by user, action, details…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 420;
              if (isCompact) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildDateChip()),
                        const SizedBox(width: 8),
                        Expanded(child: _buildSevDropdown()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildCatDropdown(),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: _buildDateChip()),
                  const SizedBox(width: 8),
                  Expanded(child: _buildCatDropdown()),
                  const SizedBox(width: 8),
                  Expanded(child: _buildSevDropdown()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip() {
    final active = _filterDate != null;
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _filterDate ?? DateTime.now(),
          firstDate: DateTime(2022),
          lastDate: DateTime.now(),
        );
        if (picked != null) setState(() => _filterDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE3F2FD) : Colors.transparent,
          border: Border.all(
            color: active ? Colors.blue : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 15,
              color: active ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                active ? DateFormat('dd.MM.yyyy').format(_filterDate!) : 'Date',
                style: TextStyle(
                  fontSize: 12,
                  color: active ? Colors.blue.shade700 : Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (active)
              GestureDetector(
                onTap: () => setState(() => _filterDate = null),
                child: Icon(
                  Icons.cancel_outlined,
                  size: 14,
                  color: Colors.blue.shade700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatDropdown() {
    return DropdownButtonFormField<_Category?>(
      initialValue: _categoryFilter,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      hint: const Text('Category', style: TextStyle(fontSize: 12)),
      items: [
        const DropdownMenuItem<_Category?>(
          value: null,
          child: Text('All categories', style: TextStyle(fontSize: 12)),
        ),
        ..._Category.values.map(
          (c) => DropdownMenuItem(
            value: c,
            child: Row(
              children: [
                Icon(_catIcon(c), size: 13, color: _catColor(c)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _catLabel(c),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      onChanged: (v) => setState(() => _categoryFilter = v),
    );
  }

  Widget _buildSevDropdown() {
    const labels = {
      _Severity.low: 'Low',
      _Severity.medium: 'Medium',
      _Severity.high: 'High',
      _Severity.critical: 'Critical',
    };
    const colors = {
      _Severity.low: Colors.green,
      _Severity.medium: Colors.amber,
      _Severity.high: Colors.orange,
      _Severity.critical: Colors.red,
    };
    return DropdownButtonFormField<_Severity?>(
      initialValue: _severityFilter,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      hint: const Text('Severity', style: TextStyle(fontSize: 12)),
      items: [
        const DropdownMenuItem<_Severity?>(
          value: null,
          child: Text('All severity', style: TextStyle(fontSize: 12)),
        ),
        ..._Severity.values.map(
          (s) => DropdownMenuItem(
            value: s,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors[s],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    labels[s]!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      onChanged: (v) => setState(() => _severityFilter = v),
    );
  }

  Widget _buildList(List<_LogEntry> filtered, List<_LogEntry> all) {
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              all.isEmpty ? 'No events yet.' : 'No events match the filters.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final summaryText =
        '${filtered.length} of ${all.length} events'
        '${_isFiltered ? ' · filtered' : ''}'
        '  |  Audit: ${_auditEntries.length}'
        '  Work: ${_workdayEntries.length}'
        '  Sys: ${_eventEntries.length}';
    final selectionText = _selected.isEmpty
        ? 'Long-press to select'
        : '${_selected.length} selected';

    return Column(
      children: [
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  summaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  selectionText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 10,
                    color: _selected.isEmpty
                        ? Colors.grey.shade400
                        : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 14),
            itemBuilder: (_, i) => _buildRow(filtered[i]),
          ),
        ),
      ],
    );
  }

  bool get _isFiltered =>
      _filterDate != null ||
      _categoryFilter != null ||
      _severityFilter != null ||
      _searchQuery.isNotEmpty;

  Widget _buildRow(_LogEntry e) {
    final isSelected = _selected.contains(e.id);
    final isSelecting = _selected.isNotEmpty;
    final accent = _catColor(e.category);
    final bg = _catBg(e.category);
    final border = _sevBorderColor(e.severity);
    final when = DateFormat('dd.MM.yy  HH:mm').format(e.timestamp);

    return GestureDetector(
      onLongPress: () => setState(
        () => isSelected ? _selected.remove(e.id) : _selected.add(e.id),
      ),
      onTap: isSelecting
          ? () => setState(
              () => isSelected ? _selected.remove(e.id) : _selected.add(e.id),
            )
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: isSelected ? Colors.blue.shade100 : bg,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: border != Colors.transparent
                    ? border
                    : accent.withAlpha(60),
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSelecting)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Icon(
                    isSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 16,
                    color: isSelected ? Colors.blue : Colors.grey,
                  ),
                ),
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 10, top: 1),
                decoration: BoxDecoration(
                  color: accent.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(_catIcon(e.category), size: 15, color: accent),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            e.action,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF212121),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: accent.withAlpha(80)),
                          ),
                          child: Text(
                            _catLabel(e.category),
                            style: TextStyle(
                              fontSize: 9,
                              color: accent,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 11,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            e.userEmail.isNotEmpty && e.userEmail != e.userName
                                ? '${e.userName} (${e.userEmail})'
                                : e.userName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.schedule,
                          size: 11,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          when,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    if (e.details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: e.details.entries.map((kv) {
                          return RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                              children: [
                                TextSpan(
                                  text: '${kv.key}: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                TextSpan(text: kv.value?.toString() ?? ''),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
