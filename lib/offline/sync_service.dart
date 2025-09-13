// lib/offline/sync_service.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/stock_service.dart';
import 'local_repository.dart';

/// Each op type gets a handler. Return:
///  - true  -> mark DONE
///  - false -> mark NEEDS_ATTENTION (validation/conflict)
typedef OpHandler = Future<bool> Function(Map<String, dynamic> payload);

class SyncService {
  final LocalRepository _repo;
  final Map<String, OpHandler> _handlers;

  SyncService._(this._repo, this._handlers);

  /// Factory: builds repository and registers op handlers.
  static Future<SyncService> create() async {
    final repo = await LocalRepository.create();

    final handlers = <String, OpHandler>{
      // Reserve in WAPRO, then mirror to Firestore (RW + project items)
      'ADD_ITEM': (Map<String, dynamic> payload) async {
        // Payload fields produced by OfflineActions.addItemToProjectOptimistic:
        // { customerId, projectId, productId, qty, note, userId, userEmail, itemId }
        final customerId = payload['customerId'] as String;
        final projectId = payload['projectId'] as String;
        final productId =
            payload['productId'] as String; // WAPRO id (e.g. "1536")
        final qtyNum = payload['qty'] as num;
        final double qty = qtyNum.toDouble();
        final String actorEmail =
            (payload['userEmail'] as String?) ?? 'app@strefa';

        // 1) WAPRO reservation (idempotent to desired target qty)
        try {
          final res = await ApiService.postJson('/admin/reservations/upsert', {
            'projectId': projectId,
            'itemId': productId, // WAPRO id
            'qty': qty, // target reserved for this project+item
            'actorEmail': actorEmail,
          });
          debugPrint('[SyncService][ADD_ITEM->reservation] ok: $res');
        } catch (e) {
          debugPrint('[SyncService][ADD_ITEM->reservation] error: $e');
          final msg = e.toString();
          // Business/validation error -> mark NEEDS_ATTENTION
          if (msg.contains('409') ||
              msg.contains('Not enough') ||
              msg.contains('not enough') ||
              msg.contains('bad-qty') ||
              msg.contains('bad-itemId')) {
            return false;
          }
          // Transient (network/timeouts) -> rethrow so we keep it PENDING for retry
          rethrow;
        }

        // 2) Mirror into Firestore so the app's project/RW stays in sync
        try {
          final db = FirebaseFirestore.instance;
          final projRef = db
              .collection('customers')
              .doc(customerId)
              .collection('projects')
              .doc(projectId);

          // Use latest RW (if any) simply as context; applySwapAsNewRw
          // will create/append "today's RW" document for us.
          final rwCol = projRef.collection('rw_documents');
          final latest = await rwCol
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();
          final DocumentReference<Map<String, dynamic>> sourceRwRef =
              latest.docs.isNotEmpty
              ? latest.docs.first.reference
              : rwCol.doc();

          await StockService.applySwapAsNewRw(
            sourceRwRef: sourceRwRef,
            customerId: customerId,
            projectId: projectId,
            oldItemId: productId,
            oldQty: 0,
            newItemId: productId,
            newQty: qty.toInt(),
          );
        } catch (e) {
          // Reservation succeeded but Firestore mirror failed — surface for review.
          debugPrint('[SyncService][ADD_ITEM->firestore] error: $e');
          return false;
        }

        return true;
      },
    };

    return SyncService._(repo, handlers);
  }

  /// Process up to [batchSize] pending ops once.
  /// Returns number of ops completed (DONE or NEEDS_ATTENTION).
  Future<int> runOnce({int batchSize = 25}) async {
    final ops = await _repo.takePending(limit: batchSize);
    int processed = 0;

    for (final op in ops) {
      try {
        await _repo.markOpTried(op.clientOpId);

        // Simple dependency handling
        if (op.dependsOn != null) {
          final deps = await _repo.takePending(limit: 9999);
          final waiting = deps.any((d) => d.clientOpId == op.dependsOn);
          if (waiting) continue;
        }

        final payload =
            jsonDecode(op.payloadJson) as Map<String, dynamic>? ?? const {};
        final handler = _handlers[op.opType];

        if (handler == null) {
          await _repo.markOpNeedsAttention(op.clientOpId);
          processed++;
          continue;
        }

        bool ok;
        try {
          ok = await handler(payload);
        } catch (_) {
          // transient error -> keep as PENDING (no state change)
          // processed++ still, so UI log shows activity
          processed++;
          continue;
        }

        if (ok) {
          await _repo.markOpDone(op.clientOpId);
        } else {
          await _repo.markOpNeedsAttention(op.clientOpId);
        }
      } catch (_) {
        // swallow; leave op as is for retry
      } finally {
        processed++;
      }
    }
    return processed;
  }
}
