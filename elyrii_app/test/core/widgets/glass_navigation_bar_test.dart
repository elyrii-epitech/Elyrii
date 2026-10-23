import 'package:elyrii_app/app/router/app_shell.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/core/glass/elyrii_glass_surface.dart';
import 'package:elyrii_app/core/theme/app_dimensions.dart';
import 'package:elyrii_app/core/theme/app_text_styles.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/core/widgets/glass_bubble_button.dart';
import 'package:elyrii_app/core/widgets/glass_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

Future<GoRouter> _pumpShell(
  WidgetTester tester, {
  bool dark = false,
  bool highContrast = false,
  bool reduceMotion = false,
  double textScale = 1,
  Size size = const Size(390, 844),
  bool boldText = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = ApiClient(storage: SecureStorageService());
  addTearDown(api.dispose);
  final gamification = GamificationProvider(client: api)
    ..onUserChanged(userId: 'demo-user', isDemo: true);
  addTearDown(gamification.dispose);
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
    ChangeNotifierProvider<GamificationProvider>.value(
      value: gamification,
      child: MaterialApp.router(
        routerConfig: router,
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            highContrast: highContrast,
            disableAnimations: reduceMotion,
            boldText: boldText,
            padding: const EdgeInsets.only(top: 24, bottom: 20),
          ),
          child: child!,
        ),
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
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('Poppins')
          ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf')))
        .load();
  });
  testWidgets(
    'six destinations remain reachable in the 300 percent navigation selector',
    (tester) async {
      await _pumpShell(
        tester,
        highContrast: true,
        reduceMotion: true,
        textScale: 3,
      );
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(ModalBarrier), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        final item = find.byWidgetPredicate(
          (widget) => widget is DropdownMenuItem<int> && widget.value == i,
        );
        final label = find
            .descendant(of: item.last, matching: find.byType(Text))
            .last;
        await tester.scrollUntilVisible(
          label,
          i < (i == 0 ? 3 : i - 1) ? -100 : 100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(label);
        await tester.pumpAndSettle();
        expect(
          find.text('Branche $i · 0'),
          findsOneWidget,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((w) => w.data)
              .where((s) => s?.startsWith('Branche') ?? false)
              .join(', '),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  for (final dark in [false, true]) {
    testWidgets('dock translucide en thème ${dark ? "sombre" : "clair"}', (
      tester,
    ) async {
      await _pumpShell(tester, dark: dark);
      final glasses = tester.widgetList<BackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(glasses, hasLength(2));
      for (final surface in tester.widgetList<ElyriiGlassSurface>(
        find.byType(ElyriiGlassSurface),
      )) {
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byWidget(surface),
                matching: find.byType(Container),
              )
              .first,
        );
        final color = (container.decoration! as BoxDecoration).color!;
        expect(color.a, inExclusiveRange(0, 1));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'contraste élevé opaque en thème ${dark ? "sombre" : "clair"}',
      (tester) async {
        await _pumpShell(tester, dark: dark, highContrast: true);
        expect(
          tester
              .widgetList<BackdropFilter>(find.byType(BackdropFilter))
              .every((filter) => !filter.enabled),
          isTrue,
        );
        for (final surface in tester.widgetList<ElyriiGlassSurface>(
          find.byType(ElyriiGlassSurface),
        )) {
          expect(surface.glassColor, isNull);
        }
        final surfaces = find.descendant(
          of: find.byType(ElyriiGlassSurface),
          matching: find.byType(Container),
        );
        expect(
          tester.widgetList<Container>(surfaces).where((container) {
            final decoration = container.decoration;
            // Le repli haut contraste reste opaque, quelle que soit la
            // translucidité du jeton surface.
            return decoration is BoxDecoration && decoration.color?.a == 1;
          }),
          hasLength(2),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('six destinations accessibles avec des cibles de 48 px', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpShell(tester, highContrast: true);
    final labels = tester
        .widget<GlassNavigationBar>(find.byType(GlassNavigationBar))
        .items
        .map((item) => item.label)
        .toList();
    for (var i = 0; i < labels.length; i++) {
      final tab = find.bySemanticsLabel('Onglet ${labels[i]}, ${i + 1} sur 5');
      expect(tab, findsOneWidget);
      final target = tester.getSize(tab);
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(labels[i]).last,
      );
      for (final box in paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: labels[i].length),
      )) {
        expect(box.left, greaterThanOrEqualTo(0), reason: labels[i]);
        expect(
          box.right,
          lessThanOrEqualTo(paragraph.size.width),
          reason: labels[i],
        );
        expect(
          box.bottom,
          lessThanOrEqualTo(paragraph.size.height),
          reason: labels[i],
        );
      }
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(find.text('Branche $i · 0'), findsOneWidget);
    }
    final chat = find.bySemanticsLabel('Chat Elyrii');
    expect(chat, findsOneWidget);
    expect(tester.getSize(chat).shortestSide, greaterThanOrEqualTo(48));
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
    final labels = tester
        .widget<GlassNavigationBar>(find.byType(GlassNavigationBar))
        .items
        .map((item) => item.label)
        .toList();
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
    await tester.tap(find.text('Méditer'));
    await tester.pumpAndSettle();
    expect(find.text('Branche 3 · 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('réduire les animations supprime le rebond du dock', (
    tester,
  ) async {
    await _pumpShell(tester, highContrast: true, reduceMotion: true);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Méditer')),
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

  for (final (width, bold) in [(375.0, false), (375.0, true), (420.0, false)]) {
    testWidgets(
      'libellés du dock à 11 pt sur une ligne, $width px, gras $bold',
      (tester) async {
        await _pumpShell(
          tester,
          textScale: 1,
          size: Size(width, 852),
          boldText: bold,
        );
        final role = AppTextStyles.dockLabel();
        final labels = tester
            .widget<GlassNavigationBar>(find.byType(GlassNavigationBar))
            .items
            .map((item) => item.label);
        for (final label in labels) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label).last,
          );
          expect(paragraph.text.style?.fontSize, role.fontSize, reason: label);
          // Le rôle v2 garde l'interligne naturel de Poppins : une seule
          // ligne reste sous deux corps de police.
          expect(
            tester.getRect(find.text(label).last).height,
            lessThan(role.fontSize! * 2),
            reason: '$label tient sur une ligne',
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          expect(
            paragraph.textSize.width,
            lessThanOrEqualTo(paragraph.size.width),
            reason: '$label n’est pas coupé',
          );
        }
      },
    );
  }

  testWidgets('dock centered inside the desktop content column', (
    tester,
  ) async {
    await _pumpShell(tester, size: const Size(1440, 900));
    final tabs = tester.getRect(find.byType(GlassNavigationBar));
    final bubble = tester.getRect(find.byType(GlassBubbleButton));
    expect(tabs.left, (1440 - AppDimensions.maxContentWidth) / 2 + 16);
    expect(bubble.right, (1440 + AppDimensions.maxContentWidth) / 2 - 16);
    expect(bubble.size, const Size(64, 64));
    expect(tabs.height, 64);
  });

  testWidgets('narrow screens and large text use the navigation selector', (
    tester,
  ) async {
    for (final (size, scale) in [
      (const Size(320, 568), 1.0),
      (const Size(390, 844), 1.5),
    ]) {
      await _pumpShell(tester, size: size, textScale: scale);
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
