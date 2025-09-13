import 'package:strefa_ciszy/offline/models/project_local.dart';
import 'package:uuid/uuid.dart';

import 'local_repository.dart';

class OfflineActions {
  final LocalRepository _repo;
  final Uuid _uuid = const Uuid();

  OfflineActions._(this._repo);

  static Future<OfflineActions> create() async {
    final repo = await LocalRepository.create();
    return OfflineActions._(repo);
  }

  Future<({String itemId, String clientOpId})> addItemToProjectOptimistic({
    required String customerId,
    required String projectId,
    required String productId,
    required double qty,
    String? note,
    String? userId,
    String? userEmail,
    String? projectNameFallback,
  }) async {
    final existingProj = await _repo.getProject(projectId);
    if (existingProj == null) {
      await _repo.upsertProject(
        projectId: projectId,
        name: projectNameFallback ?? 'Projekt $projectId',
        serverVersion: 0,
        updatedAtServer: null,
        syncState: SyncState.localOnly,
      );
    }

    final itemId = _uuid.v4();
    await _repo.upsertItem(
      itemId: itemId,
      projectId: projectId,
      productId: productId,
      qty: qty,
      note: note,
      serverVersion: 0,
      updatedAtServer: null,
      syncState: SyncState.pending,
    );

    final payload = <String, dynamic>{
      'customerId': customerId,
      'projectId': projectId,
      'itemId': itemId,
      'productId': productId,
      'qty': qty,
      'note': note,
      'userId': userId,
      'userEmail': userEmail,
      // add anything Flask endpoint needs (timestamps added server-side)
    };

    final clientOpId = await _repo.enqueueOp(
      targetType: 'item',
      targetId: itemId,
      opType: 'ADD_ITEM',
      payload: payload,
    );

    return (itemId: itemId, clientOpId: clientOpId);
  }
}
