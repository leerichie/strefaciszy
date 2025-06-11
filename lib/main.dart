// lib/main.dart

import 'firebase_options.dart';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/login_screen.dart';
import 'screens/main_menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const StrefaCiszyApp());
}

class StrefaCiszyApp extends StatelessWidget {
  const StrefaCiszyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Strefa Ciszy',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!authSnap.hasData) {
          return LoginScreen();
        }

        final uid = authSnap.data!.uid;
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (ctx, roleSnap) {
            if (roleSnap.connectionState != ConnectionState.done) {
              return Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final data = roleSnap.data?.data();
            final role =
                (data != null && data['role'] is String)
                    ? data['role'] as String
                    : 'user';
            return MainMenuScreen(role: role);
          },
        );
      },
    );
  }
}
