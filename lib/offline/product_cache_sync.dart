import 'package:shared_preferences/shared_preferences.dart';

import 'repositories/product_cache_repository.dart';

class ProductCacheSync {
  static const _kSeedDone = 'product_cache.seed_done';
  static const _kLastDeltaIso = 'product_cache.last_delta_iso';

  final ProductCacheRepository repo;
  final SharedPreferences prefs;

  ProductCacheSync._(this.repo, this.prefs);

  static Future<ProductCacheSync> create({
    required ProductCacheRepository repo,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return ProductCacheSync._(repo, prefs);
  }

  Future<void> warm({bool forceSeed = false}) async {
    final seeded = prefs.getBool(_kSeedDone) ?? false;

    if (!seeded || forceSeed) {
      final count = await repo.initialSeed();
      await prefs.setBool(_kSeedDone, true);
      await _markNow();
      // (Optional) you could log `count` somewhere
      return;
    }

    final since = _lastDelta();
    await repo.refreshDeltas(since: since);
    await _markNow();
  }

  DateTime? _lastDelta() {
    final iso = prefs.getString(_kLastDeltaIso);
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  Future<void> _markNow() =>
      prefs.setString(_kLastDeltaIso, DateTime.now().toUtc().toIso8601String());
}
