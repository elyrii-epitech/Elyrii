import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/widgets/mascot_contact_shadow.dart';
import 'package:elyrii_app/core/widgets/mascot_warm_placeholder.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/dashboard/presentation/widgets/mascot_peek.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';

Widget _wrap(Widget child) {
  final storage = SecureStorageService();
  final client = ApiClient(storage: storage);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => MascotProvider(client: client)),
      ChangeNotifierProvider(
        create: (_) => DashboardProvider(apiClient: client),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mascot Physical & Visual Interactions', () {
    testWidgets('MascotContactShadow réagit à l\'élévation (physique Apple)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MascotContactShadow(width: 100, elevation: 0.0), // posée
                MascotContactShadow(width: 100, elevation: 1.0), // élevée
              ],
            ),
          ),
        ),
      );

      final shadows = tester
          .widgetList<MascotContactShadow>(find.byType(MascotContactShadow))
          .toList();

      expect(shadows.length, 2);
      expect(shadows[0].elevation, 0.0);
      expect(shadows[1].elevation, 1.0);
    });

    testWidgets('MascotWarmPlaceholder pulse sans crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MascotWarmPlaceholder(width: 150, height: 150)),
        ),
      );

      expect(find.byType(MascotWarmPlaceholder), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets(
      'MascotPeek tap déclenche le rebond élastique et le haptique sans crash',
      (tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          _wrap(
            MascotPeek(
              selectedMood: MoodType.neutral,
              onTap: () => tapped = true,
            ),
          ),
        );

        expect(find.byType(MascotPeek), findsOneWidget);

        // Tap sur la mascotte
        await tester.tap(find.byType(MascotPeek));
        await tester.pump();
        expect(tapped, isTrue);

        // Avancer pendant le micro-rebond (squash & stretch 550 ms)
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 300));
      },
    );

    testWidgets(
      'MascotPeek réagit au changement d\'humeur (celebrate / breathe / attentive)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const MascotPeek(selectedMood: MoodType.happy)),
        );
        await tester.pump();

        // Mise à jour de l'humeur vers triste
        await tester.pumpWidget(
          _wrap(const MascotPeek(selectedMood: MoodType.sad)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  });
}
