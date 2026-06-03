library phosphor_flutter;

import 'package:flutter/widgets.dart';

// Patch local : `IconData` est devenu une `final class` (Flutter 3.43+/Dart 3.12),
// donc elle ne peut plus être étendue. À l'image du correctif amont, on remplace
// les anciennes sous-classes par de simples alias d'IconData ; les fichiers de
// style construisent désormais directement des `const IconData(...)`.
typedef PhosphorIconData = IconData;
typedef PhosphorFlatIconData = IconData;
typedef PhosphorDuotoneIconData = IconData;
