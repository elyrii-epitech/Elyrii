import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/core/widgets/elyrii_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'));
    await loader.load();
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
        const leadingKey = Key('back');
        const trailingKey = Key('reset');
        const bodyKey = Key('body');
        const headerKey = Key('header');
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
              body: ElyriiPageFrame(
                header: ElyriiPageHeader(
                  key: headerKey,
                  title: title,
                  subtitle: 'Thèmes et accessoires d’Elyrii.',
                  leading: SizedBox(
                    key: leadingKey,
                    width: 44,
                    height: 44,
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                  trailing: SizedBox(
                    key: trailingKey,
                    width: 44,
                    height: 44,
                    child: IconButton(
                      onPressed: () => tapped = true,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
                child: ListView(
                  key: bodyKey,
                  children: List.generate(
                    30,
                    (i) => SizedBox(height: 60, child: Text('Contenu $i')),
                  ),
                ),
              ),
            ),
          ),
        );

        final titleRect = tester.getRect(find.text(title));
        final headerRect = tester.getRect(find.byKey(headerKey));
        final left = tester.getRect(find.byKey(leadingKey));
        final right = tester.getRect(find.byKey(trailingKey));
        expect(titleRect.left, greaterThanOrEqualTo(left.right));
        expect(titleRect.right, lessThanOrEqualTo(right.left));
        expect(left.center.dy, right.center.dy);
        expect(
          tester.getRect(find.byKey(bodyKey)).top,
          greaterThanOrEqualTo(headerRect.bottom),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(title),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(tester.takeException(), isNull);

        await tester.drag(find.byKey(bodyKey), const Offset(0, -250));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(headerKey)), headerRect);
        await tester.tap(find.byKey(trailingKey));
        expect(tapped, isTrue);
      });
    }
  }
}
