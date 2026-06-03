// lib/service/app_update_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'web_reload_stub.dart' if (dart.library.html) 'web_reload_web.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:strefa_ciszy/services/event_log_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  static const String _versionsUrl =
      'https://ashleyrichards.tech/download/app_versions.json';

  static const String _appKey = 'strefaciszy';
  static const String _fallbackAndroidDownloadUrl =
      'https://strefa-ciszy.web.app/app-release.apk';

  static String _downloadUrlForPlatform(Map<String, dynamic> appData) {
    final legacyDownloadPage = (appData['downloadPage'] ?? '').toString();
    final androidDownloadPage = (appData['androidDownloadPage'] ?? '')
        .toString();
    final iosDownloadPage = (appData['iosDownloadPage'] ?? '').toString();

    final platformUrl = defaultTargetPlatform == TargetPlatform.iOS
        ? iosDownloadPage
        : androidDownloadPage;

    final url = platformUrl.trim().isNotEmpty
        ? platformUrl.trim()
        : legacyDownloadPage.trim();

    if (url.isEmpty || url == '#') {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? ''
          : _fallbackAndroidDownloadUrl;
    }

    return url;
  }

  static Future<void> _openDownloadUrl(
    BuildContext context,
    String downloadUrl,
  ) async {
    if (downloadUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak linku do pobrania aktualizacji.')),
      );
      return;
    }

    final uri = Uri.tryParse(downloadUrl.trim());
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nieprawidłowy link aktualizacji: $downloadUrl'),
        ),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nie udało się otworzyć: $downloadUrl')),
    );
  }

  static Future<void> checkForUpdate(BuildContext context) async {
    if (kIsWeb) {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      final uri = Uri.parse(
        '$_versionsUrl?t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response = await http.get(
        uri,
        headers: {'Cache-Control': 'no-cache'},
      );

      if (response.statusCode != 200) return;

      final Map<String, dynamic> jsonData =
          jsonDecode(response.body) as Map<String, dynamic>;

      final appData = jsonData[_appKey];
      if (appData == null || appData is! Map<String, dynamic>) return;

      final latestVersion = (appData['latestVersion'] ?? '').toString();

      final latestBuild = appData['latestBuild'] is int
          ? appData['latestBuild'] as int
          : int.tryParse(appData['latestBuild'].toString()) ?? 0;

      final hasUpdate =
          latestBuild > currentBuild ||
          (latestBuild == currentBuild && latestVersion != currentVersion);

      if (!hasUpdate) return;
      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Dostępna aktualizacja.'),
          content: const Text(
            'Jeśli przycisk Refresh nie działa można odswieżyć stronę naciskając: CTRL + SHIFT + R',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Olać to'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();

                reloadWindow();
              },
              child: const Text('Refresh'),
            ),
          ],
        ),
      );

      return;
    }
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      final uri = Uri.parse(
        '$_versionsUrl?t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response = await http.get(
        uri,
        headers: {'Cache-Control': 'no-cache'},
      );
      if (response.statusCode != 200) return;

      final Map<String, dynamic> jsonData =
          jsonDecode(response.body) as Map<String, dynamic>;

      final appData = jsonData[_appKey];
      if (appData == null || appData is! Map<String, dynamic>) return;

      final latestVersion = (appData['latestVersion'] ?? '').toString();
      final latestBuild = appData['latestBuild'] is int
          ? appData['latestBuild'] as int
          : int.tryParse(appData['latestBuild'].toString()) ?? 0;
      final updatedAt = (appData['updatedAt'] ?? '').toString();
      final downloadPage = _downloadUrlForPlatform(appData);
      final notes = (appData['notes'] is List)
          ? List<String>.from(appData['notes'])
          : <String>[];

      final hasUpdate =
          latestBuild > currentBuild ||
          (latestBuild == currentBuild && latestVersion != currentVersion);

      if (!hasUpdate) return;
      if (!context.mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('New Version...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current: $currentVersion ($currentBuild)'),
              Text(
                'Update: $latestVersion ($latestBuild)',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (updatedAt.isNotEmpty) Text(updatedAt),

              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('What\'s new?'),
                const SizedBox(height: 6),
                ...notes.map((e) => Text('• $e')),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                EventLogService.appUpdateIgnored(
                  currentVersion: '$currentVersion ($currentBuild)',
                  latestVersion: '$latestVersion ($latestBuild)',
                );
                Navigator.of(context).pop();
              },
              child: const Text('Ignore'),
            ),
            ElevatedButton(
              onPressed: () async {
                EventLogService.appUpdateAccepted(
                  currentVersion: '$currentVersion ($currentBuild)',
                  latestVersion: '$latestVersion ($latestBuild)',
                );
                Navigator.of(context).pop();
                if (!context.mounted) return;
                await _openDownloadUrl(context, downloadPage);
              },
              child: const Text('Download'),
            ),
          ],
        ),
      );
    } catch (_) {
      // silent fail
    }
  }
}
