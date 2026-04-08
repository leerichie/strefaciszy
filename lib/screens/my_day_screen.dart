// screens/my_day_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:table_calendar/table_calendar.dart';

class MyDayScreen extends StatefulWidget {
  const MyDayScreen({super.key});

  @override
  State<MyDayScreen> createState() => _MyDayScreenState();
}

class _MyDayScreenState extends State<MyDayScreen> {
  DateTime _selectedDay = DateTime.now();

  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  List<Map<String, String>> _projectsCache = [];
  bool _projectsLoading = false;
  bool _projectsLoaded = false;

  @override
  void initState() {
    super.initState();
    _ensureProjectsLoaded();
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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _projectsLoading = false;
      });

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
            final keyboardInset = media.viewInsets.bottom;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: SafeArea(
                child: Center(
                  child: Dialog(
                    insetPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: screenWidth > 500 ? 460 : screenWidth - 32,
                        maxHeight: screenHeight * 0.75,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
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
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                hintText: 'Szukaj projektu...',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: applyFilter,
                              onTapOutside: (_) {
                                FocusScope.of(context).unfocus();
                              },
                              onSubmitted: (_) {
                                FocusScope.of(context).unfocus();
                              },
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
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        if (index == 0) {
                                          return ListTile(
                                            dense: false,
                                            leading: const Icon(Icons.clear),
                                            title: const Text('Brak projektu'),
                                            onTap: () {
                                              FocusScope.of(
                                                dialogContext,
                                              ).unfocus();
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
                                          dense: false,
                                          title: Text(
                                            projectName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: customerName.isEmpty
                                              ? null
                                              : Text(
                                                  customerName,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                          onTap: () {
                                            FocusScope.of(
                                              dialogContext,
                                            ).unfocus();
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
                                onPressed: () {
                                  FocusScope.of(dialogContext).unfocus();
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

  // Future<void> _pickDay() async {
  //   final picked = await showDatePicker(
  //     context: context,
  //     initialDate: _selectedDay,
  //     firstDate: DateTime(2024),
  //     lastDate: DateTime(2100),
  //   );

  //   if (picked == null) return;

  //   setState(() {
  //     _selectedDay = DateTime(picked.year, picked.month, picked.day);
  //   });
  // }

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

    final startCtrl = TextEditingController(
      text: data?['startTime'] as String? ?? '',
    );
    final endCtrl = TextEditingController(
      text: data?['endTime'] as String? ?? '',
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
                            decoration: const InputDecoration(
                              labelText: 'Czas start',
                              suffixIcon: Icon(Icons.access_time),
                            ),
                            onTap: () => pickStart(setLocalState),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: endCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Czas koniec',
                              suffixIcon: Icon(Icons.access_time),
                            ),
                            onTap: () => pickEnd(setLocalState),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                        decoration: const InputDecoration(
                          labelText: 'Projekt',
                          suffixIcon: Icon(Icons.arrow_drop_down),
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
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Opis',
                        hintText: 'Co było robiony?',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Anuluj'),
                ),
                ElevatedButton(
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
                    } else {
                      await doc.reference.update(payload);
                    }

                    if (!mounted) return;
                    Navigator.pop(dialogContext);
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
        title: const Text('Usuń wpis?'),
        content: const Text('Wpis zostanie usunięty?.'),
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

    if (ok != true) return;
    await doc.reference.delete();
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
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
                                    ),
                                  )
                                : const Icon(Icons.add),
                            label: Text(
                              _projectsLoading ? 'Ładowanie...' : 'Dodaj',
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
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data?.docs ?? const [];
                  int totalMinutes = 0;

                  for (final d in docs) {
                    final data = d.data();
                    totalMinutes +=
                        (data['durationMinutes'] as num?)?.toInt() ?? 0;
                  }
                  // final allDocs = snap.data?.docs ?? const [];

                  // final docs =
                  //     allDocs.where((d) {
                  //       final data = d.data();
                  //       return (data['dayKey'] as String?) ==
                  //           _dayKey(_selectedDay);
                  //     }).toList()..sort((a, b) {
                  //       final am =
                  //           (a.data()['startMinutes'] as num?)?.toInt() ?? 0;
                  //       final bm =
                  //           (b.data()['startMinutes'] as num?)?.toInt() ?? 0;
                  //       return am.compareTo(bm);
                  //     });

                  // int totalMinutes = 0;

                  // for (final d in docs) {
                  //   final data = d.data();
                  //   totalMinutes +=
                  //       (data['durationMinutes'] as num?)?.toInt() ?? 0;
                  // }

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

                                    // FUTURE OPTION:
                                    // if you ever want to disable delete again,
                                    // comment out the delete block above
                                    // and also comment out the delete menu item below.
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

                                    // DELETE HIDDEN VERSION FOR LATER:
                                    // if (isTodaySelected)
                                    //   const PopupMenuItem(
                                    //     value: 'delete',
                                    //     child: Text('Usuń'),
                                    //   ),
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
