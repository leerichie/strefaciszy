// lib/screens/reports_daily.dart

import 'dart:convert';

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:open_file/open_file.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
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

  static const _downloadFunctionUrl =
      'https://us-central1-strefa-ciszy.cloudfunctions.net/downloadDailyRwReportHttp';

  static const _backupDownloadFunctionUrl =
      'https://us-central1-strefa-ciszy.cloudfunctions.net/downloadReadableBackupHttp';

  static const _manualBackupFunctionUrl =
      'https://us-central1-strefa-ciszy.cloudfunctions.net/createAndDownloadReadableBackupHttp';

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

  bool _isDownloading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // BACKUP auto

  Future<void> _downloadReadableBackup(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _statusMessage = 'Brak zalogowanego użytkownika.';
      });
      return;
    }

    final dayKey = DateFormat('yyyy-MM-dd').format(date);

    setState(() {
      _isDownloading = true;
      _statusMessage = null;
    });

    try {
      final token = await user.getIdToken();

      final resp = await http.post(
        Uri.parse(_backupDownloadFunctionUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'dayKey': dayKey}),
      );

      if (resp.statusCode == 200) {
        final bytes = Uint8List.fromList(resp.bodyBytes);
        final fileName = 'readable_backup_$dayKey.xlsx';

        if (kIsWeb) {
          await FileSaver.instance.saveFile(
            name: fileName,
            bytes: bytes,
            mimeType: MimeType.microsoftExcel,
          );
        } else {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(bytes, flush: true);

          final ok = await copyFileIntoDownloadFolder(tempFile.path, fileName);

          if (ok == true) {
            final downloadDir = await getDownloadDirectory();
            final savedPath = '${downloadDir.path}/$fileName';
            await OpenFile.open(savedPath);
          }
        }

        setState(() {
          _statusMessage = 'Pobrano backup za $dayKey.';
        });
      } else {
        String msg = 'Błąd backupu: ${resp.statusCode}';
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
    } catch (e) {
      setState(() {
        _statusMessage = 'Błąd pobierania backupu: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  // manual bkup
  Future<void> _createAndDownloadReadableBackupNow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _statusMessage = 'Brak zalogowanego użytkownika.';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _statusMessage = null;
    });

    try {
      final token = await user.getIdToken();

      final resp = await http.post(
        Uri.parse(_manualBackupFunctionUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        final bytes = Uint8List.fromList(resp.bodyBytes);
        final dayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final fileName = 'manual_readable_backup_$dayKey.xlsx';

        if (kIsWeb) {
          await FileSaver.instance.saveFile(
            name: fileName,
            bytes: bytes,
            mimeType: MimeType.microsoftExcel,
          );
        } else {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(bytes, flush: true);

          final ok = await copyFileIntoDownloadFolder(tempFile.path, fileName);

          if (ok == true) {
            final downloadDir = await getDownloadDirectory();
            final savedPath = '${downloadDir.path}/$fileName';
            await OpenFile.open(savedPath);
          }
        }

        setState(() {
          _statusMessage = 'Utworzono i pobrano backup.';
        });
      } else {
        String msg = 'Błąd backupu: ${resp.statusCode}';
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
    } catch (e) {
      setState(() {
        _statusMessage = 'Błąd backupu: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  // ice manual download reports
  // Future<void> _downloadReport() async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   if (user == null) {
  //     setState(() {
  //       _statusMessage = 'Brak zalogowanego użytkownika.';
  //     });
  //     return;
  //   }

  //   setState(() {
  //     _isDownloading = true;
  //     _statusMessage = null;
  //   });

  //   try {
  //     final token = await user.getIdToken();

  //     final resp = await http.post(
  //       Uri.parse(_downloadFunctionUrl),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Content-Type': 'application/json',
  //       },
  //       body: jsonEncode({'dayKey': _dayKey}),
  //     );

  //     if (kDebugMode) {
  //       print('downloadDailyRwReportHttp status: ${resp.statusCode}');
  //       print('downloadDailyRwReportHttp headers: ${resp.headers}');
  //     }

  //     if (resp.statusCode == 200) {
  //       final bytes = resp.bodyBytes;
  //       final fileName = 'rw_raport_$_dayKey';

  //       await FileSaver.instance.saveFile(
  //         name: '$fileName.xlsx',
  //         bytes: Uint8List.fromList(bytes),
  //         mimeType: MimeType.microsoftExcel,
  //       );

  //       setState(() {
  //         _statusMessage = 'Pobrano raport za $_dayKey.';
  //       });
  //     } else {
  //       String msg = 'Błąd: ${resp.statusCode}';
  //       try {
  //         final data = jsonDecode(resp.body) as Map<String, dynamic>;
  //         if (data['error'] != null) {
  //           msg += ' – ${data['error']}';
  //         }
  //       } catch (_) {}
  //       setState(() {
  //         _statusMessage = msg;
  //       });
  //     }
  //   } catch (e, st) {
  //     if (kDebugMode) {
  //       print('downloadDailyRwReportHttp exception: $e\n$st');
  //     }
  //     setState(() {
  //       _statusMessage = 'Błąd pobierania: $e';
  //     });
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isDownloading = false;
  //       });
  //     }
  //   }
  // }

  Future<void> _downloadReport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _statusMessage = 'Brak zalogowanego użytkownika.';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _statusMessage = null;
    });

    try {
      final token = await user.getIdToken();

      final resp = await http.post(
        Uri.parse(_downloadFunctionUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'dayKey': _dayKey}),
      );

      if (kDebugMode) {
        print('downloadDailyRwReportHttp status: ${resp.statusCode}');
        print('downloadDailyRwReportHttp headers: ${resp.headers}');
      }

      if (resp.statusCode == 200) {
        final bytes = Uint8List.fromList(resp.bodyBytes);
        final fileName = 'rw_raport_$_dayKey.xlsx';

        if (kIsWeb) {
          await FileSaver.instance.saveFile(
            name: fileName,
            bytes: bytes,
            mimeType: MimeType.microsoftExcel,
          );

          setState(() {
            _statusMessage = 'Pobrano raport za $_dayKey.';
          });
        } else {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(bytes, flush: true);

          final ok = await copyFileIntoDownloadFolder(tempFile.path, fileName);

          if (ok == true) {
            final downloadDir = await getDownloadDirectory();
            final savedPath = '${downloadDir.path}/$fileName';

            await OpenFile.open(savedPath);

            setState(() {
              _statusMessage = 'Raport zapisany w Downloads.';
            });
          } else {
            setState(() {
              _statusMessage = 'Nie udało się zapisać raport.';
            });
          }
        }
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
        print('downloadDailyRwReportHttp exception: $e\n$st');
      }
      setState(() {
        _statusMessage = 'Błąd pobierania: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
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
      context: this.context,
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

        setState(() {
          _statusMessage =
              'Wysłano raport za $_dayKey (dok.: $count)\n'
              'do: $sentTo';
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
    final isWide = MediaQuery.of(context).size.width >= 720;

    const green = Color(0xFF1E7A4D);
    const dark = Color(0xFF202124);
    const softBg = Color(0xFFF8FAF9);
    const cardBorder = Color(0xFFE0E5E2);

    ButtonStyle compactButtonStyle({
      Color? background,
      Color? foreground,
      Color? border,
    }) {
      return OutlinedButton.styleFrom(
        backgroundColor: background ?? Colors.white,
        foregroundColor: foreground ?? dark,
        side: BorderSide(color: border ?? cardBorder),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      );
    }

    Widget sectionCard({required Widget child}) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isWide ? 22 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
    }

    Widget sectionTitle({
      required IconData icon,
      required String title,
      required String subtitle,
      Color iconColor = green,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: dark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return AppScaffold(
      title: 'SC - Administration Panel',
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 28 : 16,
                vertical: 18,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Raport dzienny RW',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: dark,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Wygenerowac dzienny raporty',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),

                      const SizedBox(height: 20),

                      sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sectionTitle(
                              icon: Icons.description_rounded,
                              title: 'Raport dnia',
                              subtitle:
                                  'Pobierz raport RW & MÓJ DZIEŃ za wybrana data.',
                            ),

                            const SizedBox(height: 18),

                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: isWide ? 340 : double.infinity,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Dzień raportu',
                                      filled: true,
                                      fillColor: softBg,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: cardBorder,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: cardBorder,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                    ),
                                    child: Text(
                                      dateLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: dark,
                                      ),
                                    ),
                                  ),
                                ),

                                OutlinedButton.icon(
                                  onPressed: _pickDate,
                                  style: compactButtonStyle(
                                    foreground: green,
                                    border: green.withOpacity(0.45),
                                  ),
                                  icon: const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Zmień'),
                                ),

                                OutlinedButton.icon(
                                  onPressed: _isDownloading
                                      ? null
                                      : _downloadReport,
                                  style: compactButtonStyle(
                                    foreground: green,
                                    border: green.withOpacity(0.45),
                                    background: const Color(0xFFF3FAF6),
                                  ),
                                  icon: _isDownloading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.download_rounded,
                                          size: 19,
                                        ),
                                  label: Text(
                                    _isDownloading
                                        ? 'W toku...'
                                        : 'Pobierz raport',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text(
                        'BACKUP baza',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: dark,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Utworzony codziennie o polnoc i przechowywany przez 3 dni przed nadpisaniem!!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),

                      const SizedBox(height: 20),

                      sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sectionTitle(
                              icon: Icons.cloud_done_rounded,
                              title: 'Backups',
                              subtitle:
                                  'Backupy mozna otwierac jako arkusz (EXCEL).',
                              iconColor: const Color(0xFF8A5A16),
                            ),

                            const SizedBox(height: 18),

                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  onPressed: _isDownloading
                                      ? null
                                      : _createAndDownloadReadableBackupNow,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                    minimumSize: const Size(0, 44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  icon: _isDownloading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.backup_rounded,
                                          size: 19,
                                        ),
                                  label: const Text(
                                    'Ręcznie zrób backup teraz',
                                  ),
                                ),

                                OutlinedButton.icon(
                                  onPressed: _isDownloading
                                      ? null
                                      : () => _downloadReadableBackup(
                                          DateTime.now(),
                                        ),
                                  style: compactButtonStyle(),
                                  icon: const Icon(
                                    Icons.download_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Pobierz najnowszy'),
                                ),

                                OutlinedButton.icon(
                                  onPressed: _isDownloading
                                      ? null
                                      : () => _downloadReadableBackup(
                                          DateTime.now().subtract(
                                            const Duration(days: 1),
                                          ),
                                        ),
                                  style: compactButtonStyle(),
                                  icon: const Icon(
                                    Icons.history_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Pobierz wczorajszy'),
                                ),

                                OutlinedButton.icon(
                                  onPressed: _isDownloading
                                      ? null
                                      : () => _downloadReadableBackup(
                                          DateTime.now().subtract(
                                            const Duration(days: 2),
                                          ),
                                        ),
                                  style: compactButtonStyle(),
                                  icon: const Icon(
                                    Icons.history_toggle_off_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Pobierz z 2 dni temu'),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Container(
                            //   padding: const EdgeInsets.all(12),
                            //   decoration: BoxDecoration(
                            //     color: const Color(0xFFF3FAF6),
                            //     borderRadius: BorderRadius.circular(14),
                            //     border: Border.all(
                            //       color: green.withOpacity(0.18),
                            //     ),
                            //   ),
                            //   child: Row(
                            //     crossAxisAlignment: CrossAxisAlignment.start,
                            //     children: [
                            //       const Icon(
                            //         Icons.info_outline_rounded,
                            //         color: green,
                            //         size: 20,
                            //       ),
                            //       const SizedBox(width: 10),
                            //       Expanded(
                            //         child: Text(
                            //           'Automatyczne backupy są przechowywane maksymalnie przez 3 dni.',
                            //           style: Theme.of(context)
                            //               .textTheme
                            //               .bodySmall
                            //               ?.copyWith(
                            //                 color: Colors.grey.shade800,
                            //               ),
                            //         ),
                            //       ),
                            //     ],
                            //   ),
                            // ),
                          ],
                        ),
                      ),

                      if (_statusMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3FAF6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: green.withOpacity(0.25)),
                          ),
                          child: Text(
                            _statusMessage!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: dark,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),
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
