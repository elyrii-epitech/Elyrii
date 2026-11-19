import 'package:flutter_test/flutter_test.dart';
import 'package:elyrii_app/core/design_system/haptics/elyrii_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ElyriiHaptics', () {
    tearDown(() {
      ElyriiHaptics.setEnabled(true);
    });

    test('activé par défaut', () {
      expect(ElyriiHaptics.isEnabled, isTrue);
    });

    test('désactivation globale respectée', () {
      ElyriiHaptics.setEnabled(false);
      expect(ElyriiHaptics.isEnabled, isFalse);
    });

    test('réactivation fonctionne', () {
      ElyriiHaptics.setEnabled(false);
      expect(ElyriiHaptics.isEnabled, isFalse);

      ElyriiHaptics.setEnabled(true);
      expect(ElyriiHaptics.isEnabled, isTrue);
    });
  });
}
