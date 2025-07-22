import 'package:flutter/material.dart';

Color colourFromString(String input) {
  final hash = input.hashCode;
  final hue = (hash % 360).toDouble();
  return HSVColor.fromAHSV(1.0, hue, 0.5, 0.85).toColor();
}
