import 'package:elyrii_app/core/config/dev_session.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/mascot/presentation/widgets/accessory_card.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Mode Dev grants enough défis to unlock every accessory and jardin level 5', () {
    expect(
      DevSession.completedChallengeCount,
      greaterThanOrEqualTo(MascotAccessories.maxRequiredChallenges),
    );
    expect(DevSession.jardinLevel, 5);
    expect(1 + (DevSession.completedChallengeCount ~/ 3), DevSession.jardinLevel);
  });

  test('GamificationProvider seeds completed défis in Mode Dev', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = ApiClient(storage: SecureStorageService());
    final provider = GamificationProvider(
      client: client,
      isDemoSession: () => true,
    );

    await provider.loadAll();

    expect(
      provider.completedChallenges.length,
      DevSession.completedChallengeCount,
    );
    expect(provider.error, isNull);
    expect(provider.isLoading, isFalse);
    expect(
      provider.completedChallenges.every((challenge) => challenge.isCompleted),
      isTrue,
    );
  });
}
