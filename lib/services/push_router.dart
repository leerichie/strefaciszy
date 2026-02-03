// lib/services/push_router.dart

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/screens/chat_thread_screen.dart';

class PushRouter {
  PushRouter._();
  static final PushRouter instance = PushRouter._();

  bool _started = false;
  StreamSubscription<RemoteMessage>? _openedSub;

  Future<void> start({required GlobalKey<NavigatorState> navKey}) async {
    if (_started) return;
    _started = true;

    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        debugPrint('[PUSH ROUTER] initialMessage: ${initial.messageId}');
        _handle(initial, navKey);
      }
    } catch (e) {
      debugPrint('[PUSH ROUTER] getInitialMessage error: $e');
    }

    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('[PUSH ROUTER] onMessageOpenedApp: ${msg.messageId}');
      _handle(msg, navKey);
    });
  }

  void dispose() {
    _openedSub?.cancel();
    _openedSub = null;
    _started = false;
  }

  void _handle(RemoteMessage msg, GlobalKey<NavigatorState> navKey) {
    final data = msg.data;

    final eventType = (data['eventType'] ?? '').toString();
    debugPrint('[PUSH ROUTER] handle eventType=$eventType data=$data');

    if (eventType == 'chat.message') {
      final chatId = (data['chatId'] ?? '').toString().trim();
      if (chatId.isEmpty) return;

      final nav = navKey.currentState;
      if (nav == null) return;

      nav.push(
        MaterialPageRoute(builder: (_) => ChatThreadScreen(chatId: chatId)),
      );

      return;
    }

    // Future: project updates, swaps, etc.
    // else if (eventType == 'project.updated') { ... }
  }
}
