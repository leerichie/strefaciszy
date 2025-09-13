import 'package:flutter/material.dart';

class DevOfflineTestScreen extends StatelessWidget {
  const DevOfflineTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Dev Offline Test (web stub)\nRun on Android/iOS/macOS to test Isar offline sync.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
