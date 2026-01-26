# Flutter Dependencies

Technical explanation of all Elyrii mobile project dependencies.

## Configuration

**SDK Environment**
```yaml
environment:
  sdk: ^3.5.0
```
Compatible with Dart 3.5.0 and higher (currently 3.10.0).

## Production dependencies

### UI and Interface

#### cupertino_icons (^1.0.8)
Native iOS Cupertino-style icon library provided by Flutter.

**Technical explanation:** Provides iOS system icon vector glyphs to ensure consistent appearance with Apple ecosystem. Directly integrated into Flutter framework.

**Justification:** Necessary for native iOS support and respect Apple Human Interface guidelines. Allows using standard iOS icons without additional assets.

---

#### iconsax (^0.0.8)
Collection of modern and modular vector icons.

**Technical explanation:** SVG icon library converted to Flutter IconData. Alternative to Material Icons with more modern and consistent design. Used for application business icons.

**Justification:** Choice of coherent and modern icon design system for application visual identity. More suitable than Material Icons for a contemporary look.

---

#### flutter_launcher_icons (^0.14.3)
Automatic application icon generator for all platforms.

**Technical explanation:** CLI tool that generates all required icon variants (Android: mipmap, iOS: Assets.xcassets, Web: favicon, etc.) à partir d'une image source unique. Executed via `flutter pub run` during build phase.

**Justification:** Automates generation of dozens of different icon sizes, avoids manual errors and accelerates deployment workflow.

---

### Animations

#### flutter_animate (^4.5.0)
Declarative animation framework based on widget extensions.

**Technical explanation:** Uses Builder pattern and Dart extensions to chain animations declaratively. Optimized with reusable AnimationControllers and automatic lifecycle management. Supports parallel and sequential animations.

**Justification:** Simple and expressive API to create complex animations without boilerplate code. Optimal performance with automatic controller management. Modern alternative to AnimatedBuilder.

---

#### shimmer (^3.0.0)
Animated loading effect with linear gradient.

**Technical explanation:** Implements animated gradient via LinearGradient and AnimationController to create shimmer effect. Uses CustomPainter for performant rendering. Commonly used for skeleton loaders.

**Justification:** Improves UX during loading by giving pleasant visual feedback. Recognized design pattern that reduces waiting time perception.

---

#### lottie (^3.1.0)
Lottie animation player (After Effects JSON format).

**Technical explanation:** Parser and renderer of vector animations in Lottie format (JSON). Uses Flutter canvas to draw frames. Supports complex animations with interpolation, masks, and effects. Lightweight alternative to GIFs and videos.

**Justification:** Allows integrating complex animations created by designers without compromising quality or size. Files ~10x lighter than equivalent GIFs.

---

#### flutter_staggered_grid_view (^0.7.0)
Advanced grid layouts with variable size tiles.

**Technical explanation:** GridView extension with support for masonry layout, quilted patterns, and staggered grids. Implements custom SliverGridDelegate to calculate non-uniform tile positions.

**Justification:** Necessary to create complex Pinterest/masonry layouts impossible with standard GridView. Used for achievement and quest galleries.

---

### Network

#### http (^1.2.0)
Official Dart HTTP client for network requests.

**Technical explanation:** Wrapper around dart:io HttpClient with simplified API. Automatically handles encodings (UTF-8, JSON), headers, and status codes. Support for asynchronous requests with Future. Used for communication with REST backend.

**Justification:** Official Dart package, well maintained and stable. Simple API sufficient for application REST needs. No need for Dio complexity for this project.

---

### State management

#### provider (^6.1.1)
State management solution based on InheritedWidget.

**Technical explanation:** Implements Provider/Consumer pattern using InheritedWidget for data propagation in widget tree. ChangeNotifierProvider listens to notifications via ChangeNotifier and triggers targeted rebuilds. Optimal performance thanks to selective rebuild.

**Justification:** Officially recommended by Flutter. Simpler than Bloc/Redux for an app of this size. Excellent performance with low learning curve. Perfect for theme management and global services.

---

### Storage

#### shared_preferences (^2.5.4)
Storage persistant clé-valeur cross-platform.

**Technical explanation:** Platform-specific abstraction (SharedPreferences Android, UserDefaults iOS, localStorage Web). Storage asynchrone en fichier sur disque. Limited to primitive types (String, int, double, bool, List<String>). Used for tokens, preferences, and simple cache.

**Justification:** Standard solution for preferences and simple data. No need for SQLite for current use cases (tokens, settings). Simple and reliable cross-platform API.

---

### Internationalization

#### intl (^0.20.2)
Official internationalization and formatting package.

**Technical explanation:** Provides DateFormat, NumberFormat, and ICU locale support. Handles plurals, genders, and localized messages via ARB files. Integration with flutter_localizations for complete i18n.

**Justification:** Official Flutter package for i18n. Necessary for French date formatting and future multilingual support. Industry standard for internationalization.

---

### Accessibility

#### flutter_tts (^4.2.5)
Text-to-Speech via platform native APIs.

**Technical explanation:** Bridge to native TTS engines (Android TextToSpeech, iOS AVSpeechSynthesizer). Communication via Flutter MethodChannel. Multi-language support, pitch, rate, and volume. Improves accessibility for visually impaired users.

**Justification:** Improves accessibility for visually impaired users, aligned with the app's social mission. Uses native engines for better voice quality. WCAG level AA criteria.

---

### Utilities

#### uuid (^4.5.1)
Universal unique identifier (UUID) generator.

**Technical explanation:** Implements RFC 4122 for UUID v1 (timestamp-based) and v4 (random) generation. Uses crypto.Random to ensure uniqueness. Standard 128-bit format for distributed IDs without collision.

**Justification:** Necessary to generate unique IDs for messages, sessions, objects without depending on backend. Avoids collisions in distributed system. Recognized standard.

---

#### email_validator (^3.0.0)
Email address validation according to RFC 5322.

**Technical explanation:** Advanced RFC 5322 compliant regex for email syntax validation. Checks format, allowed characters, and domain structure. Client-side validation before server submission.

**Justification:** Client-side validation improves UX by detecting errors before submission. More robust than custom regex. Compliant with RFC standards.

---

## Development dependencies

#### flutter_lints (^6.0.0)
Set of linting rules for Flutter.

**Technical explanation:** Dart analyzer configuration with strict rules recommended by Flutter team. Version 6.0.0 includes rules for null-safety, performance, and best practices. Executed by `flutter analyze` via analysis_options.yaml.

**Justification:** Ensures code quality and consistency. Detects potential bugs and antipatterns. Version 6.0 includes strictest rules for production-ready code.

---

## Technical summary by category

### UI and Rendering (5 packages)
- Native and modern icons
- Multi-platform asset generator
- Advanced layouts with custom grids
- Complex vector animations

### Animations (3 packages)
- Performant declarative framework
- Loading visual effects
- After Effects animation support

### Infrastructure (4 packages)
- Asynchronous HTTP client
- State management with InheritedWidget
- Multi-platform local persistence
- Internationalization complète

### Accessibility (1 package)
- Multi-platform native text-to-speech

### Utilities (2 packages)
- RFC 4122 compliant UUIDs
- RFC 5322 email validation

### Code quality (1 package)
- Strict linting with recommended Flutter rules

## Impact on application

**APK size:** ~15-20 MB (with dependencies)  
**Compatibility:**
- Android 5.0+ (API 21+)
- iOS 13.0+
- Dart 3.5.0+
- Flutter 3.38.2+

## Version management

```bash
# Check updates
flutter pub outdated

# Minor updates
flutter pub upgrade

# Major updates
flutter pub upgrade --major-versions
```
