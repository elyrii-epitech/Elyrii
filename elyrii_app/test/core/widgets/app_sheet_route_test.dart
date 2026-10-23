import 'package:elyrii_app/core/theme/app_colors.dart';
import 'package:elyrii_app/core/theme/app_dimensions.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/core/widgets/app_sheet_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    bool canDismiss = true,
    bool reduced = false,
    double contentHeight = 300,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                AppSheetRoute<void>(
                  reduced: reduced,
                  canDismiss: () => canDismiss,
                  builder: (_) => AppSheetPanel(
                    title: 'Présentation',
                    child: SizedBox(height: contentHeight),
                  ),
                ),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  final surface = find.byWidgetPredicate(
    (widget) => widget is Material && widget.color == AppColors.sheetDark,
  );

  Future<TestGesture> slowDrag(
    WidgetTester tester,
    Offset start,
    double dy,
  ) async {
    final gesture = await tester.startGesture(start);
    for (var step = 0; step < 10; step++) {
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(Offset(0, dy / 10));
    }
    await tester.pump();
    return gesture;
  }

  for (final reduced in [false, true]) {
    testWidgets(
      'drag follows the finger and returns below 25%, reduced $reduced',
      (tester) async {
        await openSheet(tester, reduced: reduced);
        final original = tester.getRect(surface);
        final distance = original.height * .2;
        final gesture = await slowDrag(
          tester,
          tester.getCenter(find.text('Présentation')),
          distance,
        );
        expect(
          tester.getRect(surface).top,
          closeTo(original.top + distance, 1),
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.getRect(surface), original);
      },
    );

    testWidgets('drag dismisses above 25%, reduced $reduced', (tester) async {
      await openSheet(tester, reduced: reduced);
      final height = tester.getSize(surface).height;
      final gesture = await slowDrag(
        tester,
        tester.getCenter(find.text('Présentation')),
        height * .3,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(AppSheetPanel), findsNothing);
    });
  }

  testWidgets('a refused dismissal restores the sheet', (tester) async {
    await openSheet(tester, canDismiss: false);
    final original = tester.getRect(surface);
    final gesture = await slowDrag(
      tester,
      tester.getCenter(find.text('Présentation')),
      original.height * .4,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(surface), original);
  });

  testWidgets(
    'scrolling content from below its top never dismisses the sheet',
    (tester) async {
      await openSheet(tester, contentHeight: 1500);
      final original = tester.getRect(surface);
      final scroll = find.byType(SingleChildScrollView);
      await tester.drag(scroll, const Offset(0, -300));
      await tester.pumpAndSettle();
      final gesture = await slowDrag(tester, tester.getCenter(scroll), 400);
      expect(tester.getRect(surface), original);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(AppSheetPanel), findsOneWidget);
      final headerDrag = await slowDrag(
        tester,
        tester.getCenter(find.text('Présentation')),
        original.height * .3,
      );
      await headerDrag.up();
      await tester.pumpAndSettle();
      expect(find.byType(AppSheetPanel), findsNothing);
    },
  );

  testWidgets('a fast downward swipe dismisses below the distance threshold', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.flingFrom(
      tester.getCenter(find.text('Présentation')),
      const Offset(0, 45),
      1500,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppSheetPanel), findsNothing);
  });

  for (final width in [390.0, 1440.0]) {
    for (final dark in [true, false]) {
      testWidgets('sheet reaches the bottom at $width, dark $dark', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const contentKey = Key('last-sheet-content');
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    AppSheetRoute<void>(
                      reduced: true,
                      builder: (_) => const AppSheetPanel(
                        title: 'Présentation',
                        child: SizedBox(key: contentKey, height: 80),
                      ),
                    ),
                  ),
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();
        final surface = find.byWidgetPredicate(
          (widget) =>
              widget is Material &&
              widget.color ==
                  (dark ? AppColors.sheetDark : AppColors.sheetLight),
        );
        final rect = tester.getRect(surface);
        expect(rect.bottom, 844);
        expect(rect.width, width.clamp(0, AppDimensions.maxContentWidth));
        expect(rect.center.dx, width / 2);
        final material = tester.widget<Material>(surface);
        expect(material.color!.a, 1);
        final radius = material.borderRadius!.resolve(TextDirection.ltr);
        expect(radius.bottomLeft, Radius.zero);
        expect(radius.bottomRight, Radius.zero);
        expect(
          tester.getRect(find.byKey(contentKey)).bottom,
          lessThanOrEqualTo(810),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
