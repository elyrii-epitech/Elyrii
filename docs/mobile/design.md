# Mobile design system

The interface uses Material 3, bundled Poppins fonts, and shared Liquid Glass
components. `AppTheme` provides light, dark, and system themes, persisted by
`ThemeProvider`.

## Sources and components

| Source in `elyrii_app/lib` | Responsibility |
| --- | --- |
| `core/theme/app_colors.dart` | Palette and theme-aware text colors |
| `core/theme/app_text_styles.dart` | Poppins typography roles |
| `core/theme/app_dimensions.dart` | Spacing grid, radii, and sizes |
| `core/glass/elyrii_glass_surface.dart` and `glass_role.dart` | Shared material and glass roles |
| `core/widgets/glass/liquid_glass_button.dart` | Shared buttons |
| `core/widgets/accessible_action.dart` | Keyboard activation, focus, and action state |
| `core/widgets/elyrii_page_header.dart` | Scrolling page frame and header |
| `core/accessibility/motion.dart` | `animateRespectingMotion` extension |
| `app/router/app_shell.dart` | Persistent navigation and dock |

Import buttons directly:

```dart
import 'package:elyrii_app/core/widgets/glass/liquid_glass_button.dart';
```

`LiquidGlassWidgets.initialize()` and `LiquidGlassWidgets.wrap` are configured
at startup. Screens use Elyrii primitives. `ElyriiGlassSurface` provides an
opaque surface in high contrast and a lightweight path for rows already
inside a sheet.

## Design tokens

Screens choose a token rather than a literal value. `lib/core/theme/` defines
sizes, weights, distances, and radii. `dart run tool/check_design_tokens.dart`,
run in CI, is a text scan: it rejects `fontSize`, `fontFamily`, `fontWeight`,
`circular(n)` radii, numeric margins/gaps (`EdgeInsets`, empty `SizedBox`,
`spacing`), and `AppColors.text*Light/Dark` outside the theme. It does not detect
icon/element sizes or named constants; those still require review.

Each typography role fixes its size and weight. Selection changes color rather
than weight; only a dialog's default action switches from `dialogAction` to
`labelLarge`. A tab starts with its large `pageTitle` in the first content row
below the button bar: it scales with text settings and wraps instead of shrinking.
On scroll, the same title appears centered in the bar as `navTitle`, as on
pushed pages and chat. Overlong bar titles end with an ellipsis.

Garden, Journal, Meditation, and Journeys share `SectionSkyHeader`. Their titles
have matching alignment and no subtitle. Journal keeps its full-width window
without a strip beneath its sill. Journey arches extend to the rounded content
without a horizontal strip.

| Role | Size and weight | Use |
| --- | --- | --- |
| `wordmark` | 38, w500 | Launch logo |
| `pageTitle` | 28, w700 | Large tab title rendered by `ElyriiPageFrame` |
| `headlineMedium` | 28, w700 | Authentication and onboarding titles |
| `headlineSmall` | 24, w700 | Key figures |
| `titleLarge` | 20, w600 | Sheet and dialog titles |
| `titleMedium` | 17, w700 | Section and primary card titles |
| `navTitle` | 17, w600 | Centered bar title rendered by the header |
| `titleSmall` | 15, w600 | Card and row titles |
| `bodyLarge` | 16, w400 | Reading, input, messages |
| `bodyMedium` | 14, w400 | Body text |
| `bodySmall` | 12, w500 | Secondary text |
| `labelLarge` | 15, w600 | Buttons and default dialog action |
| `dialogAction` | 15, w400 | Other dialog actions |
| `labelMedium` | 13, w600 | Chips and short labels |
| `overline` | 13, w700 | Group labels and Home date |
| `labelSmall` | 11, w500 | Captions, minimum size |
| `badge` | 11, w700 | Tags and badges |
| `dockLabel` | 11, w500 | Dock tabs, zero letter spacing |

The dock is 64 points high, with a circular 64-point chat bubble and a 44-point
color avatar. `assets/brand/mascot_nav.png` crops the mascot without the launch
image's large transparent margins. The dock stays centered within the 600-point
content column, with 16-point side margins and a 20-point bottom margin.
The navigation role of `ElyriiGlassSurface` applies v2 glass, blur 22,
saturation 1.7, and a 0.5 border, without refraction, shadow, halo, or gradient.
The first four tabs use Material Symbols Rounded, filled only when selected.
`AppShell` defines the fifth tab's destination.

Targets are at least 48 points. Below 360 points in width or above 120% text
scale, a dropdown gives access to all six destinations without shrinking labels.
Press feedback retains a 0.96 scale, with no motion when animations are disabled.
The dock has no selection bounce or autonomous animation.

Text colors come from `context.textPrimary`, `textSecondary`, and `textTertiary`,
which follow the current theme.

Spacing follows a 4-point grid, from `spacing2` to `spacing48`.
`pageHorizontalPadding` (20) frames each page. `ElyriiPageFrame` ends each page
with the Scaffold's bottom inset (the dock on a tab, the home indicator elsewhere)
plus `spacing24`; pages do not add their own trailing space. `controlSize` (48)
sizes glass buttons and balancing spacers; `buttonHeight` (48) sizes filled buttons.

Radii are `radius4`, `radius8`, `radius12`, `radius16`, `radius20`,
`radius28` for sheets, and `radiusPill` for capsules.

## Accessibility and adaptation

Preserve persistent labels, loading/selection states, and touch areas in shared
controls. Use theme colors and allow text growth; adapt columns and enable
scrolling instead of shrinking fonts to fit.

Animations respect system preferences. Keyboard, contrast, enlarged text, and
screen reader scenarios are described in the [accessibility protocol](accessibility.md).
Widget tests do not replace native component validation.

## Mascot

`Mascot3DViewer` and `MascotModelSurface` use `flutter_3d_controller` with a PNG
fallback. The body and accessories share one GLB scene. Visibility, lifecycle,
and motion preferences control the renderer; suspension and release prevent
continuous offscreen rendering.

[Accessories](mascot-accessories.md) and [motion](velours-motion.md) have their
own sources and rebuilding tools. Bundled fonts and portraits remain in
`elyrii_app/assets`.

## Icons and launch

Sources are `assets/splash_icon.png` for launch and `assets/icon_black_bg.png`
for the app icon. From `elyrii_app`:

```bash
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```

Configuration lives in `flutter_native_splash.yaml` and the
`flutter_launcher_icons` section of `pubspec.yaml`. Check generated Android/iOS
resources and both themes after regeneration.

For long lists, build items on demand and limit animations.
