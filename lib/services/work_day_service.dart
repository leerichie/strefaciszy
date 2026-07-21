import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class WorkDayService {
  static const _baseUrl = 'https://us-central1-strefa-ciszy.cloudfunctions.net';

  Future<Map<String, dynamic>> createEntry({
    required String dayKey,
    required String startTime,
    required String endTime,
    String? projectId,
    String? projectName,
    String? customerId,
    required String description,
  }) {
    return _post('createWorkDayEntryHttp', {
      'dayKey': dayKey,
      'startTime': startTime,
      'endTime': endTime,
      'projectId': projectId,
      'projectName': projectName,
      'customerId': customerId,
      'description': description,
    });
  }

  Future<Map<String, dynamic>> updateEntry({
    required String docId,
    required String dayKey,
    required String startTime,
    required String endTime,
    String? projectId,
    String? projectName,
    String? customerId,
    required String description,
  }) {
    return _post('updateWorkDayEntryHttp', {
      'docId': docId,
      'dayKey': dayKey,
      'startTime': startTime,
      'endTime': endTime,
      'projectId': projectId,
      'projectName': projectName,
      'customerId': customerId,
      'description': description,
    });
  }

  Future<Map<String, dynamic>> deleteEntry({required String docId}) {
    return _post('deleteWorkDayEntryHttp', {'docId': docId});
  }

  Future<Map<String, dynamic>> _post(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Zaloguj się ponownie.');

    final idToken = await user.getIdToken();
    final packageInfo = await PackageInfo.fromPlatform();
    final requestBody = {
      ...body,
      'requestId':
          '${user.uid}_${DateTime.now().toUtc().microsecondsSinceEpoch}',
      'clientAppVersion': packageInfo.version,
      'clientBuildNumber': packageInfo.buildNumber,
      'clientPlatform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/$functionName'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          (decoded['message'] ?? decoded['error'] ?? 'Nie udało się zapisać.')
              .toString();
      throw WorkDayServiceException(message, decoded['error']?.toString());
    }

    return decoded;
  }
}

class WorkDayServiceException implements Exception {
  const WorkDayServiceException(this.message, [this.code]);

  final String message;
  final String? code;

  @override
  String toString() => message;
}
