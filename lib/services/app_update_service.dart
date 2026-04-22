// lib/service/app_update_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  static const String _versionsUrl =
      'https://ashleyrichards.tech/download/app_versions.json';

  static const String _appKey = 'strefaciszy';

  static Future<void> checkForUpdate(BuildContext context) async {
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
      final downloadPage = (appData['downloadPage'] ?? '').toString();
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Ignore'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final uri = Uri.parse(downloadPage);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
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
