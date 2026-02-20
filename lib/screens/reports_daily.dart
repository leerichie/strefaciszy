// lib/screens/reports_daily.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';

class ReportsDailyScreen extends StatefulWidget {
  const ReportsDailyScreen({super.key});

  @override
  State<ReportsDailyScreen> createState() => _ReportsDailyScreenState();
}

class _ReportsDailyScreenState extends State<ReportsDailyScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isSending = false;
  String? _statusMessage;
  final TextEditingController _emailController = TextEditingController();

  static const _functionUrl =
      'https://us-central1-strefa-ciszy.cloudfunctions.net/sendDailyRwReportHttp';

  String get _dayKey => DateFormat('yyyy-MM-dd').format(_selectedDate);
  static const String _devEmail = 'leerichie@wp.pl';

  static const String _devCustomerId = 'hjX1oWT4RrH9UkGbJUYt';
  static const String _devProjectId = 'RqTUcyIGnGJ1ErsuVJn';
  static const String _devCustomerName = 'aaa lee **test**';
  static const String _devProjectName = 'RW COPY TEST';

  bool get _isDevUser {
    final u = FirebaseAuth.instance.currentUser;
    final email = (u?.email ?? '').toLowerCase().trim();
    return email == _devEmail.toLowerCase();
  }

  bool _isDevRunning = false;
  String? _devStatus;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _devAppendNoteToTodayRw() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _devStatus = 'Brak zalogowanego użytkownika.');
      return;
    }

    setState(() {
      _isDevRunning = true;
      _devStatus = null;
    });

    try {
      final db = FirebaseFirestore.instance;

      final proj = db
          .collection('customers')
          .doc(_devCustomerId)
          .collection('projects')
          .doc(_devProjectId);

      final now = DateTime.now().toLocal();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));

      final q = await proj
          .collection('rw_documents')
          .where('type', isEqualTo: 'RW')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThan: end)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      DocumentReference<Map<String, dynamic>> rwRef;

      if (q.docs.isNotEmpty) {
        rwRef = q.docs.first.reference;
      } else {
        rwRef = proj.collection('rw_documents').doc();
        await rwRef.set({
          'type': 'RW',
          'customerId': _devCustomerId,
          'projectId': _devProjectId,
          'customerName': _devCustomerName,
          'projectName': _devProjectName,
          'createdDay': start,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': user.uid,
          'createdByName': user.email ?? 'dev',
          'items': <Map<String, dynamic>>[],
          'notesList': <Map<String, dynamic>>[],
        });
      }

      final note = <String, dynamic>{
        'text':
            'DEV TEST NOTE • ${DateFormat('HH:mm:ss').format(DateTime.now())}',
        'userName': user.email ?? 'dev',
        'createdAt': Timestamp.now(),
        'action': 'DEV_BUTTON',
        'color': 'black',
        'sourceTaskId': 'dev_${DateTime.now().millisecondsSinceEpoch}',
      };

      await rwRef.update({
        'notesList': FieldValue.arrayUnion([note]),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': user.uid,
        'lastUpdatedByName': user.email ?? 'dev',
      });

      setState(() {
        _devStatus =
            'OK: dopisano notatkę do RW (dzisiaj).\n'
            'customerId=$_devCustomerId\n'
            'projectId=$_devProjectId\n'
            'rwId=${rwRef.id}';
      });
    } catch (e) {
      setState(() => _devStatus = 'DEV ERROR: $e');
    } finally {
      if (mounted) setState(() => _isDevRunning = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1, 1, 1);
    final last = DateTime(now.year + 1, 12, 31);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: first,
      lastDate: last,
      locale: const Locale('pl', 'PL'),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _statusMessage = null;
      });
    }
  }

  Future<void> _sendReport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _statusMessage = 'Brak zalogowanego użytkownika.';
      });
      return;
    }

    final customEmail = _emailController.text.trim();

    setState(() {
      _isSending = true;
      _statusMessage = null;
    });

    try {
      final token = await user.getIdToken();

      final body = <String, dynamic>{'dayKey': _dayKey};
      if (customEmail.isNotEmpty) {
        body['to'] = customEmail;
      }

      final resp = await http.post(
        Uri.parse(_functionUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        print('sendDailyRwReportHttp status: ${resp.statusCode}');
        print('sendDailyRwReportHttp body: ${resp.body}');
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final count = data['count'] ?? '?';
        final sentTo =
            data['sentTo'] ??
            (customEmail.isNotEmpty ? customEmail : '(domyślny)');
        final usedOverride = data['usedOverride'] == true;

        setState(() {
          _statusMessage =
              'Wysłano raport za $_dayKey (dok.: $count)\n'
              'do: $sentTo'
              '${usedOverride ? " " : " "}';
        });
      } else {
        String msg = 'Błąd: ${resp.statusCode}';
        try {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          if (data['error'] != null) {
            msg += ' – ${data['error']}';
          }
        } catch (_) {}
        setState(() {
          _statusMessage = msg;
        });
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('sendDailyRwReportHttp exception: $e\n$st');
      }
      setState(() {
        _statusMessage = 'Błąd: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd.MM.yyyy', 'pl_PL').format(_selectedDate);

    return AppScaffold(
      title: 'Raport dzienny RW',
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu można wygenerować raporty RW za dowolny dzień i wysłać na wskazany adres email poniżej lub na domyślne ustalony adres info@strefaciszy.net',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Dzień raportu',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(dateLabel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today),
                            label: const Text('Zmień'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Odbiorca email',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Zostaw email puste aby raport wysłać na domyślne EMAIL. \n'
                        'Jeśli dodasz email raport idzie tylko na podany adres.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSending ? null : _sendReport,
                          icon: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            _isSending ? 'Wysyłanie…' : 'Wyślij raport',
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (_statusMessage != null)
                        Card(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _statusMessage!,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                            ),
                          ),
                        ),

                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
