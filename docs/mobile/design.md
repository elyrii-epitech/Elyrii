# Design system mobile

L’interface utilise Material 3, les polices Poppins embarquées et les composants
Liquid Glass communs. Les thèmes clair, sombre et système sont fournis par
`AppTheme` et persistés par `ThemeProvider`.

## Sources et composants

| Source dans `elyrii_app/lib` | Responsabilité |
| --- | --- |
| `core/theme/app_colors.dart` | Palette et couleurs de texte selon le thème |
| `core/theme/app_text_styles.dart` | Rôles typographiques Poppins |
| `core/theme/app_dimensions.dart` | Grille d’espacement, rayons et tailles |
| `core/glass/elyrii_glass_surface.dart` et `glass_role.dart` | Matériau partagé et rôles du verre |
| `core/widgets/glass/liquid_glass_kit.dart` | Boutons, cartes, contrôles, listes, dialogues et feuilles |
| `core/widgets/accessible_action.dart` | Activation clavier, focus et état d’action |
| `core/widgets/elyrii_page_header.dart` | Cadre et en-tête de page défilant |
| `core/accessibility/motion.dart` | Extension `animateRespectingMotion` |
| `app/router/app_shell.dart` | Navigation persistante et dock |

Importer les contrôles via :

```dart
import 'package:elyrii_app/core/widgets/glass/liquid_glass_kit.dart';
```

`LiquidGlassWidgets.initialize()` et `LiquidGlassWidgets.wrap` sont configurés
au démarrage. Les écrans utilisent les primitives Elyrii. `ElyriiGlassSurface`
fournit une surface opaque en contraste élevé et un chemin léger pour les
lignes déjà placées dans une feuille.

## Jetons de design

Les écrans choisissent un jeton, jamais une valeur. Seul `lib/core/theme/`
définit des tailles, graisses, distances et rayons.
`dart run tool/check_design_tokens.dart`, lancé en CI, refuse toute valeur brute
ailleurs.

Chaque rôle typographique fixe sa taille et sa graisse. Un état sélectionné
change la couleur, pas la graisse. Les titres d’onglet utilisent `pageTitle`
quel que soit le nombre de boutons. Les titres centrés des pages poussées, de
la barre réduite et du chat utilisent `navTitle`.

| Rôle | Taille et graisse | Usage |
| --- | --- | --- |
| `displaySmall` | 36, w600 | Marque au lancement |
| `pageTitle` | 28, w700 | Titre d’onglet, rendu par `ElyriiPageFrame` |
| `headlineMedium` | 28, w700 | Titres d’authentification et d’onboarding |
| `headlineSmall` | 24, w700 | Chiffres clés |
| `titleLarge` | 20, w600 | Titres de feuille et de dialogue |
| `titleMedium` | 17, w700 | Titres de section et de carte principale |
| `navTitle` | 17, w600 | Titre de navigation centré, rendu par l’en-tête |
| `titleSmall` | 15, w600 | Titres de carte et de ligne |
| `bodyLarge` | 16, w400 | Lecture, saisie, messages |
| `bodyMedium` | 14, w400 | Texte courant |
| `bodySmall` | 12, w400 | Texte secondaire |
| `labelLarge` | 15, w600 | Boutons |
| `labelMedium` | 13, w600 | Puces et libellés courts |
| `overline` | 13, w700 | Libellé au-dessus d’un groupe |
| `labelSmall` | 11, w500 | Légendes et dock, taille minimale |
| `badge` | 11, w700 | Étiquettes et pastilles |

Les couleurs de texte viennent de `context.textPrimary`, `textSecondary` et
`textTertiary`, qui suivent le thème courant.

Les espacements suivent une grille de 4 points : `spacing2` à `spacing48`.
`pageHorizontalPadding` (20) borde chaque page. `dockClearance` (130) laisse le
dernier élément d’un onglet défiler au-dessus du dock ; `pageBottomInset` (100)
termine les pages poussées. `controlSize` (48) est la taille des boutons en
verre et des espaces qui les équilibrent.

Les rayons sont `radius4`, `radius8`, `radius12`, `radius16`, `radius20`,
`radius28` pour les feuilles et `radiusPill` pour les capsules.

## Accessibilité et adaptation

Conserver les labels persistants, les états de chargement/sélection et les
zones tactiles des contrôles communs. Utiliser les couleurs du thème et laisser
le texte s’agrandir ; adapter les colonnes et permettre le défilement plutôt
que réduire la police pour faire tenir le contenu.

Les animations respectent les préférences système. Les scénarios de clavier,
de contraste, de texte agrandi et de lecteur d’écran sont décrits dans le
[protocole d’accessibilité](accessibility.md). Les tests widgets ne remplacent
pas la validation des composants natifs.

## Mascotte

`Mascot3DViewer` et `MascotModelSurface` utilisent `flutter_3d_controller` avec
un PNG de secours. Le corps et ses accessoires partagent une scène GLB.
La visibilité, le cycle de vie et les préférences d’animation contrôlent le
renderer ; sa pause et sa libération évitent un rendu permanent hors écran.

Les [accessoires](mascot-accessories.md) et les [mouvements](velours-motion.md)
ont leurs sources et outils de reconstruction. Les polices et portraits
livrés restent dans `elyrii_app/assets`.

## Icônes et lancement

Les sources sont `assets/splash_icon.png` pour le lancement et
`assets/icon_black_bg.png` pour l’icône de l’application. Depuis `elyrii_app` :

```bash
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```

Les configurations sont `flutter_native_splash.yaml` et la section
`flutter_launcher_icons` de `pubspec.yaml`. Vérifier les ressources générées
Android/iOS et les deux thèmes après une régénération.

Pour les listes longues, construire les éléments à la demande et limiter les
animations.
