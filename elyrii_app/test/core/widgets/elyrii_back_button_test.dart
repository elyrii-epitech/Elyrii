import 'package:elyrii_app/core/widgets/glass/elyrii_back_button.dart';
import 'package:elyrii_app/core/widgets/glass/liquid_glass_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('design unifié : flèche iOS dans un LiquidGlassIconButton 44', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ElyriiBackButton())),
    );

    final button = tester.widget<LiquidGlassIconButton>(
      find.byType(LiquidGlassIconButton),
    );
    expect(button.icon, Icons.arrow_back_ios_new_rounded);
    expect(button.size, 44);
  });

  testWidgets('sans onPressed : tap revient à la page précédente', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Accueil'))),
      ),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: ElyriiBackButton()),
          ),
        );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElyriiBackButton));
    await tester.pumpAndSettle();

    expect(find.text('Accueil'), findsOneWidget);
    expect(find.byType(ElyriiBackButton), findsNothing);
  });

  testWidgets('avec onPressed : action personnalisée au lieu du pop', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ElyriiBackButton(onPressed: () => tapped = true)),
      ),
    );

    await tester.tap(find.byType(ElyriiBackButton));

    expect(tapped, isTrue);
  });
}
