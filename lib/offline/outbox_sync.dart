import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:strefa_ciszy/offline/local_repository.dart';
import 'package:strefa_ciszy/offline/models/pending_op.dart';
import 'package:strefa_ciszy/services/admin_api.dart';

Future<void> processOutboxOnce({int batchSize = 25}) async {
  final local = await LocalRepository.create();
  final ops = await local.takePending(limit: batchSize);
  if (ops.isEmpty) return;

  await AdminApi.init();

  for (final op in ops) {
    try {
      await _processOne(local, op);
      await local.markOpDone(op.clientOpId);
    } catch (e, st) {
      debugPrint('Outbox op ${op.clientOpId} failed: $e\n$st');
      await local.markOpTried(op.clientOpId);
      // stop the loop on certain errors, add logic....
    }
  }
}

Future<void> _processOne(LocalRepository local, PendingOp op) async {
  final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;

  switch (op.opType) {
    case 'reserveUpsert':
      await AdminApi.reserveUpsert(
        projectId: payload['projectId'] as String,
        customerId: (payload['customerId'] as String?) ?? '',
        itemId: payload['itemId'] as String,
        qty: (payload['qty'] as num),
        actorEmail: (payload['actorEmail'] as String?) ?? 'app',
      );
      return;

    // more op types here in future (e.g., notes, photos, etc.)

    default:
      await local.markOpNeedsAttention(op.clientOpId);
      throw UnsupportedError('Unknown opType: ${op.opType}');
  }
}
