import 'package:cloud_functions/cloud_functions.dart';
import 'dart:developer' as developer;
import 'package:cloud_functions/src/https_callable.dart';

class UserFunctions {
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<List<Map<String, dynamic>>> listUsers() async {
    final callable = _functions.httpsCallable('listUsers');

    callable.timeout = Duration(seconds: 10);
    (callable as HttpsCallableImpl).interceptors.add((
      HTTPRequestOptions options,
    ) {
      developer.log('➡️ Headers: ${options.headers}');
      return options;
    });

    final result = await callable();
    final raw = result.data as List;
    return raw.map((e) {
      return Map<String, dynamic>.from(e as Map);
    }).toList();
  }

  Future<Map<String, dynamic>> createUser(
    String email,
    String password,
    String role,
  ) async {
    final res = await _functions.httpsCallable('createUser')({
      'email': email,
      'password': password,
      'role': role,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> updateUserRole(String uid, String role) async {
    await _functions.httpsCallable('updateUserRole')({
      'uid': uid,
      'role': role,
    });
  }

  Future<void> deleteUser(String uid) async {
    await _functions.httpsCallable('deleteUser')({'uid': uid});
  }
}
