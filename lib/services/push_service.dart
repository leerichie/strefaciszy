// services/push_messaging

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Step 1 scope:
/// - request permission
/// - obtain FCM token (web requires VAPID)
/// - save token under user_profiles/{uid}/push_tokens/{token}
///
/// Later we'll extend this service with:
/// - per-event routing (chat, project updates, swaps)
/// - topic subscriptions
/// - notification preferences per user
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSub;

  /// IMPORTANT (web):
  /// - Put your Web Push "VAPID public key" as --dart-define=FCM_VAPID_KEY=...
  ///   Example:
  ///   flutter run -d chrome --dart-define=FCM_VAPID_KEY=YOUR_KEY
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
    print(
      'PUSH: token = ${token == null ? "NULL" : "${token.substring(0, 16)}..."}',
    );

    if (token == null || token.isEmpty) {
      debugPrint('FCM token not available (yet).');
    } else {
      await _saveToken(user.uid, token);
    }

    // 3)   refresh
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
