import 'package:elyrii_app/core/config/mascot_3d_config.dart';
import 'package:elyrii_app/core/widgets/mascot_3d_viewer.dart';
import 'package:elyrii_app/core/widgets/mascot_with_accessories.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('switches fitted accessories in the same animated scene', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final provider = MascotProvider();
    await provider.loadMascot();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: MascotWithAccessories(
            config: Mascot3DConfig(),
            width: 200,
            height: 250,
          ),
        ),
      ),
    );
    final sceneState = tester.state(find.byType(Mascot3DViewer));
    Mascot3DViewer viewer() => tester.widget(find.byType(Mascot3DViewer));
    expect(viewer().accessoryVariant, isNull);
    expect(viewer().config.assetPath, 'assets/optimized/mascot_wardrobe.glb');

    provider.equipCosmetic('round_glasses', completedChallenges: 36);
    await tester.pump();
    expect(viewer().accessoryVariant, 'round_glasses');
    expect(tester.state(find.byType(Mascot3DViewer)), same(sceneState));

    provider.equipCosmetic('cozy_scarf', completedChallenges: 36);
    await tester.pump();
    expect(viewer().accessoryVariant, 'cozy_scarf');
    expect(viewer().config.assetPath, 'assets/optimized/mascot_wardrobe.glb');
    expect(tester.state(find.byType(Mascot3DViewer)), same(sceneState));

    provider.equipCosmetic('cozy_scarf', completedChallenges: 36);
    await tester.pump();
    expect(viewer().accessoryVariant, isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
