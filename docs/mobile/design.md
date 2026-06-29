# Elyrii Mobile Design System

The Elyrii mobile design system is based on Material 3, a soft color palette,
Poppins through Google Fonts, and reusable Liquid Glass components.

## Reference Files

```text
lib/core/theme/
+-- app_colors.dart
+-- app_dimensions.dart
+-- app_text_styles.dart
+-- app_theme.dart

lib/core/widgets/
+-- glass/
|   +-- liquid_glass_action_sheet.dart
|   +-- liquid_glass_app_bar.dart
|   +-- liquid_glass_button.dart
|   +-- liquid_glass_card.dart
|   +-- liquid_glass_controls.dart
|   +-- liquid_glass_dialog.dart
|   +-- liquid_glass_list_tile.dart
|   +-- liquid_glass_sheet.dart
|   +-- liquid_glass_text_field.dart
|   +-- liquid_glass_toast.dart
+-- glass_container.dart
+-- glass_navigation_bar.dart
+-- glass_bubble_button.dart
+-- mascot_3d_viewer.dart
+-- mascot_customize_button.dart
```

## Theme

The app exposes three modes through `ThemeProvider`:
- `ThemeMode.system`
- `ThemeMode.light`
- `ThemeMode.dark`

The selected mode is persisted in `SharedPreferences` with the `theme_mode` key.

```dart
final themeProvider = context.watch<ThemeProvider>();
themeProvider.setThemeMode(ThemeMode.dark);
```

`MaterialApp` uses:

```dart
theme: AppTheme.lightTheme,
darkTheme: AppTheme.darkTheme,
themeMode: themeProvider.themeMode,
```

## Color Palette

### Primary Colors

- Primary: `#7E6AD8`
- Primary light: `#EDE8FF`
- Primary dark: `#A99AF0`
- Secondary: `#FFB5A8`
- Accent: `#A8D5BA`

### Semantic Colors

- Success: `#7BC393`
- Error: `#EA9999`
- Warning: `#FFCFA8`
- Info: `#93B8DA`

### Backgrounds

- Light background: `#FAF8F5`
- Light scaffold: `#E8E8EB`
- Dark background: `#1A1818`
- Dark scaffold: `#171719`
- Dark surface: `#2A2627`

### Feature Colors

- XP bar: `#FDD876`
- Level badge: `#7E6AD8`
- Streak: `#FFB5A8`
- Meditation active: `#7E6AD8`
- Chatbot gradient: `#7E6AD8` to `#A99AF0`

## Typography

`AppTextStyles` uses Poppins:

```dart
static final TextStyle _baseStyle = GoogleFonts.poppins();
```

Available levels:
- `displayLarge`, `displayMedium`, `displaySmall`
- `headlineLarge`, `headlineMedium`, `headlineSmall`
- `titleLarge`, `titleMedium`, `titleSmall`
- `bodyLarge`, `bodyMedium`, `bodySmall`
- `labelLarge`, `labelMedium`, `labelSmall`

Specialized styles:
- `chatbotMessage`
- `journalEntry`
- `timestamp`
- `emotionLabel`
- `objectiveTitle`
- `achievementBadge`
- `statNumber`
- `statLabel`

## Dimensions

Spacing and sizes live in `AppDimensions`.

### Spacing

```dart
spacingXxs = 4
spacingXs = 8
spacingSm = 12
spacingMd = 16
spacingLg = 24
spacingXl = 32
spacingXxl = 48
spacingXxxl = 64
```

### Radius

```dart
radiusXs = 4
radiusSm = 8
radiusMd = 12
radiusLg = 16
radiusXl = 24
radiusXxl = 32
radiusCircular = 1000
```

### Content Widths

- mobile: `480`
- tablet: `768`
- desktop: `1200`
- max content: `600`

## Liquid Glass

The Liquid Glass layer provides standard app components:
- `LiquidGlassCard`
- `LiquidGlassButton`
- `LiquidGlassIconButton`
- `LiquidGlassListTile`
- `LiquidGlassChip`
- `LiquidGlassSwitch`
- `LiquidGlassSlider`
- `LiquidGlassSegmentedControl`
- `LiquidGlassTextField`
- `LiquidGlassDialogContent`
- `LiquidGlassSheetContent`
- `LiquidGlassActionSheetContent`
- `LiquidGlassToast`
- `LiquidGlassAppBar`

Imports can use:

```dart
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
```

or the historical re-export:

```dart
import '../../../../core/widgets/liquid_glass_kit.dart';
```

## Visual Performance

`GlassPerformanceService` adapts visual effects:
- low-end device heuristics;
- manual effect reduction;
- adaptive blur while scrolling;
- optional highlight and transition disabling.

Persisted preferences:
- `reduce_glass_effects`
- `adaptive_blur_on_scroll`

Typical usage:

```dart
final performance = GlassPerformanceService();
final blur = performance.getEffectiveBlurSigma(22);
```

## Navigation

The main navigation uses:
- `GlassNavigationBar` for the five main tabs;
- `GlassBubbleButtonStateful` for the chatbot;
- `MascotCustomizeButton` as a global overlay.

`HomeNavigation` animates:
- tab changes with fade/scale;
- nav bar pulse;
- selected icons;
- haptic feedback.

Special route transitions:
- `/mascot-customization`: fade;
- `/settings`: slide from the right plus fade.

## 3D Mascot

The base component is `Mascot3DViewer`.

Capabilities:
- loads GLB files through `flutter_3d_controller`;
- shimmer while loading;
- `assets/mascotte.png` fallback;
- `idle` animation on load;
- optional auto-rotation;
- touch interactions disabled by default;
- recoloring through a color matrix.

Configurations:
- `Mascot3DConfig.authPage()`
- `Mascot3DConfig.chatbotFull()`
- `Mascot3DConfig.chatbotMinimized()`

Themes:
- Nature;
- Halloween;
- Panda;
- Noel;
- Cosmic;
- Ocean.

Themes recolor the same GLB through `ColorFilter.matrix`; they do not load a new
model.

## Animations

Packages in use:
- `flutter_animate` for declarative transitions;
- `lottie` for `breath.json` and `Coucou.json`;
- `shimmer` for loading states.

Real usages:
- auth pages: mascot and form fade/slide;
- journal: animation limited to the first 8 items;
- meditation: breathing circle through `AnimationController`;
- chatbot: text field glow while typing;
- chatbot mascot: slow pulse in full-screen mode.

## Accessibility and Emotional Safety

Already present:
- system text scaling through standard Flutter widgets;
- dedicated light/dark contrast colors;
- `flutter_tts` available as a dependency;
- emergency button in the chatbot;
- crisis keyword detection and help banner;
- useful phone numbers shown directly in the UI.

Needs improvement:
- add explicit `Semantics` to icon-only buttons;
- verify contrast across all Liquid Glass components;
- wire `flutter_tts` into flows that should read content aloud;
- avoid relying only on keyword matching for crisis messages.

## Responsive

`core/utils/responsive.dart` defines:

```dart
compact: < 360
phone: < 600
foldable: < 840
tablet: < 1200
desktop: >= 1200
```

Available helpers:
- `Responsive.getBreakpoint(context)`
- `Responsive.getGridColumns(context)`
- `Responsive.getHorizontalPadding(context)`
- `Responsive.getMaxContentWidth(context)`
- `ResponsiveBuilder`
- `ResponsiveConstrainedBox`
- `ResponsivePadding`

## Splash and Icons

`flutter_native_splash.yaml`:
- black background in light and dark mode;
- image `assets/icon.png`;
- Android 12 configured;
- web splash disabled.

`flutter_launcher_icons`:
- source `assets/icon_black_bg.png`;
- Android launcher icon;
- iOS with alpha removal.

## UI Contribution Rules

- Use `AppColors`, `AppDimensions`, and `AppTextStyles` before adding inline
  values.
- Prefer existing Liquid Glass components for buttons, cards, dialogs, sheets,
  and list tiles.
- Preserve light/dark support on every new screen.
- Add a visual fallback when a 3D or Lottie asset can fail.
- Limit animations in long lists to avoid frame drops.
- Test screens with reduced effects through `GlassPerformanceService`.
