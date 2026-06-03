// screens/my_day_screen.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/services/event_log_service.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:table_calendar/table_calendar.dart';

class _AppPalette {
  static const bodyFont = 'Bose (Regular)';
  static const headlineFont = 'Bose-Headline (Bold)';
  static const surface = Colors.white;
  static const bg = Color(0xFFF4F6F7);
  static const line = Color(0xFFD4DCE0);
  static const text = Color(0xFF1E2B2F);
  static const muted = Color(0xFF607176);
  static const brand = Color(0xFF2574A9);
  static const danger = Color(0xFFE04747);
}

class MyDayScreen extends StatefulWidget {
  const MyDayScreen({super.key});

  @override
  State<MyDayScreen> createState() => _MyDayScreenState();
}

class _MyDayScreenState extends State<MyDayScreen> with WidgetsBindingObserver {
  DateTime _selectedDay = DateTime.now();

  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _currentLocalDay = DateTime.now();
  Timer? _dayRolloverTimer;

  List<Map<String, String>> _projectsCache = [];
  bool _projectsLoading = false;
  bool _projectsLoaded = false;
  bool _initialLoadingDialogVisible = false;
  Timer? _initialLoadingDialogTimer;

  bool _timesOverlap({
    required int startA,
    required int endA,
    required int startB,
    required int endB,
  }) {
    return startA < endB && endA > startB;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentLocalDay = _dateOnly(DateTime.now());
    _selectedDay = _currentLocalDay;
    _focusedDay = _currentLocalDay;
    _scheduleDayRolloverCheck();
    _scheduleInitialLoadingDialog();
    _ensureProjectsLoaded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayRolloverTimer?.cancel();
    _initialLoadingDialogTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handlePossibleDayRollover(showMessage: true);
    }
  }

  String _dayKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  DateTime _dateOnly(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }

  DateTime _firstDayOfMonth(DateTime d) {
    return DateTime(d.year, d.month, 1);
  }

  DateTime _firstDayOfNextMonth(DateTime d) {
    if (d.month == 12) {
      return DateTime(d.year + 1, 1, 1);
    }
    return DateTime(d.year, d.month + 1, 1);
  }

  Map<String, int> _buildDayCounts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, int> counts = {};

    for (final doc in docs) {
      final data = doc.data();
      final ts = data['workDate'] as Timestamp?;
      if (ts == null) continue;

      final day = _dateOnly(ts.toDate());
      final key = _dayKey(day);

      counts[key] = (counts[key] ?? 0) + 1;
    }

    return counts;
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  void _scheduleDayRolloverCheck() {
    _dayRolloverTimer?.cancel();

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final delay = tomorrow.difference(now) + const Duration(seconds: 2);

    _dayRolloverTimer = Timer(delay, () {
      _handlePossibleDayRollover(showMessage: true);
    });
  }

  void _handlePossibleDayRollover({required bool showMessage}) {
    final today = _dateOnly(DateTime.now());
    final previousDay = _currentLocalDay;
    _currentLocalDay = today;
    _scheduleDayRolloverCheck();

    if (isSameDay(previousDay, today)) return;
    if (!mounted) return;

    final wasShowingCurrentDay = isSameDay(_selectedDay, previousDay);
    if (!wasShowingCurrentDay) return;

    setState(() {
      _selectedDay = today;
      _focusedDay = today;
    });

    if (showMessage && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nowy dzień - odświeżono widok Mój Dzień.'),
        ),
      );
    }
  }

  void _scheduleInitialLoadingDialog() {
    _initialLoadingDialogTimer?.cancel();
    _initialLoadingDialogTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || !_projectsLoading || _projectsLoaded) return;
      _showInitialLoadingDialog();
    });
  }

  void _showInitialLoadingDialog() {
    if (_initialLoadingDialogVisible) return;

    _initialLoadingDialogVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _AppPalette.brand,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Czekaj chwile, synchronizuję wpisy...',
                style: TextStyle(
                  fontFamily: _AppPalette.bodyFont,
                  color: _AppPalette.text,
                ),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      _initialLoadingDialogVisible = false;
    });
  }

  void _dismissInitialLoadingDialog() {
    _initialLoadingDialogTimer?.cancel();
    if (!_initialLoadingDialogVisible || !mounted) return;

    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<String> _readUserName(User user) async {
    final display = (user.displayName ?? '').trim();
    if (display.isNotEmpty) return display;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final name = (snap.data()?['name'] as String?)?.trim() ?? '';
    if (name.isNotEmpty) return name;

    return (user.email ?? 'Unknown user').trim();
  }

  Future<List<Map<String, String>>> _loadProjects() async {
    final db = FirebaseFirestore.instance;
    final customersSnap = await db.collection('customers').get();

    final List<Map<String, String>> out = [];

    for (final customerDoc in customersSnap.docs) {
      final customerId = customerDoc.id;
      final customerData = customerDoc.data();
      final customerName = ((customerData['name'] as String?) ?? '').trim();

      final projectsSnap = await db
          .collection('customers')
          .doc(customerId)
          .collection('projects')
          .get();

      for (final projectDoc in projectsSnap.docs) {
        final data = projectDoc.data();

        final archived = data['archived'] == true;
        if (archived) continue;

        final title = ((data['title'] as String?) ?? '').trim();
        final fallbackName = ((data['name'] as String?) ?? '').trim();
        final projectName = title.isNotEmpty ? title : fallbackName;

        if (projectName.isEmpty) continue;

        out.add({
          'projectId': projectDoc.id,
          'projectName': projectName,
          'customerId': customerId,
          'customerName': customerName,
        });
      }
    }

    out.sort((a, b) {
      final ap = (a['projectName'] ?? '').toLowerCase();
      final bp = (b['projectName'] ?? '').toLowerCase();
      return ap.compareTo(bp);
    });

    return out;
  }

  Future<void> _ensureProjectsLoaded({bool forceRefresh = false}) async {
    if (_projectsLoading) return;
    if (_projectsLoaded && !forceRefresh) return;

    setState(() {
      _projectsLoading = true;
    });

    try {
      final projects = await _loadProjects();

      if (!mounted) return;

      setState(() {
        _projectsCache = projects;
        _projectsLoaded = true;
        _projectsLoading = false;
      });
      _dismissInitialLoadingDialog();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _projectsLoading = false;
      });
      _dismissInitialLoadingDialog();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się szukać projektów: $e')),
      );
    }
  }

  Future<Map<String, String>?> _pickProjectDialog(
    List<Map<String, String>> projects,
  ) async {
    final searchCtrl = TextEditingController();
    List<Map<String, String>> filtered = List.of(projects);

    return showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            void applyFilter(String value) {
              final q = value.trim().toLowerCase();

              setLocalState(() {
                if (q.isEmpty) {
                  filtered = List.of(projects);
                } else {
                  filtered = projects.where((p) {
                    final projectName = (p['projectName'] ?? '').toLowerCase();
                    final customerName = (p['customerName'] ?? '')
                        .toLowerCase();
                    return projectName.contains(q) || customerName.contains(q);
                  }).toList();
                }
              });
            }

            final media = MediaQuery.of(context);
            final screenHeight = media.size.height;
            final screenWidth = media.size.width;

            final dialogHeight = screenHeight * 0.72;

            return SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Dialog(
                    insetPadding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: screenWidth > 500 ? 460 : screenWidth - 32,
                      height: dialogHeight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Wybierz projekt',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: searchCtrl,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'Szukaj projektu...',
                                prefixIcon: const Icon(Icons.search),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: _AppPalette.line,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: _AppPalette.brand,
                                    width: 1.5,
                                  ),
                                ),
                                labelStyle: const TextStyle(
                                  fontFamily: _AppPalette.bodyFont,
                                  color: _AppPalette.muted,
                                ),
                                hintStyle: const TextStyle(
                                  fontFamily: _AppPalette.bodyFont,
                                  color: _AppPalette.muted,
                                ),
                              ),
                              onChanged: applyFilter,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: filtered.isEmpty
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text(
                                          'Brak pasujących projektów',
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior
                                              .onDrag,
                                      itemCount: filtered.length + 1,
                                      separatorBuilder: (_, __) =>
                                          const Divider(
                                            height: 1,
                                            color: _AppPalette.line,
                                            thickness: 1,
                                          ),
                                      itemBuilder: (context, index) {
                                        if (index == 0) {
                                          return ListTile(
                                            leading: const Icon(Icons.clear),
                                            title: const Text('Brak projektu'),
                                            onTap: () {
                                              Navigator.pop(dialogContext, {
                                                'projectId': '',
                                                'projectName': '',
                                                'customerId': '',
                                                'customerName': '',
                                              });
                                            },
                                          );
                                        }

                                        final p = filtered[index - 1];
                                        final projectName =
                                            p['projectName'] ?? '';
                                        final customerName =
                                            p['customerName'] ?? '';

                                        return ListTile(
                                          title: Text(
                                            projectName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: _AppPalette.bodyFont,
                                              color: _AppPalette.text,
                                            ),
                                          ),
                                          subtitle: customerName.isEmpty
                                              ? null
                                              : Text(
                                                  customerName,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontFamily:
                                                        _AppPalette.bodyFont,
                                                    color: _AppPalette.muted,
                                                  ),
                                                ),
                                          onTap: () {
                                            Navigator.pop(dialogContext, p);
                                          },
                                        );
                                      },
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: _AppPalette.muted,
                                ),
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                },
                                child: const Text('Anuluj'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, String>> _getNextFreeTimeSlot() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {'startTime': '08:00', 'endTime': '09:00'};
    }

    final snap = await FirebaseFirestore.instance
        .collection('work_day_logs')
        .where('userId', isEqualTo: user.uid)
        .where('dayKey', isEqualTo: _dayKey(_selectedDay))
        .orderBy('startMinutes')
        .get();

    int candidateStart = 8 * 60;
    const int slotLength = 60;
    const int dayEnd = 23 * 60;

    for (final doc in snap.docs) {
      final data = doc.data();
      final existingStart = (data['startMinutes'] as num?)?.toInt();
      final existingEnd = (data['endMinutes'] as num?)?.toInt();

      if (existingStart == null || existingEnd == null) continue;

      if (candidateStart + slotLength <= existingStart) {
        break;
      }

      if (candidateStart < existingEnd) {
        candidateStart = existingEnd;
      }
    }

    if (candidateStart + slotLength > dayEnd) {
      candidateStart = 8 * 60;
    }

    String toTime(int minutes) {
      final h = (minutes ~/ 60).toString().padLeft(2, '0');
      final m = (minutes % 60).toString().padLeft(2, '0');
      return '$h:$m';
    }

    return {
      'startTime': toTime(candidateStart),
      'endTime': toTime(candidateStart + slotLength),
    };
  }

  Future<void> _showEntryDialog({
    DocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    if (!_isToday(_selectedDay)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Można dodawać i edytować wpisy tylko na dzisiejszy dzień',
          ),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_projectsLoaded && !_projectsLoading) {
      await _ensureProjectsLoaded();
    }

    final projects = _projectsCache;
    final data = doc?.data();

    final suggestedSlot = doc == null ? await _getNextFreeTimeSlot() : null;

    final startCtrl = TextEditingController(
      text: data?['startTime'] as String? ?? suggestedSlot?['startTime'] ?? '',
    );
    final endCtrl = TextEditingController(
      text: data?['endTime'] as String? ?? suggestedSlot?['endTime'] ?? '',
    );
    final descCtrl = TextEditingController(
      text: data?['description'] as String? ?? '',
    );

    String? selectedProjectId = data?['projectId'] as String?;
    String? selectedProjectName = data?['projectName'] as String?;
    String? selectedCustomerId = data?['customerId'] as String?;

    TimeOfDay? parseTime(String raw) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      final parts = s.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      if (h < 0 || h > 23 || m < 0 || m > 59) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    String formatTime(TimeOfDay t) {
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    Future<void> pickStart(StateSetter setLocalState) async {
      final initial =
          parseTime(startCtrl.text) ?? const TimeOfDay(hour: 8, minute: 0);

      final picked = await showTimePicker(
        context: context,
        initialTime: initial,
        helpText: 'Czas start',
      );
      if (picked == null) return;

      setLocalState(() {
        startCtrl.text = formatTime(picked);
      });

      final currentEnd = parseTime(endCtrl.text);
      final autoEnd =
          currentEnd ??
          TimeOfDay(hour: (picked.hour + 1) % 24, minute: picked.minute);

      final pickedEnd = await showTimePicker(
        context: context,
        initialTime: autoEnd,
        helpText: 'Czas koniec',
      );
      if (pickedEnd == null) return;

      setLocalState(() {
        endCtrl.text = formatTime(pickedEnd);
      });
    }

    Future<void> pickEnd(StateSetter setLocalState) async {
      final initial =
          parseTime(endCtrl.text) ?? const TimeOfDay(hour: 16, minute: 0);
      final picked = await showTimePicker(
        context: context,
        initialTime: initial,
        helpText: 'Czas koniec',
      );
      if (picked == null) return;
      setLocalState(() {
        endCtrl.text = formatTime(picked);
      });
    }

    int? toMinutes(String raw) {
      final t = parseTime(raw);
      if (t == null) return null;
      return t.hour * 60 + t.minute;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: _AppPalette.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titleTextStyle: const TextStyle(
                fontFamily: _AppPalette.headlineFont,
                fontWeight: FontWeight.w800,
                color: _AppPalette.text,
                fontSize: 17,
                letterSpacing: 0,
              ),
              contentTextStyle: const TextStyle(
                fontFamily: _AppPalette.bodyFont,
                color: _AppPalette.muted,
                fontSize: 14,
              ),
              title: Text(
                doc == null ? 'Dodaj wpis o pracy' : 'Edytuj wpis o pracy',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: startCtrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Czas start',
                              suffixIcon: const Icon(Icons.access_time),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: _AppPalette.line,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: _AppPalette.brand,
                                  width: 1.5,
                                ),
                              ),
                              labelStyle: const TextStyle(
                                fontFamily: _AppPalette.bodyFont,
                                color: _AppPalette.muted,
                              ),
                              hintStyle: const TextStyle(
                                fontFamily: _AppPalette.bodyFont,
                                color: _AppPalette.muted,
                              ),
                            ),
                            onTap: () => pickStart(setLocalState),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: endCtrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Czas koniec',
                              suffixIcon: const Icon(Icons.access_time),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: _AppPalette.line,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: _AppPalette.brand,
                                  width: 1.5,
                                ),
                              ),
                              labelStyle: const TextStyle(
                                fontFamily: _AppPalette.bodyFont,
                                color: _AppPalette.muted,
                              ),
                              hintStyle: const TextStyle(
                                fontFamily: _AppPalette.bodyFont,
                                color: _AppPalette.muted,
                              ),
                            ),
                            onTap: () => pickEnd(setLocalState),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await _pickProjectDialog(projects);
                        if (picked == null) return;

                        setLocalState(() {
                          final pid = (picked['projectId'] ?? '').trim();
                          final pname = (picked['projectName'] ?? '').trim();
                          final cid = (picked['customerId'] ?? '').trim();

                          selectedProjectId = pid.isEmpty ? null : pid;
                          selectedProjectName = pname.isEmpty ? null : pname;
                          selectedCustomerId = cid.isEmpty ? null : cid;
                        });
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Projekt',
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: _AppPalette.line,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: _AppPalette.brand,
                              width: 1.5,
                            ),
                          ),
                          labelStyle: const TextStyle(
                            fontFamily: _AppPalette.bodyFont,
                            color: _AppPalette.muted,
                          ),
                          hintStyle: const TextStyle(
                            fontFamily: _AppPalette.bodyFont,
                            color: _AppPalette.muted,
                          ),
                        ),
                        child: Text(
                          (selectedProjectName != null &&
                                  selectedProjectName!.trim().isNotEmpty)
                              ? selectedProjectName!
                              : 'Brak projektu',
                          style: TextStyle(
                            color:
                                (selectedProjectName != null &&
                                    selectedProjectName!.trim().isNotEmpty)
                                ? null
                                : _AppPalette.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Opis',
                        hintText: 'Co było robiony?',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _AppPalette.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: _AppPalette.brand,
                            width: 1.5,
                          ),
                        ),
                        labelStyle: const TextStyle(
                          fontFamily: _AppPalette.bodyFont,
                          color: _AppPalette.muted,
                        ),
                        hintStyle: const TextStyle(
                          fontFamily: _AppPalette.bodyFont,
                          color: _AppPalette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: _AppPalette.muted,
                  ),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Anuluj'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AppPalette.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    final startTime = startCtrl.text.trim();
                    final endTime = endCtrl.text.trim();
                    final description = descCtrl.text.trim();

                    final startMinutes = toMinutes(startTime);
                    final endMinutes = toMinutes(endTime);

                    if (startMinutes == null || endMinutes == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Ustaw prawidlłowo czas start i koniec',
                          ),
                        ),
                      );
                      return;
                    }

                    if (endMinutes <= startMinutes) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Data zakończenie musi być później niż czas rozpoczęcia',
                          ),
                        ),
                      );
                      return;
                    }

                    if ((selectedProjectId == null ||
                            selectedProjectId!.isEmpty) &&
                        description.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Wybierz projekt lub dodaj opis'),
                        ),
                      );
                      return;
                    }

                    try {
                      final existingEntries = await FirebaseFirestore.instance
                          .collection('work_day_logs')
                          .where('userId', isEqualTo: user.uid)
                          .where('dayKey', isEqualTo: _dayKey(_selectedDay))
                          .get();

                      bool hasConflict = false;

                      for (final existingDoc in existingEntries.docs) {
                        if (doc != null && existingDoc.id == doc.id) {
                          continue;
                        }

                        final existingData = existingDoc.data();
                        final existingStart =
                            (existingData['startMinutes'] as num?)?.toInt();
                        final existingEnd = (existingData['endMinutes'] as num?)
                            ?.toInt();

                        if (existingStart == null || existingEnd == null) {
                          continue;
                        }

                        if (_timesOverlap(
                          startA: startMinutes,
                          endA: endMinutes,
                          startB: existingStart,
                          endB: existingEnd,
                        )) {
                          hasConflict = true;
                          break;
                        }
                      }

                      if (hasConflict) {
                        await showDialog<void>(
                          context: dialogContext,
                          builder: (conflictDialogContext) => AlertDialog(
                            title: const Text(
                              'Istnieje wpis o tej godzinie.\nWybierz inny czas! 🤪',
                            ),
                            // content: const Text(
                            //   'Istnieje wpis o tej godzinie. Wybierz inny czas!',
                            // ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(conflictDialogContext),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }

                      final userName = await _readUserName(user);
                      final durationMinutes = endMinutes - startMinutes;

                      final payload = <String, dynamic>{
                        'userId': user.uid,
                        'userName': userName,
                        'userEmail': user.email,
                        'dayKey': _dayKey(_selectedDay),
                        'workDate': Timestamp.fromDate(
                          DateTime(
                            _selectedDay.year,
                            _selectedDay.month,
                            _selectedDay.day,
                          ),
                        ),
                        'startTime': startTime,
                        'endTime': endTime,
                        'startMinutes': startMinutes,
                        'endMinutes': endMinutes,
                        'durationMinutes': durationMinutes,
                        'projectId': selectedProjectId,
                        'projectName': selectedProjectName,
                        'customerId': selectedCustomerId,
                        'description': description,
                        'updatedAt': FieldValue.serverTimestamp(),
                      };

                      final col = FirebaseFirestore.instance.collection(
                        'work_day_logs',
                      );

                      if (doc == null) {
                        payload['createdAt'] = FieldValue.serverTimestamp();
                        await col.add(payload);
                        await EventLogService.workDayEntryCreated(
                          dayKey: _dayKey(_selectedDay),
                          startTime: startTime,
                          endTime: endTime,
                          projectName: selectedProjectName,
                          description: description,
                        );
                      } else {
                        await doc.reference.update(payload);
                        await EventLogService.workDayEntryUpdated(
                          dayKey: _dayKey(_selectedDay),
                          startTime: startTime,
                          endTime: endTime,
                          projectName: selectedProjectName,
                          description: description,
                        );
                      }

                      if (!mounted) return;
                      Navigator.pop(dialogContext);
                    } catch (e) {
                      await EventLogService.workDayEntrySaveFailed(
                        operation: doc == null ? 'create' : 'update',
                        dayKey: _dayKey(_selectedDay),
                        startTime: startTime,
                        endTime: endTime,
                        projectName: selectedProjectName,
                        description: description,
                        error: e,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Nie udało się zapisać wpisu: $e'),
                        ),
                      );
                    }
                  },
                  child: const Text('Zapisz'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEntry(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          fontFamily: _AppPalette.headlineFont,
          fontWeight: FontWeight.w800,
          color: _AppPalette.text,
          fontSize: 17,
          letterSpacing: 0,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: _AppPalette.bodyFont,
          color: _AppPalette.muted,
          fontSize: 14,
        ),
        title: const Text('Usuń wpis?'),
        content: const Text('Wpis zostanie usunięty?.'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _AppPalette.muted),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppPalette.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final data = doc.data();
    final dayKey = (data?['dayKey'] as String?) ?? '';
    final startTime = (data?['startTime'] as String?) ?? '';
    final endTime = (data?['endTime'] as String?) ?? '';
    final projectName = data?['projectName'] as String?;

    try {
      await doc.reference.delete();
      await EventLogService.workDayEntryDeleted(
        dayKey: dayKey,
        startTime: startTime,
        endTime: endTime,
        projectName: projectName,
      );
    } catch (e) {
      await EventLogService.workDayEntryDeleteFailed(
        dayKey: dayKey,
        startTime: startTime,
        endTime: endTime,
        projectName: projectName,
        error: e,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Nie udało się usunąć wpisu: $e')));
    }
  }

  String _hoursLabel(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (minutes == 0) {
      return '$hours h';
    }

    return '$hours.${minutes.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('No signed-in user')));
    }

    final query = FirebaseFirestore.instance
        .collection('work_day_logs')
        .where('userId', isEqualTo: uid)
        .where('dayKey', isEqualTo: _dayKey(_selectedDay))
        .orderBy('startMinutes');

    final dateLabel = DateFormat('dd.MM.yyyy').format(_selectedDay);
    final isTodaySelected = _isToday(_selectedDay);

    final monthStart = _firstDayOfMonth(_focusedDay);
    final nextMonthStart = _firstDayOfNextMonth(_focusedDay);

    final monthQuery = FirebaseFirestore.instance
        .collection('work_day_logs')
        .where('userId', isEqualTo: uid)
        .where(
          'workDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
        )
        .where('workDate', isLessThan: Timestamp.fromDate(nextMonthStart));

    return AppScaffold(
      title: 'Mój Dzień',
      body: SafeArea(
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: monthQuery.snapshots(),
              builder: (context, monthSnap) {
                final monthDocs = monthSnap.data?.docs ?? const [];
                final dayCounts = _buildDayCounts(monthDocs);

                int countForDay(DateTime day) {
                  return dayCounts[_dayKey(_dateOnly(day))] ?? 0;
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: [
                      Card(
                        color: _AppPalette.surface,
                        surfaceTintColor: Colors.transparent,
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: TableCalendar<dynamic>(
                            locale: 'pl_PL',
                            firstDay: DateTime(2024, 1, 1),
                            lastDay: DateTime(2100, 12, 31),
                            focusedDay: _focusedDay,
                            currentDay: DateTime.now(),
                            calendarFormat: _calendarFormat,
                            availableCalendarFormats: const {
                              CalendarFormat.week: 'Tydzień',
                              CalendarFormat.month: 'Miesiąc',
                            },
                            onFormatChanged: (format) {
                              setState(() {
                                _calendarFormat = format;
                              });
                            },
                            startingDayOfWeek: StartingDayOfWeek.monday,
                            selectedDayPredicate: (day) {
                              return isSameDay(_selectedDay, day);
                            },
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = _dateOnly(selectedDay);
                                _focusedDay = _dateOnly(focusedDay);
                              });
                            },
                            onPageChanged: (focusedDay) {
                              setState(() {
                                _focusedDay = _dateOnly(focusedDay);
                              });
                            },
                            eventLoader: (day) {
                              final count = countForDay(day);
                              if (count <= 0) return const [];
                              return List.generate(count, (index) => index);
                            },
                            headerStyle: const HeaderStyle(
                              formatButtonVisible: true,
                              titleCentered: true,
                              formatButtonShowsNext: false,
                            ),
                            calendarStyle: const CalendarStyle(
                              markersMaxCount: 1,
                              outsideDaysVisible: true,
                            ),
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, day, events) {
                                final count = countForDay(day);
                                if (count == 0) return const SizedBox.shrink();

                                return Positioned(
                                  bottom: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _AppPalette.brand,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.calendar_today),
                              label: Text('Data: $dateLabel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _AppPalette.brand,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: (_projectsLoading || !isTodaySelected)
                                ? null
                                : () async {
                                    if (!_projectsLoaded) {
                                      await _ensureProjectsLoaded();
                                    }
                                    if (!mounted) return;
                                    _showEntryDialog();
                                  },
                            icon: _projectsLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add),
                            label: Text(
                              _projectsLoading ? 'Prepping...' : 'Dodaj',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: query.snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: _AppPalette.brand,
                      ),
                    );
                  }

                  final docs = snap.data?.docs ?? const [];
                  int totalMinutes = 0;

                  for (final d in docs) {
                    final data = d.data();
                    totalMinutes +=
                        (data['durationMinutes'] as num?)?.toInt() ?? 0;
                  }

                  if (docs.isEmpty) {
                    return Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Text(
                              'Brak wpisów za ten dzień',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Card(
                            color: _AppPalette.surface,
                            surfaceTintColor: Colors.transparent,
                            elevation: 1,
                            child: ListTile(
                              leading: const Icon(Icons.schedule),
                              title: const Text('Suma godzin'),
                              trailing: Text(_hoursLabel(totalMinutes)),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();

                            final startTime =
                                (data['startTime'] as String?) ?? '';
                            final endTime = (data['endTime'] as String?) ?? '';
                            final projectName =
                                (data['projectName'] as String?) ?? '';
                            final description =
                                (data['description'] as String?) ?? '';

                            final subtitleParts = <String>[
                              if (projectName.isNotEmpty)
                                'Projekt: $projectName',
                              if (description.isNotEmpty) description,
                            ];

                            return Card(
                              color: _AppPalette.surface,
                              surfaceTintColor: Colors.transparent,
                              elevation: 1,
                              child: ListTile(
                                title: Text('$startTime - $endTime'),
                                subtitle: subtitleParts.isEmpty
                                    ? null
                                    : Text(subtitleParts.join('\n')),
                                isThreeLine: subtitleParts.length > 1,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEntryDialog(doc: doc);
                                    } else if (value == 'delete') {
                                      _deleteEntry(doc);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    if (isTodaySelected)
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edytuj'),
                                      ),
                                    if (isTodaySelected)
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Usuń'),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.schedule),
                            title: const Text('Suma godzin'),
                            trailing: Text(_hoursLabel(totalMinutes)),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
