import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/core/widgets/section_sky_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'la bande apparaît strictement après 190 et ne déplace pas le scroll',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Stack(
              children: [
                ListView(
                  controller: scroll,
                  children: const [SizedBox(height: 2000)],
                ),
                SectionSkyBar(
                  scroll: scroll,
                  title: 'Jardin',
                  trailing: IconButton(
                    tooltip: 'Période',
                    onPressed: () {},
                    icon: const Icon(Icons.calendar_month),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      double paintedOpacity() => tester
          .renderObject<RenderAnimatedOpacity>(find.byType(FadeTransition))
          .opacity
          .value;

      scroll.jumpTo(190);
      await tester.pumpAndSettle();
      expect(paintedOpacity(), 0);
      expect(find.byTooltip('Période').hitTestable(), findsOneWidget);
      scroll.jumpTo(191);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(paintedOpacity(), allOf(greaterThan(0), lessThan(1)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(paintedOpacity(), 1);
      expect(scroll.offset, 191);
      scroll.jumpTo(800);
      await tester.pumpAndSettle();
      expect(paintedOpacity(), 1);
      expect(scroll.offset, 800);
      scroll.jumpTo(190);
      await tester.pumpAndSettle();
      expect(paintedOpacity(), 0);
      expect(scroll.offset, 190);
    },
  );
}
