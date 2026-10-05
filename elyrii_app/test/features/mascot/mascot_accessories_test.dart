import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/mascot/data/models/mascot_accessory.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _selectionKey = 'elyrii_mascot_customization_guest';

class _MascotClient extends ApiClient {
  final Map<String, dynamic> response;
  final updates = <Map<String, dynamic>?>[];

  _MascotClient(this.response) : super(storage: SecureStorageService());

  @override
  Future<dynamic> get(
    String url, {
    bool auth = true,
    Map<String, String>? queryParams,
  }) async => response;

  @override
  Future<dynamic> put(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    updates.add(body);
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'garde-robe : les quinze pièces et les anciens identifiants sont conservés',
    () {
      expect(MascotAccessories.all.length, 15);
      expect(MascotAccessories.all.map((a) => a.id).toSet().length, 15);
      expect(MascotAccessories.byId('custom1')?.id, 'graduate_cap');
      expect(MascotAccessories.progression.map((a) => a.requiredChallenges), [
        1,
        2,
        3,
        3,
        4,
        5,
        7,
        9,
        12,
        15,
        18,
        22,
        26,
        30,
        36,
      ]);
    },
  );

  test(
    'les pièces inconnues et verrouillées ne sont pas équipées ni synchronisées',
    () async {
      final client = _MascotClient({});
      final provider = MascotProvider(client: client, userId: 'user');
      await provider.loadMascot();
      var notifications = 0;
      provider.addListener(() => notifications++);

      expect(provider.equipCosmetic('beret', completedChallenges: 1), isFalse);
      expect(
        provider.equipCosmetic('unknown', completedChallenges: 100),
        isFalse,
      );
      expect(
        provider.equipCosmetic('custom1', completedChallenges: 0),
        isFalse,
      );
      expect(provider.mascot.equippedCosmetics, isEmpty);
      expect(client.updates, isEmpty);
      expect(notifications, 0);
      provider.dispose();
    },
  );

  test(
    'le palier exact équipe, remplace la pièce portée et permet de la retirer',
    () async {
      final provider = MascotProvider();
      await provider.loadMascot();

      expect(provider.equipCosmetic('beret', completedChallenges: 2), isTrue);
      expect(provider.mascot.equippedCosmetics, ['beret']);
      expect(provider.equipCosmetic('beanie', completedChallenges: 3), isTrue);
      expect(provider.mascot.equippedCosmetics, ['beanie']);
      expect(provider.equipCosmetic('beanie', completedChallenges: 3), isTrue);
      expect(provider.mascot.equippedCosmetics, isEmpty);
      await Future<void>.delayed(Duration.zero);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getStringList(_selectionKey), isEmpty);
      provider.dispose();
    },
  );

  test(
    'rééquiper depuis la célébration ne retire pas la pièce portée',
    () async {
      final provider = MascotProvider();
      await provider.loadMascot();
      provider.equipCosmetic('beanie', completedChallenges: 3);

      expect(
        provider.equipCosmetic(
          'beanie',
          completedChallenges: 3,
          toggleIfEquipped: false,
        ),
        isFalse,
      );
      expect(provider.mascot.equippedCosmetics, ['beanie']);
      await Future<void>.delayed(Duration.zero);
      provider.dispose();
    },
  );

  test('le chapeau historique de Lucas retrouve le modèle intégré', () async {
    SharedPreferences.setMockInitialValues({
      _selectionKey: ['custom1'],
    });
    final provider = MascotProvider();
    await provider.loadMascot();
    expect(provider.mascot.equippedCosmetics, ['graduate_cap']);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList(_selectionKey), ['graduate_cap']);
    provider.dispose();
  });

  test(
    'la sauvegarde historique conserve la dernière pièce de chaque zone',
    () async {
      SharedPreferences.setMockInitialValues({
        _selectionKey: ['custom1', 'beret'],
      });
      final provider = MascotProvider();
      await provider.loadMascot();
      expect(provider.mascot.equippedCosmetics, ['beret']);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getStringList(_selectionKey), ['beret']);
      expect(
        () => provider.mascot.equippedCosmetics.add('beanie'),
        throwsUnsupportedError,
      );
      provider.dispose();
    },
  );

  test('une nouvelle pièce est sauvegardée et restaurée', () async {
    final provider = MascotProvider();
    await provider.loadMascot();
    provider.equipCosmetic('mini_backpack', completedChallenges: 36);
    await Future<void>.delayed(Duration.zero);

    final restored = MascotProvider();
    await restored.loadMascot();
    expect(restored.mascot.equippedCosmetics, ['mini_backpack']);
    provider.dispose();
    restored.dispose();
  });

  test(
    'une réponse serveur invalide garde une pièce reconnue par zone',
    () async {
      final client = _MascotClient({
        'appearance': 'nature',
        'personality': {
          'equippedCosmetics': [
            null,
            42,
            'retired_piece',
            'custom1',
            'round_glasses',
            'beanie',
          ],
        },
      });
      final provider = MascotProvider(client: client, userId: 'user');
      await provider.loadMascot();
      expect(provider.mascot.equippedCosmetics, ['beanie', 'round_glasses']);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getStringList('elyrii_mascot_customization_user'), [
        'beanie',
        'round_glasses',
      ]);
      provider.setTheme('halloween');
      await Future<void>.delayed(Duration.zero);
      expect(client.updates.single?['equippedCosmetics'], [
        'beanie',
        'round_glasses',
      ]);
      provider.dispose();
    },
  );
}
