// lib/main.dart

import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/main_menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('pl_PL', null);
  runApp(const StrefaCiszyApp());
}

class StrefaCiszyApp extends StatelessWidget {
  const StrefaCiszyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Strefa Ciszy',
      theme: ThemeData(primarySwatch: Colors.blue),
      locale: const Locale('pl', 'PL'),
      supportedLocales: const [Locale('pl', 'PL')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!authSnap.hasData) {
          return const LoginScreen();
        }
<<<<<<< HEAD
        final uid = authSnap.data!.uid;
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (ctx, roleSnap) {
            if (roleSnap.connectionState != ConnectionState.done) {
=======

        final user = authSnap.data!;
        return FutureBuilder<IdTokenResult>(
          future: user.getIdTokenResult(true),
          builder: (ctx, tokenSnap) {
            if (tokenSnap.connectionState != ConnectionState.done) {
>>>>>>> 027e8f4f7a9b33da39b80636990a8c0971b810ed
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
<<<<<<< HEAD
            final data = roleSnap.data?.data();
            final role = (data != null && data['role'] is String)
                ? data['role'] as String
                : 'user';
            return MainMenuScreen(role: role);
=======

            final claims = tokenSnap.data?.claims ?? {};
            final isAdmin = claims['admin'] == true;

            return MainMenuScreen(role: isAdmin ? 'admin' : 'user');
>>>>>>> 027e8f4f7a9b33da39b80636990a8c0971b810ed
          },
        );
      },
    );
  }
}
