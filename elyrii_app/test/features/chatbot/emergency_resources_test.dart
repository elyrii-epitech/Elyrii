import 'package:elyrii_app/core/theme/app_colors.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/chatbot/presentation/widgets/emergency_resources_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'emergency sheet is themed and scrolls with large text ($dark)',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.binding.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(
          tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const Scaffold(
              body: Center(child: EmergencyResourcesButton(compact: true)),
            ),
          ),
        );
        await tester.tap(find.byType(EmergencyResourcesButton));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester
              .widget<Material>(
                find.byKey(const ValueKey('emergency-sheet-surface')),
              )
              .color,
          dark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
        );
        expect(
          tester.widget<Text>(find.text('Besoin d’aide ?')).style?.fontFamily,
          'Poppins',
        );
        // A system appearance change must update the open route's surface too.
        tester.binding.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.light
            : Brightness.dark;
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Material>(
                find.byKey(const ValueKey('emergency-sheet-surface')),
              )
              .color,
          dark ? AppColors.scaffoldLight : AppColors.scaffoldDark,
        );
        expect(
          tester.widget<Text>(find.text('Besoin d’aide ?')).style?.color,
          dark ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        );
        await tester.ensureVisible(
          find.text('Choisis un contact pour ouvrir l’appel.'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Urgence vitale'));
        await tester.pumpAndSettle();
        expect(find.text('Urgence vitale').hitTestable(), findsOneWidget);
        await tester.tap(find.byTooltip('Fermer'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
      },
    );
  }
}
