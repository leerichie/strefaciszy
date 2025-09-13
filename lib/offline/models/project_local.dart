import 'package:isar/isar.dart';

part 'project_local.g.dart';

@collection
class ProjectLocal {
  Id id;
  String projectId;
  String name;

  int serverVersion;
  DateTime? updatedAtServer;
  DateTime updatedAtLocal;

  @enumerated
  SyncState syncState;

  ProjectLocal({
    this.id = Isar.autoIncrement,
    required this.projectId,
    required this.name,
    this.serverVersion = 0,
    this.updatedAtServer,
    DateTime? updatedAtLocal,
    this.syncState = SyncState.synced,
  }) : updatedAtLocal = DateTime.now();
}

enum SyncState { localOnly, pending, synced, needsAttention }
