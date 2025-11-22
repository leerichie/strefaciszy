import 'dart:async';

import 'package:flutter/widgets.dart';

import '../offline_api.dart';

/// Wrap to auto-refresh

class ProductCacheLifecycleRefresher extends StatefulWidget {
  final Widget child;
  const ProductCacheLifecycleRefresher({super.key, required this.child});

  @override
  State<ProductCacheLifecycleRefresher> createState() =>
      _ProductCacheLifecycleRefresherState();
}

class _ProductCacheLifecycleRefresherState
    extends State<ProductCacheLifecycleRefresher>
    with WidgetsBindingObserver {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        unawaited(warmProductCache());
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
