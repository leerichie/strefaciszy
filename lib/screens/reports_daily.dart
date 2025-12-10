// lib/screens/reports_daily.dart

import 'dart:convert';

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

  // adjust if you use a different region / project
  static const _functionUrl =
      'https://us-central1-strefa-ciszy.cloudfunctions.net/sendDailyRwReportHttp';

  String get _dayKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
      body: Padding(
        padding: const EdgeInsets.all(16),
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
                // hintText: 'pozostaw puste, aby użyć REPORTS_TO',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // const Spacer(),
            Text(
              'Zostaw email puste aby raport wysłać na domyślne EMAIL. \n'
              'Jeśli dodasz email raport idzie tylko na podany adres.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_isSending ? 'Wysyłanie…' : 'Wyślij raport'),
              ),
            ),
            const SizedBox(height: 24),
            if (_statusMessage != null)
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
          ],
        ),
      ),
    );
  }
}
