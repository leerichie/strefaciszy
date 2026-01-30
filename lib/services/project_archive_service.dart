// lib/services/project_archive_service.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

class ProjectArchiveService {
  static const String _archiveDocId = 'current';

  // ---------------- Filename extraction ----------------

  static String _filenameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);

      String objectEncoded = '';
      final oIndex = uri.pathSegments.indexOf('o');

      if (oIndex != -1 && oIndex + 1 < uri.pathSegments.length) {
        objectEncoded = uri.pathSegments[oIndex + 1];
      } else if (uri.pathSegments.isNotEmpty) {
        objectEncoded = uri.pathSegments.last;
      }

      final objectPath = Uri.decodeComponent(objectEncoded);
      final filename = objectPath.contains('/')
          ? objectPath.split('/').last
          : objectPath;

      final clean = filename.trim();
      return clean.isEmpty ? 'link' : clean;
    } catch (_) {
      return 'link';
    }
  }

  static void _setHyperlinkCell(
    xlsio.Worksheet sheet, {
    required String cellAddress,
    required String text,
    required String url,
  }) {
    final range = sheet.getRangeByName(cellAddress);
    range.setText(text);
    sheet.hyperlinks.add(range, xlsio.HyperlinkType.url, url);
  }

  static String _fmtDate(dynamic ts) {
    try {
      DateTime dt;
      if (ts is Timestamp) {
        dt = ts.toDate();
      } else if (ts is String) {
        dt = DateTime.tryParse(ts) ?? DateTime(2000);
      } else if (ts is DateTime) {
        dt = ts;
      } else {
        dt = DateTime(2000);
      }
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  static String _detailsToText(dynamic details) {
    if (details == null) return '';
    if (details is String) return details;
    if (details is Map) {
      final entries = <String>[];
      details.forEach((k, v) {
        final kk = k.toString().trim();
        final vv = (v ?? '').toString().trim();
        if (kk.isEmpty && vv.isEmpty) return;
        entries.add('$kk: $vv');
      });
      return entries.join(' | ');
    }
    return details.toString();
  }

  // ================= ARCHIVE =================

  static Future<void> archiveProjectAndCreateFile({
    required String customerId,
    required String projectId,
  }) async {
    final db = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;

    final projRef = db
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);

    final custSnap = await db.collection('customers').doc(customerId).get();
    final projSnap = await projRef.get(const GetOptions(source: Source.server));
    if (!projSnap.exists) return;

    final cust = custSnap.data() ?? <String, dynamic>{};
    final proj = projSnap.data() ?? <String, dynamic>{};

    final customerName = (cust['name'] ?? '–').toString();
    final projectName = (proj['title'] ?? '–').toString();

    final rwSnap = await projRef
        .collection('rw_documents')
        .orderBy('createdAt', descending: false)
        .get(const GetOptions(source: Source.server));

    final rwDocs = rwSnap.docs.map((d) => d.data()).toList();

    final auditSnap = await projRef
        .collection('audit_logs')
        .orderBy('timestamp', descending: false)
        .get(const GetOptions(source: Source.server));

    final auditLogs = auditSnap.docs.map((d) => d.data()).toList();

    final workbook = xlsio.Workbook();

    // ================= SHEET 1: PROJEKT =================
    final s0 = workbook.worksheets[0];
    s0.name = 'Projekt';

    s0.getRangeByName('A1').setText('Klient');
    s0.getRangeByName('B1').setText(customerName);

    s0.getRangeByName('A2').setText('Projekt');
    s0.getRangeByName('B2').setText(projectName);

    s0.getRangeByName('A3').setText('Adres');
    s0.getRangeByName('B3').setText((proj['address'] ?? '').toString());

    s0.getRangeByName('A4').setText('Raporty');
    s0.getRangeByName('B4').setText((proj['description'] ?? '').toString());

    s0.getRangeByName('A5').setText('Bieżące');
    s0.getRangeByName('B5').setText((proj['currentText'] ?? '').toString());

    s0.getRangeByName('A1:A5').cellStyle.bold = true;

    // widths: narrow qty, wide text/link
    s0.getRangeByName('A1').columnWidth = 18;
    s0.getRangeByName('B1').columnWidth = 95;

    int row = 7;

    // ---------------- PRODUCTS (2 cols) ----------------
    s0.getRangeByName('A$row').setText('PRODUKTY');
    s0.getRangeByName('A$row').cellStyle.bold = true;
    row++;

    s0.getRangeByName('A$row').setText('Ilość');
    s0.getRangeByName('B$row').setText('Nazwa');
    s0.getRangeByName('A$row:B$row').cellStyle.bold = true;
    row++;

    final projectItems = (proj['items'] as List?) ?? const [];
    for (final it in projectItems) {
      if (it is! Map) continue;

      final qtyRaw = (it['requestedQty'] ?? it['qty'] ?? it['quantity'] ?? '');
      final qty = qtyRaw.toString().trim();
      final unit = (it['unit'] ?? it['jm'] ?? '').toString().trim();
      final name = (it['customName'] ?? it['name'] ?? it['itemName'] ?? '')
          .toString()
          .trim();

      final qtyUnit = [qty, unit].where((x) => x.isNotEmpty).join(' ');
      s0.getRangeByName('A$row').setText(qtyUnit);
      s0.getRangeByName('B$row').setText(name);
      row++;
    }

    // ---------------- LINKS under products ----------------
    row++; // small gap
    s0.getRangeByName('A$row').setText('LINKI (pliki/fotki)');
    s0.getRangeByName('A$row').cellStyle.bold = true;
    row++;

    // Headers
    s0.getRangeByName('A$row').setText('Nazwa pliku');
    s0.getRangeByName('B$row').setText('URL');
    s0.getRangeByName('A$row:B$row').cellStyle.bold = true;
    row++;

    // Make URL column wide
    s0.getRangeByName('A1').columnWidth = 30; // filename
    s0.getRangeByName('B1').columnWidth = 110; // full url

    // FILES
    final files = (proj['files'] as List?) ?? const [];
    for (final f in files) {
      if (f is! Map) continue;

      final url = (f['url'] ?? '').toString();
      if (url.isEmpty) continue;

      final filename = _filenameFromUrl(url);

      s0.getRangeByName('A$row').setText(filename);
      s0.getRangeByName('B$row').setText(url);
      row++;
    }

    // PHOTOS
    final photos = (proj['photos'] as List?) ?? const [];
    for (final p in photos) {
      final url = p?.toString() ?? '';
      if (url.isEmpty) continue;

      final filename = _filenameFromUrl(url);

      s0.getRangeByName('A$row').setText(filename);
      s0.getRangeByName('B$row').setText(url);
      row++;
    }

    // ================= SHEET 2: RW_MM =================
    final s1 = workbook.worksheets.addWithName('RW_MM');

    // widths
    s1.getRangeByName('A1').columnWidth = 12;
    s1.getRangeByName('B1').columnWidth = 18;
    s1.getRangeByName('C1').columnWidth = 16;
    s1.getRangeByName('D1').columnWidth = 18;
    s1.getRangeByName('E1').columnWidth = 70;
    s1.getRangeByName('F1').columnWidth = 12;
    s1.getRangeByName('G1').columnWidth = 80;

    // header
    s1.getRangeByName('A1').setText('Typ');
    s1.getRangeByName('B1').setText('Utworzono');
    s1.getRangeByName('C1').setText('Użytkownik');
    s1.getRangeByName('D1').setText('Producent');
    s1.getRangeByName('E1').setText('Nazwa');
    s1.getRangeByName('F1').setText('Ilość');
    s1.getRangeByName('G1').setText('Notatki (notesList)');
    s1.getRangeByName('A1:G1').cellStyle.bold = true;

    int r = 2;

    for (final doc in rwDocs) {
      final type = (doc['type'] ?? '').toString();
      final when = _fmtDate(doc['createdAt']);
      final createdByName = (doc['createdByName'] ?? '').toString();

      final items = (doc['items'] as List?) ?? const [];
      final rawNotes = (doc['notesList'] as List?) ?? const [];

      // Build one multiline notes cell for this RW doc (like your RW export dialog)
      String notesText = '';
      if (rawNotes.isNotEmpty) {
        final notesList = rawNotes
            .whereType<Map>()
            .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
            .toList();

        notesList.sort((a, b) {
          final da = a['createdAt'];
          final dbb = b['createdAt'];
          DateTime ta = da is Timestamp ? da.toDate() : DateTime(2000);
          DateTime tb = dbb is Timestamp ? dbb.toDate() : DateTime(2000);
          return ta.compareTo(tb);
        });

        final lines = <String>[];
        for (final m in notesList) {
          final ts = m['createdAt'];
          final tsStr = _fmtDate(ts);
          final u = (m['userName'] ?? '').toString();
          final action = (m['action'] ?? '').toString().trim();
          final text = (m['text'] ?? '').toString();
          final actionPart = action.isNotEmpty ? ': $action' : '';
          lines.add('[$tsStr] $u$actionPart: $text');
        }
        notesText = lines.join('\n');
      }

      if (items.isEmpty) {
        s1.getRangeByName('A$r').setText(type);
        s1.getRangeByName('B$r').setText(when);
        s1.getRangeByName('C$r').setText(createdByName);
        s1.getRangeByName('G$r').setText(notesText);
        r++;
        continue;
      }

      for (final it in items) {
        if (it is! Map) continue;

        final producent = (it['producent'] ?? '').toString();
        final name = (it['name'] ?? it['itemId'] ?? '').toString();

        final qtyRaw = (it['quantity'] ?? '').toString().trim();
        final unit = (it['unit'] ?? '').toString().trim();
        final qtyUnit = [qtyRaw, unit].where((x) => x.isNotEmpty).join(' ');

        s1.getRangeByName('A$r').setText(type);
        s1.getRangeByName('B$r').setText(when);
        s1.getRangeByName('C$r').setText(createdByName);
        s1.getRangeByName('D$r').setText(producent);
        s1.getRangeByName('E$r').setText(name);
        s1.getRangeByName('F$r').setText(qtyUnit);

        // Put notes only on the first item row for this RW doc (so it doesn’t repeat)
        if (it == items.first) {
          s1.getRangeByName('G$r').setText(notesText);
        }

        r++;
      }
    }

    // ================= SHEET 3: HISTORIA (audit_logs) =================
    final s2 = workbook.worksheets.addWithName('HISTORIA');

    s2.getRangeByName('A1').columnWidth = 18;
    s2.getRangeByName('B1').columnWidth = 20;
    s2.getRangeByName('C1').columnWidth = 40;
    s2.getRangeByName('D1').columnWidth = 120;

    s2.getRangeByName('A1').setText('Data');
    s2.getRangeByName('B1').setText('Użytkownik');
    s2.getRangeByName('C1').setText('Akcja');
    s2.getRangeByName('D1').setText('Szczegóły');
    s2.getRangeByName('A1:D1').cellStyle.bold = true;

    int h = 2;
    for (final log in auditLogs) {
      final ts = log['timestamp'] ?? log['createdAt'];
      final when = _fmtDate(ts);

      final userName =
          (log['userName'] ?? log['actorName'] ?? log['actorEmail'] ?? '')
              .toString();

      final action = (log['action'] ?? log['title'] ?? '').toString();

      // Many of your audit logs have "details" map
      final detailsText = _detailsToText(log['details'] ?? log['meta'] ?? '');

      s2.getRangeByName('A$h').setText(when);
      s2.getRangeByName('B$h').setText(userName);
      s2.getRangeByName('C$h').setText(action);
      s2.getRangeByName('D$h').setText(detailsText);

      h++;
    }

    // ================= SAVE =================
    final bytes = Uint8List.fromList(workbook.saveAsStream());
    workbook.dispose();

    final storagePath = 'archives/$customerId/$projectId/archive.xlsx';
    final ref = FirebaseStorage.instance.ref(storagePath);

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    );

    final url = await ref.getDownloadURL();

    final archiveRef = projRef.collection('archives').doc(_archiveDocId);
    final batch = db.batch();

    batch.set(archiveRef, {
      'customerId': customerId,
      'projectId': projectId,
      'customerName': customerName,
      'projectName': projectName,
      'archivedAt': FieldValue.serverTimestamp(),
      'archivedBy': user?.uid,
      'filePath': storagePath,
      'downloadUrl': url,
      'byteSize': bytes.length,
      'isActive': true,
    }, SetOptions(merge: true));

    batch.update(projRef, {
      'archived': true,
      'archivedAt': FieldValue.serverTimestamp(),
      'archivedBy': user?.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user?.uid,
    });

    await batch.commit();
  }

  // ================= UNARCHIVE =================

  static Future<void> unarchiveProject({
    required String customerId,
    required String projectId,
    bool deleteArchiveFile = false,
  }) async {
    final db = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;

    final projRef = db
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);

    final archivesCol = projRef.collection('archives');

    if (deleteArchiveFile) {
      try {
        final storagePath = 'archives/$customerId/$projectId/archive.xlsx';
        await FirebaseStorage.instance.ref(storagePath).delete();
      } catch (_) {}
    }

    // Read all archive docs (current + any older ones)
    final snaps = await archivesCol.get(
      const GetOptions(source: Source.server),
    );

    final batch = db.batch();

    batch.update(projRef, {
      'archived': false,
      'unarchivedAt': FieldValue.serverTimestamp(),
      'unarchivedBy': user?.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user?.uid,
      'archivedAt': FieldValue.delete(),
      'archivedBy': FieldValue.delete(),
    });

    for (final d in snaps.docs) {
      batch.set(d.reference, {
        'isActive': false,
        'unarchivedAt': FieldValue.serverTimestamp(),
        'unarchivedBy': user?.uid,
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }
}
