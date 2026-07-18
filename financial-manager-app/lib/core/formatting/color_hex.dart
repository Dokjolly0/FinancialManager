import 'package:flutter/material.dart';

/// Encodes a [Color] as `#RRGGBB`, matching the format the backend
/// validates for avatar colors (plan.md section 11.2:
/// `^#[0-9A-Fa-f]{6}$`).
String colorToHex(Color color) {
  final argb = color.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Parses `#RRGGBB` (or `#AARRGGBB`) back into a [Color].
Color colorFromHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  final value = int.parse(
    cleaned.length == 6 ? 'FF$cleaned' : cleaned,
    radix: 16,
  );
  return Color(value);
}
