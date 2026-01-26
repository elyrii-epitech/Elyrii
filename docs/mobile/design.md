# Elyrii Mobile Design System

Design system, themes, and visual guidelines for the mobile application.

## Overview

The Elyrii application uses a consistent design system based on Material Design 3 with customizations for unique visual identity.

## Themes

### Dual theme support

The application supports two modes:
- Light mode (light theme)
- Dark mode (dark theme)

**Management:**
```dart
// Via Provider
final themeProvider = Provider.of<ThemeProvider>(context);
themeProvider.toggleTheme();

// Current mode
ThemeMode currentMode = themeProvider.themeMode;
```

### Configuration

Defined in `lib/core/theme/app_theme.dart`:

```dart
class AppTheme {
  static ThemeData lightTheme = ThemeData(...);
  static ThemeData darkTheme = ThemeData(...);
}
```

## Color palette

### Primary colors

**Light theme:**
- Primary: Primary brand color
- Secondary: Accent color
- Background: Primary background
- Surface: Surfaces (cards, dialogs)
- Error: Error messages

**Dark theme:**
- Adapted versions for dark mode
- Optimized contrast for readability

### Usage

```dart
// Access theme colors
final colorScheme = Theme.of(context).colorScheme;
Color primary = colorScheme.primary;
Color background = colorScheme.background;

// Custom colors
const brandTurquoise = Color(0xFF00CED1);
```

## Typography

### Text levels

**Headings:**
- displayLarge: Main titles
- displayMedium: Important subtitles
- displaySmall: Section titles

**Body:**
- bodyLarge: Main text
- bodyMedium: Standard text
- bodySmall: Secondary text

**Labels:**
- labelLarge: Button labels
- labelMedium: Form labels
- labelSmall: Secondary labels

### Usage

```dart
Text(
  'Titre',
  style: Theme.of(context).textTheme.displayLarge,
)

Text(
  'Contenu',
  style: Theme.of(context).textTheme.bodyMedium,
)
```

## Spacing

### Spacing system

**Constants** (définis dans `app_constants.dart`):
```dart
static const double spacingXS = 4.0;
static const double spacingS = 8.0;
static const double spacingM = 16.0;
static const double spacingL = 24.0;
static const double spacingXL = 32.0;
```

### Usage

```dart
Padding(
  padding: EdgeInsets.all(AppConstants.spacingM),
  child: child,
)

SizedBox(height: AppConstants.spacingL)
```

## UI Components

### Buttons

**Reusable widgets** dans `lib/core/widgets/`:

```dart
// Primary button
CustomButton(
  text: 'Connexion',
  onPressed: () {},
)

// Secondary button
CustomButton(
  text: 'Annuler',
  variant: ButtonVariant.secondary,
  onPressed: () {},
)
```

### Cards

```dart
CustomCard(
  child: Column(
    children: [
      // Contenu
    ],
  ),
)
```

### Loaders

```dart
// Loader with shimmer
ShimmerLoader()

// Circular loader
CustomLoader()
```

## Glass Morphism

### GlassPerformanceService

Automatic optimization of glass effects based on performance:

```dart
final glassService = Provider.of<GlassPerformanceService>(context);

// Use optimized glass effect
GlassContainer(
  blur: glassService.blurIntensity,
  opacity: glassService.opacity,
  child: child,
)
```

### Quality levels

**High performance:**
- High blur
- High transparency
- Smooth animations

**Low performance:**
- Reduced blur
- Increased opacity
- Simplified animations

## Animations

### Flutter Animate

**Usage:**
```dart
Text('Hello')
  .animate()
  .fadeIn(duration: 300.ms)
  .slideX(begin: -0.2, end: 0);
```

### Shimmer

**Loading states:**
```dart
Shimmer.fromColors(
  baseColor: Colors.grey[300],
  highlightColor: Colors.grey[100],
  child: Container(
    height: 50,
    width: double.infinity,
  ),
)
```

### Lottie

**Complex animations:**
```dart
Lottie.asset(
  'assets/animations/mascotte.json',
  width: 200,
  height: 200,
)
```

## Navigation

### Transitions

Consistent transitions between screens:

```dart
MaterialPageRoute(
  builder: (context) => NextScreen(),
)

// Or with custom animations
PageRouteBuilder(
  pageBuilder: (context, animation, secondaryAnimation) => NextScreen(),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(opacity: animation, child: child);
  },
)
```

## Icons

### Sources

**Iconsax:**
```dart
Icon(Iconsax.heart)
Icon(Iconsax.message)
Icon(Iconsax.calendar)
```

**Material Icons:**
```dart
Icon(Icons.settings)
Icon(Icons.person)
```

**Cupertino (iOS):**
```dart
Icon(CupertinoIcons.heart)
```

## Mascot

### Assets

- `assets/mascotte.png`: Eyes open
- `assets/mascotte_eyes_closed.png`: Eyes closed

### Animation

Configuration dans `lib/core/config/mascot_animations.dart`:

```dart
// Mascot states
enum MascotState {
  idle,
  happy,
  thinking,
  sleeping,
}
```

## Accessibility

### Contrast

**Verification:**
- Minimum ratio: 4.5:1 for normal text
- Minimum ratio: 3:1 for large text

**Tools:**
- Flutter DevTools > Inspector > Performance Overlay
- Color Contrast Analyzer

### Text sizes

System scaling support:

```dart
Text(
  'Texte',
  style: Theme.of(context).textTheme.bodyMedium,
  // Automatically inherits system scale factor
)
```

### Screen readers

Support for flutter_tts for text-to-speech.

## Responsive Design

### Breakpoints

```dart
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}
```

### Adaptive layout

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth < Breakpoints.mobile) {
      return MobileLayout();
    } else if (constraints.maxWidth < Breakpoints.tablet) {
      return TabletLayout();
    } else {
      return DesktopLayout();
    }
  },
)
```

## Maintenance

### Add a color

1. Définir dans `app_theme.dart`
2. Add for light and dark theme
3. Document usage
4. Check contrast

### Add a component

1. Create in `lib/core/widgets/`
2. Use theme constants
3. Support dark mode
4. Add documentation
5. Create widget test

### Modify theme

1. Update `app_theme.dart`
2. Test on all screens
3. Check light and dark mode
4. Validate accessibility
5. Update la documentation

## Resources

**Material Design 3:**
https://m3.material.io/

**Flutter Theming:**
https://docs.flutter.dev/cookbook/design/themes

**Accessibility:**
https://docs.flutter.dev/development/accessibility-and-localization/accessibility
