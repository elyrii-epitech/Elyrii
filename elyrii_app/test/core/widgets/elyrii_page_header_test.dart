import 'dart:async';

import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/core/widgets/elyrii_page_header.dart';
import 'package:elyrii_app/core/widgets/glass/elyrii_back_button.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    await loader.load();
  });

  for (final level in ElyriiTitleLevel.values) {
    testWidgets('tirer pour actualiser déclenche le rappel, ${level.name}', (
      tester,
    ) async {
      var refreshes = 0;
      final pendingRefresh = Completer<void>();
      addTearDown(() {
        if (!pendingRefresh.isCompleted) pendingRefresh.complete();
      });
      Future<void> refresh() {
        refreshes++;
        return pendingRefresh.future;
      }

      final slivers = [const SliverToBoxAdapter(child: SizedBox(height: 1200))];
      const physics = BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: const EdgeInsets.only(top: 59)),
            child: child!,
          ),
          home: Scaffold(
            body: level == ElyriiTitleLevel.tab
                ? ElyriiPageFrame.tab(
                    title: 'Journal',
                    physics: physics,
                    slivers: slivers,
                    onRefresh: refresh,
                  )
                : ElyriiPageFrame.detail(
                    title: 'Bilan',
                    leading: ElyriiBackButton(onPressed: () {}),
                    physics: physics,
                    slivers: slivers,
                    onRefresh: refresh,
                  ),
          ),
        ),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
      await tester.pump();
      for (var frame = 0; frame < 120; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(refreshes, 1);
      final indicator = tester.getRect(
        find.byType(CupertinoActivityIndicator, skipOffstage: false),
      );
      final frameContext = tester.element(find.byType(ElyriiPageFrame));
      expect(
        indicator.top,
        greaterThanOrEqualTo(ElyriiHeaderBar.extentOf(frameContext)),
        reason:
            'L’actualisation reste visible sous la barre et la zone système.',
      );
      pendingRefresh.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final title in ['Jardin', 'Bon après-midi, Marie-Claire']) {
    testWidgets(
      'le titre sémantique reste unique pendant le défilement : $title',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: ElyriiPageFrame.tab(
                title: title,
                eyebrow: 'JEUDI 22 OCTOBRE',
                controller: controller,
                slivers: const [
                  SliverToBoxAdapter(child: SizedBox(height: 1200)),
                ],
              ),
            ),
          ),
        );
        for (final offset in [0.0, 24.0, 25.0, 300.0, 24.0, 0.0]) {
          controller.jumpTo(offset);
          await tester.pump();
          final headings = find.semantics.byLabel(title).evaluate();
          expect(headings, hasLength(1), reason: 'Défilement à $offset px');
          expect(headings.single.flagsCollection.isHeader, isTrue);
          expect(headings.single.flagsCollection.isHidden, isFalse);
        }
      },
    );
  }

  testWidgets('le titre fixe du chat est un titre sémantique accessible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: ElyriiHeaderBar(title: 'Elyrii')),
      ),
    );

    final headings = find.semantics.byLabel('Elyrii').evaluate();
    expect(headings, hasLength(1));
    expect(headings.single.flagsCollection.isHeader, isTrue);
    expect(headings.single.flagsCollection.isHidden, isFalse);
  });

  for (final title in ['Personnalisation', 'Paramètres', 'Mon avatar']) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('$title reste entre les boutons à 320 px, texte $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const trailingKey = Key('reset');
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                padding: const EdgeInsets.only(top: 24),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: ElyriiPageFrame.detail(
                title: title,
                leading: ElyriiBackButton(onPressed: () {}),
                actions: [
                  SizedBox(
                    key: trailingKey,
                    width: 48,
                    height: 48,
                    child: IconButton(
                      onPressed: () => tapped = true,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ],
                slivers: [
                  SliverList.list(
                    children: List.generate(
                      40,
                      (i) => SizedBox(height: 60, child: Text('Contenu $i')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final back = find.byTooltip('Retour');
        final titleRect = tester.getRect(find.text(title));
        final left = tester.getRect(back);
        final right = tester.getRect(find.byKey(trailingKey));
        expect(titleRect.left, greaterThanOrEqualTo(left.right));
        expect(titleRect.right, lessThanOrEqualTo(right.left));
        expect(titleRect.overlaps(left), isFalse);
        expect(titleRect.overlaps(right), isFalse);
        expect(left.center.dy, right.center.dy);
        expect(titleRect.center.dy, closeTo(left.center.dy, 1));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(title),
        );
        expect(paragraph.text.style?.fontSize, 17, reason: 'navTitle');
        expect(
          titleRect.height,
          closeTo(paragraph.size.height, 0.5),
          reason: 'a long title is truncated, never shrunk',
        );
        expect(tester.takeException(), isNull);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(tester.getRect(back), left);
        expect(left.top, greaterThanOrEqualTo(0));
        expect(left.bottom, lessThanOrEqualTo(568));
        expect(tester.getRect(find.text(title)), titleRect);
        await tester.tap(find.byKey(trailingKey));
        expect(tapped, isTrue);
      });
    }
  }

  for (final scale in [1.0, 1.3]) {
    testWidgets('les grands titres d’onglet ont la même taille, texte $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final button = SizedBox(
        width: 48,
        height: 48,
        child: IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
      );
      const greeting = 'Bon après-midi, Marie-Claire';
      final frames = {
        'Jardin': const ElyriiPageFrame.tab(title: 'Jardin', slivers: []),
        'Journal': ElyriiPageFrame.tab(
          title: 'Journal',
          actions: [button, button],
          slivers: const [],
        ),
        greeting: ElyriiPageFrame.tab(
          title: greeting,
          eyebrow: 'JEUDI 22 OCTOBRE',
          leading: button,
          actions: [button],
          slivers: const [],
        ),
      };
      final glyphHeights = <String, double>{};
      for (final MapEntry(key: title, value: frame) in frames.entries) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(body: frame),
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(title),
        );
        expect(
          tester.getRect(find.text(title)).height,
          closeTo(paragraph.size.height, 0.5),
          reason: '$title is laid out at its real size, not shrunk',
        );
        glyphHeights[title] = paragraph.textScaler.scale(
          paragraph.text.style!.fontSize!,
        );
      }
      expect(
        glyphHeights.values.toSet(),
        hasLength(1),
        reason: '$glyphHeights',
      );
      expect(glyphHeights['Jardin'], closeTo(28 * scale, 0.01));
    });
  }

  testWidgets('le contenu passé sous la barre ne reçoit pas les touchers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final taps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ElyriiPageFrame.detail(
            title: 'Paramètres',
            leading: ElyriiBackButton(onPressed: () {}),
            slivers: [
              SliverList.list(
                children: [
                  for (var i = 0; i < 30; i++)
                    SizedBox(
                      height: 60,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => taps.add(i),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('Paramètres')));
    expect(taps, isEmpty, reason: 'the bar owns taps on its title');
    await tester.tapAt(const Offset(195, 400));
    expect(taps, hasLength(1));
  });
}
