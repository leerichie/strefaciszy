// services/push_messaging

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSub;

  static const String _webVapidKey = String.fromEnvironment(
    'FCM_VAPID_KEY',
    defaultValue: '',
  );

  bool _started = false;

  Future<void> startForCurrentUser() async {
    print('PUSH: startForCurrentUser called');

    if (_started) return;
    _started = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1) Permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('Push permission: ${settings.authorizationStatus}');

    // 2) Token
    final token = await _getTokenSafe();
    if ((token == null || token.isEmpty) &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      // try again IF NULL on first attmmpt iOS
      Future.delayed(const Duration(seconds: 2), () async {
        final u = FirebaseAuth.instance.currentUser;
        if (u == null) return;

        final t2 = await _getTokenSafe();
        if (t2 != null && t2.isNotEmpty) {
          await _saveToken(u.uid, t2);
          debugPrint('PUSH: token saved on retry');
        }
      });
    }

    print(
      'PUSH: token = ${token == null ? "NULL" : "${token.substring(0, 16)}..."}',
    );

    if (token == null || token.isEmpty) {
      debugPrint('FCM token not available (yet).');
    } else {
      await _saveToken(user.uid, token);
    }

    // 3) refresh
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return;
      await _saveToken(u.uid, newToken);
    });
  }

  Future<void> stop() async {
    _started = false;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  Future<String?> _getTokenSafe() async {
    try {
      if (kIsWeb) {
        if (_webVapidKey.isEmpty) {
          debugPrint(
            'Missing FCM_VAPID_KEY. Run web with --dart-define=FCM_VAPID_KEY=...',
          );
          return null;
        }
        return _messaging.getToken(vapidKey: _webVapidKey);
      }

      // iOS: APNs token
      if (Platform.isIOS) {
        final apns = await _messaging.getAPNSToken();
        if (apns == null) {
          debugPrint('PUSH: APNS token not ready yet (will retry later).');
          return null;
        }
      }

      return _messaging.getToken();
    } catch (e, st) {
      debugPrint('getToken error: $e');
      debugPrint('$st');
      return null;
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(uid);
    final tokenRef = userRef.collection('push_tokens').doc(token);

    try {
      await tokenRef.set({
        'token': token,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('PUSH: ✅ Saved token for uid=$uid');
    } catch (e, st) {
      print('PUSH: ❌ Failed to save token: $e');

      debugPrint('$st');
    }
  }
}
