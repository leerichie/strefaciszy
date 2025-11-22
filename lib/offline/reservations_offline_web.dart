import 'package:strefa_ciszy/services/admin_api.dart';

class ReserveOrEnqueueResult {
  final bool enqueued;
  final Map<String, dynamic>? server;
  const ReserveOrEnqueueResult({required this.enqueued, this.server});
}

Future<ReserveOrEnqueueResult> reserveOrEnqueue({
  required String projectId,
  required String customerId,
  required String itemId,
  required num qty,
  required String actorEmail,
}) async {
  try {
    await AdminApi.init();
    final resp = await AdminApi.reserveUpsert(
      projectId: projectId,
      customerId: customerId,
      itemId: itemId,
      qty: qty,
      actorEmail: actorEmail,
    );
    return ReserveOrEnqueueResult(enqueued: false, server: resp);
  } catch (_) {
    return const ReserveOrEnqueueResult(enqueued: true);
  }
}
