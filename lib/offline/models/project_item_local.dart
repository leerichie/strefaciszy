import 'package:isar/isar.dart';

import 'project_local.dart';

part 'project_item_local.g.dart';

@collection
class ProjectItemLocal {
  Id id;
  String itemId;
  String projectId;
  String productId;
  double qty;
  String? note;

  int serverVersion;
  DateTime? updatedAtServer;
  DateTime updatedAtLocal;

  @enumerated
  SyncState syncState;

  ProjectItemLocal({
    this.id = Isar.autoIncrement,
    required this.itemId,
    required this.projectId,
    required this.productId,
    required this.qty,
    this.note,
    this.serverVersion = 0,
    this.updatedAtServer,
    DateTime? updatedAtLocal,
    this.syncState = SyncState.synced,
  }) : updatedAtLocal = updatedAtLocal ?? DateTime.now();
}
