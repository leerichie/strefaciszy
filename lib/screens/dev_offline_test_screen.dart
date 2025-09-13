import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../offline/local_repository.dart';
import '../offline/offline_actions.dart';
import '../offline/sync_service.dart';

class DevOfflineTestScreen extends StatefulWidget {
  const DevOfflineTestScreen({super.key});

  @override
  State<DevOfflineTestScreen> createState() => _DevOfflineTestScreenState();
}

class _DevOfflineTestScreenState extends State<DevOfflineTestScreen> {
  final _uuid = const Uuid();
  String _log = '';
  int _pendingCount = 0;

  Future<void> _refreshPending() async {
    final repo = await LocalRepository.create();
    final ops = await repo.takePending(limit: 9999);
    setState(() => _pendingCount = ops.length);
  }

  void _append(String msg) {
    setState(() => _log = '${DateTime.now().toIso8601String()}  $msg\n$_log');
  }

  // Future<void> _ensureSignedIn() async {
  //   final auth = FirebaseAuth.instance;
  //   if (auth.currentUser != null) return;

  //   // EITHER anonymous (only if rules allow it)
  //   // await auth.signInAnonymously();

  //   // OR email/password for a dev user that already exists
  //   await auth.signInWithEmailAndPassword(
  //     email: 'leerichie@wp.pl',
  //     password: 'Strefa5568!',
  //   );
  // }

  Future<void> _enqueueAddItem() async {
    final actions = await OfflineActions.create();
    final projectId = 'EC6mC4jvtS1OByy9rgqT';
    final customerId = 'ucF7tUeOsh4KA2zQoyfl';
    final productId = '1674';
    final qty = 1.0;

    final res = await actions.addItemToProjectOptimistic(
      customerId: customerId,
      projectId: projectId,
      productId: productId,
      qty: qty,
      note: 'Debug add',
      userId: 'dev-user',
      userEmail: 'dev@example.com',
      projectNameFallback: 'DEV Project',
    );

    _append(
      'Enqueued ADD_ITEM: itemId=${res.itemId}, clientOpId=${res.clientOpId}',
    );
    await _refreshPending();
  }

  Future<void> _runSyncOnce() async {
    final sync = await SyncService.create();
    final n = await sync.runOnce(batchSize: 25);
    _append('Sync runOnce processed: $n');
    await _refreshPending();
  }

  @override
  void initState() {
    super.initState();
    _refreshPending();
    // _ensureSignedIn().then((_) => _refreshPending());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dev Offline Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending ops: $_pendingCount',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: _enqueueAddItem,
                  child: const Text('Enqueue ADD_ITEM'),
                ),
                ElevatedButton(
                  onPressed: _runSyncOnce,
                  child: const Text('Run Sync Once'),
                ),
                ElevatedButton(
                  onPressed: _refreshPending,
                  child: const Text('Refresh Pending'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Log:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  _log,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
