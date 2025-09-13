import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:strefa_ciszy/offline/models/note_local.dart';
import 'package:strefa_ciszy/offline/models/pending_op.dart';
import 'package:strefa_ciszy/offline/models/photo_local.dart';
import 'package:strefa_ciszy/offline/models/project_item_local.dart';
import 'package:strefa_ciszy/offline/models/project_local.dart';
import 'package:uuid/uuid.dart';

import 'isar_db.dart';

class LocalRepository {
  final Isar _isar;
  final _uuid = const Uuid();

  LocalRepository._(this._isar);

  static Future<LocalRepository> create() async {
    final isar = await IsarDb.instance();
    return LocalRepository._(isar);
  }

  // ---------- Projects ----------
  Future<ProjectLocal?> getProject(String projectId) async {
    return _isar.projectLocals
        .where()
        .filter()
        .projectIdEqualTo(projectId)
        .findFirst();
  }

  Future<List<ProjectLocal>> listProjects() async {
    return _isar.projectLocals.where().sortByUpdatedAtLocalDesc().findAll();
  }

  Future<void> upsertProject({
    required String projectId,
    required String name,
    int serverVersion = 0,
    DateTime? updatedAtServer,
    SyncState syncState = SyncState.synced,
  }) async {
    final existing = await getProject(projectId);
    final model = ProjectLocal(
      id: existing?.id ?? Isar.autoIncrement,
      projectId: projectId,
      name: name,
      serverVersion: serverVersion,
      updatedAtServer: updatedAtServer,
      syncState: syncState,
    );
    await _isar.writeTxn(() async {
      await _isar.projectLocals.put(model);
    });
  }

  // ---------- Project Items ----------
  Future<List<ProjectItemLocal>> listItems(String projectId) {
    return _isar.projectItemLocals
        .where()
        .filter()
        .projectIdEqualTo(projectId)
        .sortByUpdatedAtLocalDesc()
        .findAll();
  }

  Future<ProjectItemLocal?> getItemByItemId(String itemId) async {
    return _isar.projectItemLocals
        .where()
        .filter()
        .itemIdEqualTo(itemId)
        .findFirst();
  }

  Future<void> upsertItem({
    required String itemId,
    required String projectId,
    required String productId,
    required double qty,
    String? note,
    int serverVersion = 0,
    DateTime? updatedAtServer,
    SyncState syncState = SyncState.pending,
  }) async {
    final existing = await getItemByItemId(itemId);
    final model = ProjectItemLocal(
      id: existing?.id ?? Isar.autoIncrement,
      itemId: itemId,
      projectId: projectId,
      productId: productId,
      qty: qty,
      note: note ?? existing?.note,
      serverVersion: serverVersion,
      updatedAtServer: updatedAtServer,
      syncState: syncState,
    );
    await _isar.writeTxn(() async {
      await _isar.projectItemLocals.put(model);
    });
  }

  Future<void> deleteItemByItemId(String itemId) async {
    final existing = await getItemByItemId(itemId);
    if (existing == null) return;
    await _isar.writeTxn(() async {
      await _isar.projectItemLocals.delete(existing.id);
    });
  }

  // ---------- Notes ----------
  Future<List<NoteLocal>> listNotes(String projectId) {
    return _isar.noteLocals
        .where()
        .filter()
        .projectIdEqualTo(projectId)
        .sortByCreatedAtLocalDesc()
        .findAll();
  }

  Future<String> addNote({
    required String projectId,
    required String text,
    SyncState syncState = SyncState.localOnly,
  }) async {
    final noteId = _uuid.v4();
    final model = NoteLocal(
      noteId: noteId,
      projectId: projectId,
      text: text,
      syncState: syncState,
    );
    await _isar.writeTxn(() async {
      await _isar.noteLocals.put(model);
    });
    return noteId;
  }

  // ---------- Photos ----------
  Future<List<PhotoLocal>> listPhotos(String projectId) {
    return _isar.photoLocals
        .where()
        .filter()
        .projectIdEqualTo(projectId)
        .sortByCreatedAtLocalDesc()
        .findAll();
  }

  Future<String> addPhotoLocal({
    required String projectId,
    required String localPath,
    String? thumbPath,
    SyncState syncState = SyncState.localOnly,
  }) async {
    final photoId = _uuid.v4();
    final model = PhotoLocal(
      photoId: photoId,
      projectId: projectId,
      localPath: localPath,
      thumbPath: thumbPath,
      cloudUrl: null,
      syncState: syncState,
    );
    await _isar.writeTxn(() async {
      await _isar.photoLocals.put(model);
    });
    return photoId;
  }

  Future<void> markPhotoCloudUrl({
    required String photoId,
    required String cloudUrl,
  }) async {
    final photo = await _isar.photoLocals
        .where()
        .filter()
        .photoIdEqualTo(photoId)
        .findFirst();
    if (photo == null) return;
    final updated = PhotoLocal(
      id: photo.id,
      photoId: photo.photoId,
      projectId: photo.projectId,
      localPath: photo.localPath,
      thumbPath: photo.thumbPath,
      cloudUrl: cloudUrl,
      syncState: SyncState.synced,
    );
    await _isar.writeTxn(() async {
      await _isar.photoLocals.put(updated);
    });
  }

  // ---------- Pending Ops (Outbox) ----------
  Future<String> enqueueOp({
    required String targetType,
    required String targetId,
    required String opType,
    required Map<String, dynamic> payload,
    String? dependsOnClientOpId,
  }) async {
    final clientOpId = _uuid.v4();
    final op = PendingOp(
      clientOpId: clientOpId,
      targetType: targetType,
      targetId: targetId,
      opType: opType,
      payloadJson: jsonEncode(payload),
      dependsOn: dependsOnClientOpId,
    );
    await _isar.writeTxn(() async {
      await _isar.pendingOps.put(op);
    });
    return clientOpId;
  }

  Future<List<PendingOp>> takePending({int limit = 25}) async {
    // Caller will process and then mark them done/attention.
    return _isar.pendingOps
        .where()
        .filter()
        .statusEqualTo('PENDING')
        .sortByCreatedAt()
        .findAll()
        .then((ops) => ops.take(limit).toList());
  }

  Future<void> markOpDone(String clientOpId) async {
    final op = await _isar.pendingOps
        .where()
        .filter()
        .clientOpIdEqualTo(clientOpId)
        .findFirst();
    if (op == null) return;
    await _isar.writeTxn(() async {
      op.status = 'DONE';
      op.lastTriedAt = DateTime.now();
      await _isar.pendingOps.put(op);
    });
  }

  Future<void> markOpTried(String clientOpId) async {
    final op = await _isar.pendingOps
        .where()
        .filter()
        .clientOpIdEqualTo(clientOpId)
        .findFirst();
    if (op == null) return;
    await _isar.writeTxn(() async {
      op.retryCount += 1;
      op.lastTriedAt = DateTime.now();
      await _isar.pendingOps.put(op);
    });
  }

  Future<void> markOpNeedsAttention(String clientOpId) async {
    final op = await _isar.pendingOps
        .where()
        .filter()
        .clientOpIdEqualTo(clientOpId)
        .findFirst();
    if (op == null) return;
    await _isar.writeTxn(() async {
      op.status = 'NEEDS_ATTENTION';
      op.lastTriedAt = DateTime.now();
      await _isar.pendingOps.put(op);
    });
  }
}
