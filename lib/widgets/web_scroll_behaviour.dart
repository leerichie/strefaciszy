// widgets/web_scroll_behavior.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class WebScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch, // mobile
    PointerDeviceKind.mouse, // desktop click‐drag
    PointerDeviceKind.trackpad, // trackpad swipe
  };
}
