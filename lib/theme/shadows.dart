import 'package:flutter/material.dart';

class Shadows {
  static const sm = [
    BoxShadow(
      color: Color(0x0A1B1A2E),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const md = [
    BoxShadow(
      color: Color(0x141B1A2E),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const lg = [
    BoxShadow(
      color: Color(0x1F1B1A2E),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  static const brand = [
    BoxShadow(color: Color(0x527C3AED), blurRadius: 20, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x2FEC4899), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const coral = [
    BoxShadow(
      color: Color(0x66F97316),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];
}
