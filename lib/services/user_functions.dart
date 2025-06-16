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
    String name,
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
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      }),
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

  Future<void> updateUserDetails({
    required String uid,
    String? name,
    String? email,
    String? password,
    String? role,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final idToken = await user.getIdToken();

    final resp = await http.post(
      Uri.parse('$_baseUrl/updateUserDetailsHttp'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'uid': uid,
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      }),
    );

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception('Error ${resp.statusCode}: ${body['error']}');
    }
  }
}
