Logos des moyens de paiement Jeko, utilisés par PayMethodLogo
(lib/widgets/pay_method_logo.dart) via PayMethodX.logoAsset
(lib/core/services/payment_service.dart).

Utilisés aujourd'hui :

  wave.svg    → Wave        (SVG carré, viewBox 179.25×179.25)
  orange.svg  → Orange Money (idem)
  mtn.svg     → MTN MoMo     (idem)
  moov.png    → Moov Money  — généré depuis moov_money.webp (bandeau
                rectangulaire) : recadré en carré centré puis découpé en
                cercle (script Python/Pillow, crop + masque ellipse).
                Régénérer si moov_money.webp change.
  Djamo.svg   → Djamo       — wordmark NOIR uniquement (pas d'icône
                carrée ni de version couleur disponible). PayMethodLogo
                lui donne un fond blanc fixe (logoNeedsLightBackdrop)
                pour rester lisible sur les surfaces sombres du thème
                dark-first — sinon invisible sur fond sombre.

Les autres fichiers du dossier (Wave.png, Wave_icon.png, Wave_play.png,
Orange_CI.*, MTN_CI.*, Moov_Africa_CI.png, Djamo.png, Orabank.png,
mastercard.svg, visa.svg…) ne sont pas référencés par le code (Orabank
et card ne font pas partie des moyens de paiement Jeko actuels) —
conservés au cas où mais inutilisés.
