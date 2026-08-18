/// Formate un montant en FCFA avec séparateur de milliers (espace) —
/// centralisé pour éviter que chaque écran de paiement/boost réimplémente
/// indépendamment le même arrondi/séparateur.
String formatFcfa(int amount) {
  final s = amount.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '${b.toString()} FCFA';
}
