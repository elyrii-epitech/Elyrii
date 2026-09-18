import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'compact chat keeps a single input surface and clears keyboard (${dark ? "dark" : "light"})',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final provider = ChatbotProvider(storage: SecureStorageService());
        addTearDown(provider.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp(
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              home: const ChatbotPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final input = find.byType(TextField);
        final decoration = tester.widget<TextField>(input).decoration!;
        expect(decoration.filled, isFalse);
        expect(decoration.enabledBorder, InputBorder.none);
        expect(decoration.focusedBorder, InputBorder.none);
        final composer = find.byKey(const ValueKey('chat-composer'));
        final singleLineHeight = tester.getSize(composer).height;
        expect(singleLineHeight, lessThanOrEqualTo(60));

        await tester.tap(find.text('Ma journée'));
        await tester.pumpAndSettle();
        expect(provider.messages, isEmpty);
        expect(
          tester.widget<TextField>(input).controller!.text,
          'J’aimerais parler de ma journée',
        );

        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.enterText(
          input,
          'Une première ligne\nUne deuxième ligne\nUne troisième ligne',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(composer).height, greaterThan(singleLineHeight));
        expect(tester.getBottomRight(composer).dy, closeTo(568 - 260 - 8, 1));
        expect(find.text('Ma journée'), findsNothing);
        await tester.enterText(
          input,
          'Test du mot suicide\nLigne 2\nLigne 3\nLigne 4\nLigne 5',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getBottomRight(composer).dy, closeTo(568 - 260 - 8, 1));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
