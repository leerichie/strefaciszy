import 'package:flutter/material.dart';
import 'package:strefa_ciszy/services/admin_api.dart';

/// Big inline button that lives in the page body (NOT a FloatingActionButton).
/// Sets an absolute reservation of 3 szt for item 1372 in project proj-demo-1.
class DebugReserveButton extends StatelessWidget {
  final String itemId;
  final String projectId;
  final String customerId;
  final String actorEmail;

  const DebugReserveButton({
    super.key,
    this.itemId = '1372', // has stock=9 in your DB
    this.projectId = 'proj-demo-1',
    this.customerId = 'custA',
    this.actorEmail = 'leerichie@wp.pl',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.bolt),
        label: const Text('TEST RES x1 (set 1372 → 3 szt)'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
        ),
        onPressed: () async {
          final m = ScaffoldMessenger.of(context);
          try {
            await AdminApi.init();
            final r = await AdminApi.reserveUpsert(
              projectId: projectId,
              customerId: customerId,
              itemId: itemId,
              qty: 3, // ABSOLUTE reservation for this project
              actorEmail: actorEmail,
            );
            m.showSnackBar(
              SnackBar(
                content: Text(
                  'OK: stock=${r['stock']}, reserved_total=${r['reserved_total']}, '
                  'available_after=${r['available_after']}, unit=${r['unit']}',
                ),
              ),
            );
          } catch (e) {
            m.showSnackBar(SnackBar(content: Text('reserveUpsert error: $e')));
          }
        },
      ),
    );
  }
}
