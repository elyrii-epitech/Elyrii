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
| `core/widgets/glass/liquid_glass_button.dart` | Boutons partagés |
| `core/widgets/accessible_action.dart` | Activation clavier, focus et état d’action |
| `core/widgets/elyrii_page_header.dart` | Cadre et en-tête de page défilant |
| `core/accessibility/motion.dart` | Extension `animateRespectingMotion` |
| `app/router/app_shell.dart` | Navigation persistante et dock |

Importer les boutons directement :

```dart
import 'package:elyrii_app/core/widgets/glass/liquid_glass_button.dart';
```

`LiquidGlassWidgets.initialize()` et `LiquidGlassWidgets.wrap` sont configurés
au démarrage. Les écrans utilisent les primitives Elyrii. `ElyriiGlassSurface`
fournit une surface opaque en contraste élevé et un chemin léger pour les
lignes déjà placées dans une feuille.

## Jetons de design

Les écrans choisissent un jeton, jamais une valeur. `lib/core/theme/` définit
les tailles, graisses, distances et rayons. `dart run
tool/check_design_tokens.dart`, lancé en CI, est un balayage de texte : il
refuse `fontSize`, `fontFamily`, `fontWeight`, les rayons `circular(n)`, les
marges et écarts chiffrés (`EdgeInsets`, `SizedBox` vide, `spacing`) et les
couleurs `AppColors.text*Light/Dark` hors du thème. Il ne voit ni les tailles
d’icônes ou d’éléments, ni les constantes nommées ; ces cas restent à la revue.

Chaque rôle typographique fixe sa taille et sa graisse. Un état sélectionné
change la couleur, pas la graisse ; seule l’action par défaut d’un dialogue
passe de `dialogAction` à `labelLarge`. Un onglet commence par son grand titre
(`pageTitle`) en première ligne du contenu, sous la barre de boutons : il suit
la taille de texte et passe à la ligne au lieu de rétrécir. En défilant, le
même titre apparaît centré dans la barre en `navTitle`, comme le titre des
pages poussées et du chat. Un titre de barre trop long finit par une ellipse.

Jardin, Journal, Méditer et Parcours partagent `SectionSkyHeader`.
Leurs titres ont le même alignement et aucun sous-titre.
Le décor du Journal conserve sa fenêtre pleine largeur, sans bande sous son appui.
Les arches de Parcours se prolongent jusqu'au contenu arrondi, sans bande horizontale.

| Rôle | Taille et graisse | Usage |
| --- | --- | --- |
| `wordmark` | 38, w500 | Logo « elyrii » au lancement |
| `pageTitle` | 28, w700 | Grand titre d’onglet, rendu par `ElyriiPageFrame` |
| `headlineMedium` | 28, w700 | Titres d’authentification et d’onboarding |
| `headlineSmall` | 24, w700 | Chiffres clés |
| `titleLarge` | 20, w600 | Titres de feuille et de dialogue |
| `titleMedium` | 17, w700 | Titres de section et de carte principale |
| `navTitle` | 17, w600 | Titre centré dans la barre, rendu par l’en-tête |
| `titleSmall` | 15, w600 | Titres de carte et de ligne |
| `bodyLarge` | 16, w400 | Lecture, saisie, messages |
| `bodyMedium` | 14, w400 | Texte courant |
| `bodySmall` | 12, w500 | Texte secondaire |
| `labelLarge` | 15, w600 | Boutons, action par défaut d’un dialogue |
| `dialogAction` | 15, w400 | Autres actions d’un dialogue |
| `labelMedium` | 13, w600 | Puces et libellés courts |
| `overline` | 13, w700 | Libellé au-dessus d’un groupe, date de l’accueil |
| `labelSmall` | 11, w500 | Légendes, taille minimale |
| `badge` | 11, w700 | Étiquettes et pastilles |
| `dockLabel` | 11, w500 | Onglets du dock, tracking nul |

Le dock mesure 64 points de haut, avec une bulle de chat circulaire de 64
et un avatar couleur de 44. `assets/brand/mascot_nav.png` recadre la mascotte
sans les grandes marges transparentes de l'image de lancement.
Le dock reste centré dans la colonne de contenu de 600 points, avec des marges
latérales de 16 et une marge basse de 20.
Le rôle navigation de `ElyriiGlassSurface` applique le verre v2, flou 22,
saturation 1,7 et filet de 0,5, sans réfraction, ombre, halo ni gradient.
Les quatre premiers onglets utilisent Material Symbols Rounded, remplis
uniquement en sélection. La destination du cinquième onglet reste définie
par `AppShell`.

Les cibles font au moins 48 points. Sous 360 points de largeur ou au-delà
de 120 % de taille de texte, un sélecteur déroulant donne accès aux six
destinations sans réduire les libellés. La pression conserve une échelle
de 0,96, sans mouvement lorsque les animations sont désactivées. Le dock
n'a ni rebond de sélection ni animation autonome.

Les couleurs de texte viennent de `context.textPrimary`, `textSecondary` et
`textTertiary`, qui suivent le thème courant.

Les espacements suivent une grille de 4 points : `spacing2` à `spacing48`.
`pageHorizontalPadding` (20) borde chaque page. `ElyriiPageFrame` termine
chaque page par la marge basse fournie par le Scaffold (le dock sur un onglet,
l’indicateur d’accueil ailleurs) plus `spacing24` ; les pages n’ajoutent pas
d’espace final. `controlSize` (48) est la taille des boutons en verre et des
espaces qui les équilibrent ; `buttonHeight` (48) celle des boutons pleins.

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
