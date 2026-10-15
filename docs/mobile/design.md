# Design system mobile

L’interface utilise Material 3, les polices Poppins embarquées et les composants
Liquid Glass communs. Les thèmes clair, sombre et système sont fournis par
`AppTheme` et persistés par `ThemeProvider`.

## Sources et composants

| Source dans `elyrii_app/lib` | Responsabilité |
| --- | --- |
| `core/theme/app_colors.dart` | Palette et couleurs selon le thème |
| `core/theme/app_text_styles.dart` | Typographie Poppins |
| `core/theme/app_dimensions.dart` | Espacements, rayons et dimensions |
| `core/design_system/colors/elyrii_colors.dart` | Alias sémantiques de couleurs |
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
