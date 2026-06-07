import 'package:flutter/services.dart';

abstract final class Haptics {
  /// Tap léger — navigation, chips, filtres, toggles secondaires
  static void light()     => HapticFeedback.lightImpact();

  /// Tap moyen — actions positives (participer, envoyer, accepter un appel)
  static void medium()    => HapticFeedback.mediumImpact();

  /// Tap fort — actions critiques ou destructives (raccrocher, refuser, confirmer suppression)
  static void heavy()     => HapticFeedback.heavyImpact();

  /// Sélection — chips actifs, toggles d'état, onglets
  static void selection() => HapticFeedback.selectionClick();
}
