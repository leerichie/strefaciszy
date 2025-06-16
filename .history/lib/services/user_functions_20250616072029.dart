import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class UserFunctions {
  static const _baseUrl = 'https://us-central1-strefa-ciszy.cloudfunctions.net';

  Future<List<Map<String, dynamic>>> listUsers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final idToken = await user.getIdToken();

    final resp = await http.get(
      Uri.parse('$_baseUrl/listUsersHttp'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception('Error ${resp.statusCode}: ${body['error']}');
    }

    final List data = jsonDecode(resp.body) as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createUser(
<<<<<<< HEAD
=======
    String name,
>>>>>>> 027e8f4f7a9b33da39b80636990a8c0971b810ed
    String email,
    String password,
    String role,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final idToken = await user.getIdToken();

    final resp = await http.post(
      Uri.parse('$_baseUrl/createUserHttp'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
<<<<<<< HEAD
      body: jsonEncode({'email': email, 'password': password, 'role': role}),
=======
      body: jsonEncode({
        'displayName': name,
        'email': email,
        'password': password,
        'role': role,
      }),
>>>>>>> 027e8f4f7a9b33da39b80636990a8c0971b810ed
    );

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception('Error ${resp.statusCode}: ${body['error']}');
    }

    return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
  }

  Future<void> updateUserRole(String uid, String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final idToken = await user.getIdToken();

    final resp = await http.post(
      Uri.parse('$_baseUrl/updateUserRoleHttp'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'uid': uid, 'role': role}),
    );

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception('Error ${resp.statusCode}: ${body['error']}');
    }
  }

  Future<void> deleteUser(String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final idToken = await user.getIdToken();

    final resp = await http.post(
      Uri.parse('$_baseUrl/deleteUserHttp'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'uid': uid}),
    );

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception('Error ${resp.statusCode}: ${body['error']}');
    }
  }
}
