# Mobile CI/CD Elyrii

Automated configuration and testing for the mobile application.

## GitHub Actions Workflows

The project uses two automatic workflows:

**flutter-build.yml**
- Build Android and iOS
- Triggered on push and PR to `main` and `dev`

**flutter-check-and-docs.yml**
- Formatting, analysis, tests verification
- Triggered on push and PR to `main` and `dev`

## Configuration

**Flutter version:** 3.38.2  
**Cache enabled:** Yes (30-50% build time reduction)

## Run all tests locally

Before pushing, execute these commands in order:

### 1. Formatting

```bash
cd elyrii_app
dart format .
```

### 2. Static analysis

```bash
flutter analyze
```

Must return: `No issues found!`

### 3. Unit tests

```bash
flutter test
```

All tests must pass.

### 4. Android build (optional)

```bash
flutter build apk --release
```

### 5. All in one command

```bash
cd elyrii_app && \
dart format . && \
flutter analyze && \
flutter test && \
echo "All checks pass"
```

## Check workflows

**URL:** https://github.com/elyrii-epitech/Elyrii/actions

**Status:**
- Yellow: In progress
- Green: Success
- Red: Failure

## Fix failures

**If formatting fails:**
```bash
dart format .
git add .
git commit -m "style: format code"
```

**If analyze fails:**
```bash
flutter analyze
# Fix displayed errors
git commit -m "fix: resolve analysis issues"
```

**If tests fail:**
```bash
flutter test
# Fix tests or code
git commit -m "fix: resolve test failures"
```

## Artifacts

Successful builds generate downloadable artifacts:
- Android APK: `app-android-apk`
- iOS build: `app-ios-build`
- Documentation: `dartdoc-html`
