import 'package:flutter/material.dart';

class Shadows {
  static const sm = [
    BoxShadow(
      color: Color(0x0A0B1118),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const card = [
    BoxShadow(
      color: Color(0x0A0B1118),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const md = [
    BoxShadow(
      color: Color(0x140B1118),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const lg = [
    BoxShadow(
      color: Color(0x1F0B1118),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];

  static const brand = [
    BoxShadow(color: Color(0x3D141417), blurRadius: 14, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x2BFF4B26), blurRadius: 4, offset: Offset(0, 2)),
  ];

  static const coral = [
    BoxShadow(
      color: Color(0x47FF4B26),
      blurRadius: 14,
      offset: Offset(0, 5),
    ),
  ];
}
