import 'package:elyrii_app/app/router/app_shell.dart';
import 'package:elyrii_app/core/design_system/colors/elyrii_colors.dart';
import 'package:elyrii_app/core/glass/elyrii_glass_surface.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/core/widgets/glass_bubble_button.dart';
import 'package:elyrii_app/core/widgets/glass_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

Future<GoRouter> _pumpShell(
  WidgetTester tester, {
  bool dark = false,
  bool highContrast = false,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/branch3',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          for (var i = 0; i < 6; i++)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/branch$i',
                  builder: (_, _) => _BranchView(index: i),
                ),
              ],
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.5),
          highContrast: highContrast,
          disableAnimations: reduceMotion,
          padding: const EdgeInsets.only(top: 24, bottom: 20),
        ),
        child: child!,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return router;
}

class _BranchView extends StatefulWidget {
  final int index;

  const _BranchView({required this.index});

  @override
  State<_BranchView> createState() => _BranchViewState();
}

class _BranchViewState extends State<_BranchView> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: GestureDetector(
        onTap: () => setState(() => count++),
        child: Text('Branche ${widget.index} · $count'),
      ),
    ),
  );
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('dock translucide en thème ${dark ? "sombre" : "clair"}', (
      tester,
    ) async {
      await _pumpShell(tester, dark: dark);
      final glasses = tester.widgetList<GlassContainer>(
        find.byType(GlassContainer),
      );
      expect(glasses, hasLength(2));
      for (final glass in glasses) {
        expect(glass.useOwnLayer, isTrue);
        expect(glass.settings?.glassColor.a, lessThan(0.25));
        expect(glass.settings?.blur, greaterThan(0));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'contraste élevé opaque en thème ${dark ? "sombre" : "clair"}',
      (tester) async {
        await _pumpShell(tester, dark: dark, highContrast: true);
        expect(find.byType(GlassContainer), findsNothing);
        for (final surface in tester.widgetList<ElyriiGlassSurface>(
          find.byType(ElyriiGlassSurface),
        )) {
          expect(surface.glassColor, isNull);
        }
        final expected = dark
            ? ElyriiColors.surfaceDark
            : ElyriiColors.surfaceLight;
        final surfaces = find.descendant(
          of: find.byType(ElyriiGlassSurface),
          matching: find.byType(Container),
        );
        expect(
          tester.widgetList<Container>(surfaces).where((container) {
            final decoration = container.decoration;
            return decoration is BoxDecoration && decoration.color == expected;
          }),
          hasLength(2),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('six destinations accessibles à 320 px et texte à 150 %', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpShell(tester, highContrast: true);
    const labels = ['Accueil', 'Jardin', 'Journal', 'Méditation', 'Coach'];
    for (var i = 0; i < labels.length; i++) {
      final tab = find.bySemanticsLabel('Onglet ${labels[i]}, ${i + 1} sur 5');
      expect(tab, findsOneWidget);
      final target = tester.getSize(tab);
      expect(target.width, greaterThanOrEqualTo(44));
      expect(target.height, greaterThanOrEqualTo(44));
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(find.text('Branche $i · 0'), findsOneWidget);
    }
    final chat = find.bySemanticsLabel('Chat Elyrii');
    expect(chat, findsOneWidget);
    expect(tester.getSize(chat).shortestSide, greaterThanOrEqualTo(44));
    await tester.tap(chat);
    await tester.pumpAndSettle();
    expect(find.text('Branche 5 · 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('activation au clavier et état des branches conservé', (
    tester,
  ) async {
    await _pumpShell(tester, highContrast: true);
    await tester.tap(find.text('Branche 3 · 0'));
    await tester.pump();
    const labels = ['Accueil', 'Jardin', 'Journal', 'Méditation', 'Coach'];
    for (var i = 0; i < 6; i++) {
      final target = i < 5
          ? find.text(labels[i])
          : find
                .descendant(
                  of: find.byType(GlassBubbleButton),
                  matching: find.byType(GestureDetector),
                )
                .first;
      Focus.of(tester.element(target)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(
        i.isEven ? LogicalKeyboardKey.enter : LogicalKeyboardKey.space,
      );
      await tester.pumpAndSettle();
      expect(find.text('Branche $i · ${i == 3 ? 1 : 0}'), findsOneWidget);
    }
    await tester.tap(find.text('Méditation'));
    await tester.pumpAndSettle();
    expect(find.text('Branche 3 · 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('réduire les animations supprime le rebond du dock', (
    tester,
  ) async {
    await _pumpShell(tester, highContrast: true, reduceMotion: true);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Méditation')),
    );
    await tester.pump(const Duration(milliseconds: 120));
    final scales = tester.widgetList<AnimatedScale>(
      find.descendant(
        of: find.byType(GlassNavigationBar),
        matching: find.byType(AnimatedScale),
      ),
    );
    expect(scales, hasLength(5));
    expect(scales.every((scale) => scale.scale == 1), isTrue);
    expect(scales.every((scale) => scale.duration == Duration.zero), isTrue);
    await gesture.up();
    final bubbleGesture = await tester.startGesture(
      tester.getCenter(find.byType(GlassBubbleButtonStateful)),
    );
    await tester.pump(const Duration(milliseconds: 120));
    final bubbleScale = tester.widget<AnimatedScale>(
      find.descendant(
        of: find.byType(GlassBubbleButtonStateful),
        matching: find.byType(AnimatedScale),
      ),
    );
    expect(bubbleScale.scale, 1);
    expect(bubbleScale.duration, Duration.zero);
    await bubbleGesture.up();
    expect(tester.takeException(), isNull);
  });
}
