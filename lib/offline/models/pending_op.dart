import 'package:isar/isar.dart';

part 'pending_op.g.dart';

@collection
class PendingOp {
  Id id;

  String clientOpId;
  String targetType;
  String targetId;
  String opType;
  String payloadJson;

  String? dependsOn;

  DateTime createdAt;
  DateTime? lastTriedAt;
  int retryCount;
  String status;

  PendingOp({
    this.id = Isar.autoIncrement,
    required this.clientOpId,
    required this.targetType,
    required this.targetId,
    required this.opType,
    required this.payloadJson,
    this.dependsOn,
    this.lastTriedAt,
    this.retryCount = 0,
    this.status = 'PENDING',
  }) : createdAt = DateTime.now();
}
