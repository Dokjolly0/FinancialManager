import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/core/formatting/color_hex.dart';

void main() {
  group('colorToHex / colorFromHex', () {
    test('encodes a color as #RRGGBB', () {
      expect(colorToHex(const Color(0xFF176B5B)), '#176B5B');
    });

    test('round-trips through colorFromHex', () {
      const original = Color(0xFFB42318);
      final hex = colorToHex(original);
      final parsed = colorFromHex(hex);
      expect(parsed.toARGB32() & 0xFFFFFF, original.toARGB32() & 0xFFFFFF);
    });
  });
}
