// lib/services/event_log_service.dart
// Writes system/app events to the top-level `event_logs` collection.
// Business-level audit actions stay in `audit_logs` via AuditService.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EventLogService {
  EventLogService._();

  static const _col = 'event_logs';
  static const _pendingKey = 'pending_event_logs_v1';

  // Set to true by the manual "Wyloguj" button handlers right before calling
  // FirebaseAuth signOut(), so AuthGate can tell a deliberate logout apart
  // from the app silently dropping the session on its own.
  static bool manualSignOutInProgress = false;

  // ── Internal writer ─────────────────────────────────────────────────────────

  static Future<void> _writeRaw({
    required String eventType,
    required String category,
    required String summary,
    String? userId,
    String? userEmail,
    String? userName,
    Map<String, dynamic>? details,
    String severity = 'info', // info | warning | error
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection(_col).add({
      'eventType': eventType,
      'category': category,
      'summary': summary,
      'userId': userId ?? currentUser?.uid ?? 'unknown',
      'userEmail': userEmail ?? currentUser?.email ?? '',
      'userName':
          userName ??
          currentUser?.displayName ??
          currentUser?.email ??
          'Unknown',
      'details': details ?? {},
      'severity': severity,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _write({
    required String eventType,
    required String category,
    required String summary,
    String? userId,
    String? userEmail,
    String? userName,
    Map<String, dynamic>? details,
    String severity = 'info', // info | warning | error
  }) async {
    try {
      await _writeRaw(
        eventType: eventType,
        category: category,
        summary: summary,
        userId: userId,
        userEmail: userEmail,
        userName: userName,
        details: details,
        severity: severity,
      );
    } catch (e) {
      debugPrint('Event log write failed ($eventType): $e');
      // Never let logging crash the app
    }
  }

  /// Like [_write], but if Firestore rejects the write (e.g. because the
  /// user's session just dropped and `request.auth` is now null), the event
  /// is buffered on-device and retried via [flushPendingEvents] next time
  /// the app has a signed-in user.
  static Future<void> _writeOrBuffer({
    required String eventType,
    required String category,
    required String summary,
    String? userId,
    String? userEmail,
    String? userName,
    Map<String, dynamic>? details,
    String severity = 'info',
  }) async {
    try {
      await _writeRaw(
        eventType: eventType,
        category: category,
        summary: summary,
        userId: userId,
        userEmail: userEmail,
        userName: userName,
        details: details,
        severity: severity,
      );
    } catch (e) {
      debugPrint('Event log write failed, buffering ($eventType): $e');
      await _bufferLocally({
        'eventType': eventType,
        'category': category,
        'summary': summary,
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'details': details ?? {},
        'severity': severity,
      });
    }
  }

  static Future<void> _bufferLocally(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_pendingKey) ?? [];
      list.add(jsonEncode(payload));
      await prefs.setStringList(_pendingKey, list);
    } catch (e) {
      debugPrint('Failed to buffer event log locally: $e');
    }
  }

  /// Call once a signed-in user is confirmed (e.g. from AuthGate) to flush
  /// any events that couldn't reach Firestore at the moment they happened.
  static Future<void> flushPendingEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_pendingKey);
      if (pending == null || pending.isEmpty) return;

      final stillPending = <String>[];
      for (final raw in pending) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          await _writeRaw(
            eventType: map['eventType'] as String,
            category: map['category'] as String,
            summary: map['summary'] as String,
            userId: map['userId'] as String?,
            userEmail: map['userEmail'] as String?,
            userName: map['userName'] as String?,
            details: (map['details'] as Map?)?.cast<String, dynamic>(),
            severity: map['severity'] as String? ?? 'info',
          );
        } catch (e) {
          stillPending.add(raw);
        }
      }
      await prefs.setStringList(_pendingKey, stillPending);
    } catch (e) {
      debugPrint('Failed to flush pending event logs: $e');
    }
  }

  static Future<String> _resolveDisplayName(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final name = doc.data()?['name'] as String?;
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return user.displayName ?? user.email ?? user.uid;
  }

  // ── Auth events ─────────────────────────────────────────────────────────────

  static Future<void> loginSuccess(User user) async {
    final name = await _resolveDisplayName(user);
    await _write(
      eventType: 'LOGIN_SUCCESS',
      category: 'auth',
      summary: 'Login successful',
      userId: user.uid,
      userEmail: user.email ?? '',
      userName: name,
      details: {'email': user.email ?? ''},
      severity: 'info',
    );
  }

  static Future<void> loginFailed(String email, String errorCode) async {
    await _write(
      eventType: 'LOGIN_FAILED',
      category: 'auth',
      summary: 'Failed login attempt',
      userId: 'unauthenticated',
      userEmail: email,
      userName: email,
      details: {'email': email, 'errorCode': errorCode},
      severity: 'warning',
    );
  }

  /// Fired when authStateChanges() drops to null for a user who was
  /// previously signed in, and no manual "Wyloguj" button triggered it.
  static Future<void> authUnexpectedSignOut({
    required String uid,
    String? email,
  }) async {
    await _writeOrBuffer(
      eventType: 'AUTH_UNEXPECTED_SIGNOUT',
      category: 'auth',
      summary: 'User signed out without tapping logout',
      userId: uid,
      userEmail: email ?? '',
      userName: email ?? uid,
      details: {if (email != null) 'email': email},
      severity: 'error',
    );
  }

  /// Fired when the forced ID-token refresh on app launch/auth-state-change
  /// throws, right before the app falls back to non-admin claims.
  static Future<void> authTokenRefreshFailed({
    required String uid,
    String? email,
    required Object error,
  }) async {
    await _writeOrBuffer(
      eventType: 'AUTH_TOKEN_REFRESH_FAILED',
      category: 'auth',
      summary: 'Token refresh failed',
      userId: uid,
      userEmail: email ?? '',
      userName: email ?? uid,
      details: {if (email != null) 'email': email, 'error': error.toString()},
      severity: 'error',
    );
  }

  /// Fired from global FlutterError/PlatformDispatcher handlers so
  /// unhandled exceptions (e.g. a Firestore permission-denied that would
  /// otherwise just show a blank/broken screen) show up here too.
  static Future<void> unhandledError({
    required String context,
    required Object error,
    StackTrace? stackTrace,
  }) async {
    await _writeOrBuffer(
      eventType: 'UNHANDLED_ERROR',
      category: 'error',
      summary: 'Unhandled app error',
      details: {
        'context': context,
        'error': error.toString(),
        if (stackTrace != null)
          'stack': stackTrace.toString().split('\n').take(6).join(' | '),
      },
      severity: 'error',
    );
  }

  // ── Chat events ─────────────────────────────────────────────────────────────

  static Future<void> chatMessageSent({
    required String chatId,
    required String chatTitle,
    bool hasAttachment = false,
  }) async {
    await _write(
      eventType: 'CHAT_MESSAGE_SENT',
      category: 'chat',
      summary: 'Message sent in chat',
      details: {
        'chatId': chatId,
        'chat': chatTitle,
        if (hasAttachment) 'attachment': 'yes',
      },
      severity: 'info',
    );
  }

  // ── File events ─────────────────────────────────────────────────────────────

  static Future<void> fileUploaded({
    required String context,
    required String fileName,
    String? projectId,
  }) async {
    await _write(
      eventType: 'FILE_UPLOADED',
      category: 'file',
      summary: 'File uploaded',
      details: {
        'fileName': fileName,
        'context': context,
        if (projectId != null) 'projectId': projectId,
      },
      severity: 'info',
    );
  }

  static Future<void> fileDeleted({
    required String context,
    required String fileName,
    String? projectId,
  }) async {
    await _write(
      eventType: 'FILE_DELETED',
      category: 'file',
      summary: 'File deleted',
      details: {
        'fileName': fileName,
        'context': context,
        if (projectId != null) 'projectId': projectId,
      },
      severity: 'warning',
    );
  }

  // ── Work day events ──────────────────────────────────────────────────────────

  static Future<void> workDayEntryCreated({
    required String dayKey,
    required String startTime,
    required String endTime,
    String? projectName,
    String? description,
  }) async {
    await _write(
      eventType: 'WORKDAY_ENTRY_CREATED',
      category: 'workday',
      summary: 'Work day entry added',
      details: {
        'day': dayKey,
        'time': '$startTime – $endTime',
        if (projectName != null && projectName.isNotEmpty)
          'project': projectName,
        if (description != null && description.isNotEmpty) 'note': description,
      },
      severity: 'info',
    );
  }

  static Future<void> workDayEntryBlocked({
    required String reason,
    required String dayKey,
    String? startTime,
    String? endTime,
    String? projectName,
    String? description,
  }) async {
    await _write(
      eventType: 'WORKDAY_ENTRY_BLOCKED',
      category: 'workday',
      summary: 'Work day entry blocked before save',
      details: {
        'reason': reason,
        'day': dayKey,
        if (startTime != null && startTime.isNotEmpty) 'startTime': startTime,
        if (endTime != null && endTime.isNotEmpty) 'endTime': endTime,
        if (startTime != null &&
            startTime.isNotEmpty &&
            endTime != null &&
            endTime.isNotEmpty)
          'time': '$startTime – $endTime',
        if (projectName != null && projectName.isNotEmpty)
          'project': projectName,
        if (description != null && description.isNotEmpty) 'note': description,
      },
      severity: 'warning',
    );
  }

  static Future<void> workDayEntrySaveFailed({
    required String operation,
    required String dayKey,
    String? startTime,
    String? endTime,
    String? projectName,
    String? description,
    required Object error,
  }) async {
    await _write(
      eventType: 'WORKDAY_ENTRY_SAVE_FAILED',
      category: 'workday',
      summary: 'Work day entry save failed',
      details: {
        'operation': operation,
        'day': dayKey,
        if (startTime != null && startTime.isNotEmpty) 'startTime': startTime,
        if (endTime != null && endTime.isNotEmpty) 'endTime': endTime,
        if (startTime != null &&
            startTime.isNotEmpty &&
            endTime != null &&
            endTime.isNotEmpty)
          'time': '$startTime – $endTime',
        if (projectName != null && projectName.isNotEmpty)
          'project': projectName,
        if (description != null && description.isNotEmpty) 'note': description,
        'error': error.toString(),
      },
      severity: 'error',
    );
  }

  static Future<void> workDayEntryUpdated({
    required String dayKey,
    required String startTime,
    required String endTime,
    String? projectName,
    String? description,
  }) async {
    await _write(
      eventType: 'WORKDAY_ENTRY_UPDATED',
      category: 'workday',
      summary: 'Work day entry updated',
      details: {
        'day': dayKey,
        'time': '$startTime – $endTime',
        if (projectName != null && projectName.isNotEmpty)
          'project': projectName,
        if (description != null && description.isNotEmpty) 'note': description,
      },
      severity: 'info',
    );
  }

  static Future<void> workDayEntryDeleted({
    required String dayKey,
    required String startTime,
    required String endTime,
    String? projectName,
  }) async {
    await _write(
      eventType: 'WORKDAY_ENTRY_DELETED',
      category: 'workday',
      summary: 'Work day entry deleted',
      details: {
        'day': dayKey,
        'time': '$startTime – $endTime',
        if (projectName != null && projectName.isNotEmpty)
          'project': projectName,
      },
      severity: 'warning',
    );
  }

  static Future<void> workDayEntryDeleteFailed({
    required String dayKey,
    required String startTime,
    required String endTime,
    String? projectName,
    required Object error,
  }) async {
    await _write(
      eventType: 'WORKDAY_ENTRY_DELETE_FAILED',
      category: 'workday',
      summary: 'Work day entry delete failed',
      details: {
        'day': dayKey,
        'time': '$startTime – $endTime',
        if (projectName != null && projectName.isNotEmpty)
          'project': projectName,
        'error': error.toString(),
      },
      severity: 'error',
    );
  }

  // ── App update events ────────────────────────────────────────────────────────

  static Future<void> appUpdateAccepted({
    required String currentVersion,
    required String latestVersion,
  }) async {
    await _write(
      eventType: 'APP_UPDATE_ACCEPTED',
      category: 'app',
      summary: 'User accepted app update',
      details: {'from': currentVersion, 'to': latestVersion},
      severity: 'info',
    );
  }

  static Future<void> appUpdateIgnored({
    required String currentVersion,
    required String latestVersion,
  }) async {
    await _write(
      eventType: 'APP_UPDATE_IGNORED',
      category: 'app',
      summary: 'User dismissed update prompt',
      details: {'current': currentVersion, 'available': latestVersion},
      severity: 'info',
    );
  }

  // ── Report events ────────────────────────────────────────────────────────────

  static Future<void> reportViewed({required String reportType}) async {
    await _write(
      eventType: 'REPORT_VIEWED',
      category: 'report',
      summary: 'Report opened',
      details: {'type': reportType},
      severity: 'info',
    );
  }
}
