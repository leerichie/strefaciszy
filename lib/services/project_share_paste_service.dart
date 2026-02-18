// lib/services/project_share_paste_service.dart

import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'project_files_service.dart';
import 'share_incoming_service.dart';

class ProjectSharePasteService {
  ProjectSharePasteService._();
  static final ProjectSharePasteService instance = ProjectSharePasteService._();

  bool get hasSharedItems => SharedIncomingService.instance.hasFiles;

  Future<bool> pasteToPhotos({
    required BuildContext context,
    required String customerId,
    required String projectId,
    required bool canEdit,
  }) async {
    if (!canEdit) return false;

    if (kIsWeb) {
      _snack(context, 'Share/Paste nie działa przez web.');
      return false;
    }

    final items = SharedIncomingService.instance.files;
    if (items.isEmpty) return false;

    try {
      _snack(context, 'Dodam do Fotki...');

      final payload = <MapEntry<String, Uint8List>>[];

      for (final SharedMediaFile item in items) {
        final path = item.path.trim();

        debugPrint('SHARE PATH RAW: $path');

        if (path.isEmpty) continue;

        Uint8List? bytes;
        String name;

        // ---------- URL CASE ----------
        if (path.startsWith('http')) {
          try {
            final uri = Uri.parse(path);
            final response = await http.get(uri);

            if (response.statusCode == 200) {
              bytes = response.bodyBytes;
              name = uri.pathSegments.isNotEmpty
                  ? uri.pathSegments.last
                  : 'file';
            } else {
              continue;
            }
          } catch (e) {
            debugPrint('URL DOWNLOAD ERROR: $e');
            continue;
          }
        }
        // ---------- LOCAL FILE CASE ----------
        else {
          final file = io.File(path);

          final exists = await file.exists();
          debugPrint('SHARE EXISTS: $exists');

          if (!exists) continue;

          bytes = await file.readAsBytes();
          name = _safeBasename(path);
        }

        if (bytes.isEmpty) continue;

        debugPrint('SHARE BYTES: ${bytes.length}');

        payload.add(MapEntry(name, bytes));
      }

      if (payload.isEmpty) {
        _snack(context, 'Nie kompatybilny plik.');
        return false;
      }

      await ProjectFilesService.uploadProjectImagesFromBytes(
        customerId: customerId,
        projectId: projectId,
        files: payload,
        tabBucket: 'images',
      );

      SharedIncomingService.instance.clear();
      _snack(context, 'Dodany do Fotki');
      return true;
    } catch (e) {
      _snack(context, 'Nie udało się dodać do Fotki: $e');
      return false;
    }
  }

  Future<bool> pasteToFiles({
    required BuildContext context,
    required String customerId,
    required String projectId,
    required bool canEdit,
  }) async {
    if (!canEdit) return false;

    if (kIsWeb) {
      _snack(context, 'Share/Paste nie działa przez web.');
      return false;
    }

    final items = SharedIncomingService.instance.files;
    if (items.isEmpty) return false;

    try {
      _snack(context, 'Dodam do Pliki...');

      final payload = <MapEntry<String, Uint8List>>[];

      for (final SharedMediaFile item in items) {
        final path = item.path.trim();

        debugPrint('SHARE PATH RAW: $path');

        if (path.isEmpty) continue;

        Uint8List? bytes;
        String name;

        // ---------- URL CASE ----------
        if (path.startsWith('http')) {
          try {
            final uri = Uri.parse(path);
            final response = await http.get(uri);

            if (response.statusCode != 200) continue;

            final contentType = response.headers['content-type'] ?? '';

            debugPrint('URL CONTENT TYPE: $contentType');
            final body = response.bodyBytes;

            final isPdf =
                contentType.contains('pdf') ||
                (body.length >= 4 &&
                    body[0] == 0x25 &&
                    body[1] == 0x50 &&
                    body[2] == 0x44 &&
                    body[3] == 0x46); // %PDF

            if (!isPdf) {
              _snack(
                context,
                'plik jest link — pobierz go najpierw na telefon.',
              );
              continue;
            }

            bytes = body;

            name = uri.pathSegments.isNotEmpty
                ? uri.pathSegments.last
                : 'file.pdf';
          } catch (e) {
            debugPrint('URL DOWNLOAD ERROR: $e');
            continue;
          }
        }
        // ---------- LOCAL FILE CASE ----------
        else {
          final file = io.File(path);

          final exists = await file.exists();
          debugPrint('SHARE EXISTS: $exists');

          if (!exists) continue;

          bytes = await file.readAsBytes();
          name = _safeBasename(path);
        }

        if (bytes.isEmpty) continue;

        debugPrint('SHARE BYTES: ${bytes.length}');

        payload.add(MapEntry(name, bytes));
      }

      if (payload.isEmpty) {
        _snack(context, 'Nie kompatybilny plik.');
        return false;
      }

      await ProjectFilesService.uploadProjectFilesFromBytes(
        customerId: customerId,
        projectId: projectId,
        files: payload,
        tabBucket: 'files',
      );

      SharedIncomingService.instance.clear();
      _snack(context, 'Dodany do Pliki');
      return true;
    } catch (e) {
      _snack(context, 'Nie udało się dodać do Pliki: $e');
      return false;
    }
  }

  static String _safeBasename(String path) {
    final uri = Uri.tryParse(path);
    final raw = (uri != null && uri.pathSegments.isNotEmpty)
        ? uri.pathSegments.last
        : path.split('/').last;

    final name = Uri.decodeComponent(raw).split('?').first.trim();
    return name.isEmpty ? 'file' : name;
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
