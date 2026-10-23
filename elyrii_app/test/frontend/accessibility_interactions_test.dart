import 'package:flutter/material.dart';

import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/features/chatbot/presentation/widgets/ai_report_sheet.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/core/theme/app_colors.dart';
import 'package:elyrii_app/core/widgets/accessible_action.dart';
import 'package:elyrii_app/core/widgets/glass/liquid_glass_dialog.dart';
import 'package:elyrii_app/features/profile_setup/presentation/widgets/profile_controls.dart';
import 'package:elyrii_app/features/auth/presentation/widgets/arrival_widgets.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Poppins')
          ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf')))
        .load();
  });
  testWidgets(
    'AI report motives remain named and selectable at 300 percent and sending announces acknowledgment',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = ApiClient(
        storage: SecureStorageService(),
        client: MockClient(
          (_) async => http.Response('{"id":"fixture-report"}', 201),
        ),
      );
      try {
        await tester.pumpWidget(
          Provider<ApiClient>.value(
            value: api,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (_, child) => MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.linear(3),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: Scaffold(
                body: AiReportSheet(
                  message: ChatMessage(
                    id: '00000000-0000-4000-8000-000000000001',
                    isUser: false,
                    content: 'Selected synthetic reply',
                    timestamp: DateTime.utc(2026, 10, 10),
                  ),
                  conversationId: 'fixture-conversation',
                ),
              ),
            ),
          ),
        );
        await tester.scrollUntilVisible(
          find.text('Information inexacte'),
          180,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Information inexacte'));
        await tester.pump();
        expect(
          tester
              .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
              .groupValue,
          'INACCURATE',
        );
        await tester.scrollUntilVisible(
          find.text('Envoyer le signalement'),
          180,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Envoyer le signalement'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Signalement enregistré pour examen'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        api.dispose();
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'keyboard focus is visible, activation works and disabled actions are skipped',
    (tester) async {
      var count = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AccessibleAction(
                    label: 'Valider',
                    onPressed: () => count++,
                    child: const Text('Valider'),
                  ),
                  const AccessibleAction(
                    label: 'Indisponible',
                    onPressed: null,
                    child: Text('Indisponible'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              ((widget.decoration as BoxDecoration).boxShadow?.length ?? 0) ==
                  2,
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(count, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(count, 2);
    },
  );
  test('status ink stays readable across canvas, cards and both themes', () {
    for (final dark in [false, true]) {
      for (final color in [
        AppColors.successText(dark),
        AppColors.errorText(dark),
        AppColors.primaryText(dark),
        AppColors.controlOutline(dark),
      ]) {
        // surface-2 sombre est translucide : on mesure la carte rendue,
        // composée au-dessus du fond de page.
        for (final background
            in dark
                ? [
                    Color.alphaBlend(
                      AppColors.cardDark,
                      AppColors.scaffoldDark,
                    ),
                    AppColors.scaffoldDark,
                  ]
                : [AppColors.cardLight, AppColors.scaffoldLight]) {
          final a = color.computeLuminance();
          final b = background.computeLuminance();
          expect(
            (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05)),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    }
  });
  testWidgets(
    'email and password expose persistent names, autofill, validation and a named toggle',
    (tester) async {
      final semantics = tester.ensureSemantics();

      final email = TextEditingController();
      final password = TextEditingController();
      addTearDown(email.dispose);
      addTearDown(password.dispose);
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Form(
              key: form,
              child: Column(
                children: [
                  ArrivalField(
                    controller: email,
                    label: 'Adresse email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (_) => 'Entre une adresse email valide.',
                  ),
                  ArrivalField(
                    controller: password,
                    label: 'Mot de passe',
                    icon: Icons.lock_outline_rounded,
                    password: true,
                    autofillHints: const [AutofillHints.password],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final fields = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();
      expect(fields[0].autofillHints, [AutofillHints.email]);
      expect(fields[1].autofillHints, [AutofillHints.password]);
      final node = tester.getSemantics(find.byType(EditableText).first);
      expect(node.getSemanticsData().label, contains('Adresse email'));
      expect(node.getSemanticsData().flagsCollection.isTextField, isTrue);
      await tester.enterText(find.byType(TextField).last, 'une phrase secrète');
      expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isTrue,
      );
      await tester.tap(find.byTooltip('Afficher le mot de passe'));
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isFalse,
      );
      expect(find.byTooltip('Masquer le mot de passe'), findsOneWidget);
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Entre une adresse email valide.'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byType(EditableText).first)
            .getSemanticsData()
            .label,
        contains('Adresse email'),
      );
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
    },
  );
  testWidgets(
    'card context and a nested action remain separately available to assistive technology',
    (tester) async {
      final semantics = tester.ensureSemantics();

      var outer = 0;
      var report = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleAction(
              label: 'Ouvrir la note',
              onPressed: () => outer++,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Réflexion du 10 octobre. Humeur : content.'),
                  TextButton(
                    onPressed: () => report++,
                    child: const Text('Signaler'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Ouvrir la note'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Réflexion du 10 octobre. Humeur : content.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Signaler'));
      expect(report, 1);
      expect(outer, 0);
      semantics.dispose();
    },
  );
  testWidgets(
    'segments and switches announce selection and expose named targets',
    (tester) async {
      final semantics = tester.ensureSemantics();

      var selected = 'a';
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  ProfileSegments<String>(
                    options: const {
                      'a': 'Première option',
                      'b': 'Deuxième option',
                    },
                    selected: selected,
                    onChanged: (v) => setState(() => selected = v),
                  ),
                  MergeSemantics(
                    child: Row(
                      children: [
                        const Text('Vibrations'),
                        ProfileToggle(
                          label: 'Vibrations',
                          value: value,
                          onChanged: (v) => setState(() => value = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Deuxième option'));
      await tester.pump();
      expect(selected, 'b');
      expect(
        tester
                .getSemantics(find.text('Deuxième option'))
                .getSemanticsData()
                .flagsCollection
                .isSelected ==
            Tristate.isTrue,
        isTrue,
      );
      await tester.tap(find.byType(ProfileToggle));
      await tester.pump();
      expect(value, isTrue);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    },
  );
  testWidgets(
    'dialog content remains scrollable at 300 percent and keyboard dismissal restores the page',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(3),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLiquidGlassDialog<void>(
                  context: context,
                  title: 'Confirmer les modifications',
                  child: Text(
                    List.filled(
                      8,
                      'Voici un texte qui doit rester accessible sans réduire la taille des caractères.',
                    ).join(' '),
                  ),
                  actions: [
                    LiquidGlassDialogAction(
                      label: 'Annuler',
                      onPressed: () => Navigator.pop(context),
                    ),
                    LiquidGlassDialogAction(
                      label: 'Enregistrer les modifications',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final scroll = find.descendant(
        of: find.byType(LiquidGlassDialogContent),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroll, findsOneWidget);
      await tester.drag(scroll, const Offset(0, -1600));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidGlassDialogContent), findsNothing);
    },
  );
}
