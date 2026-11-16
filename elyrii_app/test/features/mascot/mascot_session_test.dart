import 'dart:async';
import 'dart:convert';

import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/mascot/data/models/mascot_appearance.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends ApiClient {
  _Client() : super(storage: SecureStorageService());
  Future<Map<String, dynamic>> Function()? read;
  final readStarted = Completer<void>();
  final writeStarted = Completer<void>();
  Completer<void>? firstWrite;
  final writes = <Map<String, dynamic>>[];
  int reads = 0;

  @override
  Future<dynamic> get(
    String url, {
    bool auth = true,
    Map<String, String>? queryParams,
  }) {
    reads++;
    if (!readStarted.isCompleted) readStarted.complete();
    return read?.call() ?? Future.value({'appearance': 'nature'});
  }

  @override
  Future<dynamic> put(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    writes.add(body!);
    if (!writeStarted.isCompleted) writeStarted.complete();
    if (writes.length == 1 && firstWrite != null) await firstWrite!.future;
    return body;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'les looks de Lucas sont normalisés et restent séparés par compte',
    () async {
      SharedPreferences.setMockInitialValues({
        'elyrii_mascot_theme_alice': 'zen',
        'elyrii_mascot_customization_alice': [
          'crown_laurel',
          'flower_mouth',
          'scarf_cozy',
        ],
        'elyrii_mascot_appearance_alice': jsonEncode({
          'colors': {'ears': '#C8E6C9'},
          'finish': 'satin',
        }),
      });
      final provider = MascotProvider(userId: 'alice');
      addTearDown(provider.dispose);
      await provider.loadMascot();
      final alice = provider.mascot;
      expect(alice.equippedCosmetics, [
        'laurel_crown',
        'cheek_sparkle',
        'cozy_scarf',
      ]);
      expect(alice.appearance.colors['ears'], '#C8E6C9');
      await provider.onUserChanged(userId: 'bob');
      expect(provider.mascot.themeId, 'nature');
      expect(provider.mascot.equippedCosmetics, isEmpty);
      await provider.saveCustomization(
        provider.mascot.copyWith(themeId: 'sakura'),
        completedChallenges: 0,
      );
      await provider.onUserChanged(userId: 'alice');
      expect(provider.mascot, alice);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('elyrii_mascot_theme_bob'), 'sakura');
      expect(
        prefs.getStringList('elyrii_mascot_customization_alice'),
        alice.equippedCosmetics,
      );
    },
  );

  for (final hasScopedLook in [false, true]) {
    test(
      'la migration historique appartient à un seul compte (cache existant : $hasScopedLook)',
      () async {
        SharedPreferences.setMockInitialValues({
          'elyrii_mascot_theme': 'cosmic',
          'elyrii_mascot_customization': ['custom1'],
          if (hasScopedLook) 'elyrii_mascot_theme_alice': 'zen',
        });
        final provider = MascotProvider();
        addTearDown(provider.dispose);
        await provider.onUserChanged(userId: 'alice', migrateLegacy: true);
        expect(provider.mascot.themeId, hasScopedLook ? 'zen' : 'cosmic');
        if (!hasScopedLook) {
          expect(provider.mascot.equippedCosmetics, ['graduate_cap']);
        }
        await provider.onUserChanged(userId: 'bob', migrateLegacy: true);
        expect(provider.mascot.themeId, 'nature');
        expect(provider.mascot.equippedCosmetics, isEmpty);
        await provider.onUserChanged();
        expect(provider.mascot.themeId, 'nature');
        expect(provider.mascot.equippedCosmetics, isEmpty);
      },
    );
  }

  test('un look local de Lucas est synchronisé avant de lire un serveur encore vierge', () async {
    SharedPreferences.setMockInitialValues({
      'elyrii_mascot_theme_alice': 'zen',
      'elyrii_mascot_customization_alice': ['crown_laurel', 'flower_mouth'],
    });
    final client = _Client();
    final provider = MascotProvider(client: client, userId: 'alice');
    addTearDown(provider.dispose);
    await provider.loadMascot();
    await provider.retrySync();
    expect(client.reads, 0);
    expect(provider.mascot.themeId, 'zen');
    expect(provider.mascot.equippedCosmetics, [
      'laurel_crown',
      'cheek_sparkle',
    ]);
    expect(client.writes.last['equippedCosmetics'], [
      'laurel_crown',
      'cheek_sparkle',
    ]);
  });

  test(
    'le mode démo et le visiteur ne lisent ni écrivent sur le serveur',
    () async {
      final client = _Client();
      final provider = MascotProvider(client: client);
      addTearDown(provider.dispose);
      await provider.loadMascot();
      await provider.onUserChanged(userId: 'demo-user', isDemo: true);
      await provider.saveCustomization(
        provider.mascot.copyWith(
          themeId: 'sakura',
          equippedCosmetics: ['custom1'],
        ),
        completedChallenges: 36,
      );
      await provider.retrySync();
      await provider.onUserChanged();
      expect(provider.mascot.themeId, 'nature');
      await provider.onUserChanged(userId: 'demo-user', isDemo: true);
      expect(provider.mascot.themeId, 'sakura');
      expect(provider.mascot.equippedCosmetics, ['graduate_cap']);
      expect(client.reads, 0);
      expect(client.writes, isEmpty);
    },
  );

  test(
    'une ancienne réponse serveur ne remplace pas le look du nouveau compte',
    () async {
      final stale = Completer<Map<String, dynamic>>();
      final client = _Client()..read = () => stale.future;
      final provider = MascotProvider(client: client);
      addTearDown(provider.dispose);
      final loadingAlice = provider.onUserChanged(userId: 'alice');
      await client.readStarted.future;
      client.read = () async => {'appearance': 'sakura'};
      await provider.onUserChanged(userId: 'bob');
      stale.complete({
        'appearance': 'zen',
        'equippedCosmetics': ['custom1'],
      });
      await loadingAlice;
      expect(provider.storageScope, 'bob');
      expect(provider.mascot.themeId, 'sakura');
      expect(provider.mascot.equippedCosmetics, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'elyrii_mascot_theme_bob',
        ),
        'sakura',
      );
    },
  );

  test(
    'les écritures en attente sont invalidées au changement de compte',
    () async {
      final client = _Client()..firstWrite = Completer<void>();
      final provider = MascotProvider(client: client, userId: 'alice');
      addTearDown(provider.dispose);
      await provider.loadMascot();
      await provider.saveCustomization(
        provider.mascot.copyWith(
          appearance: MascotAppearance(colors: const {'body': '#B8A3DC'}),
        ),
        completedChallenges: 0,
      );
      await client.writeStarted.future;
      await provider.saveCustomization(
        provider.mascot.copyWith(
          appearance: MascotAppearance(colors: const {'body': '#91C5BD'}),
        ),
        completedChallenges: 0,
      );
      client.read = () async => {'appearance': 'sakura'};
      await provider.onUserChanged(userId: 'bob');
      client.firstWrite!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(client.writes, hasLength(1));
      expect(provider.mascot.themeId, 'sakura');
      expect(provider.isSyncing, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'elyrii_mascot_pending_sync_alice',
        ),
        isTrue,
      );
      await provider.saveCustomization(
        provider.mascot.copyWith(
          appearance: MascotAppearance(colors: const {'body': '#E67E22'}),
        ),
        completedChallenges: 0,
      );
      await provider.retrySync();
      expect(
        client.writes.last['personality']['customization']['colors']['body'],
        '#E67E22',
      );
    },
  );

  test(
    'un brouillon ouvert par un ancien compte ne peut pas être enregistré',
    () async {
      final provider = MascotProvider(userId: 'alice');
      addTearDown(provider.dispose);
      await provider.loadMascot();
      final revision = provider.sessionRevision;
      final draft = provider.mascot.copyWith(themeId: 'zen');
      await provider.onUserChanged(userId: 'bob');
      expect(
        await provider.saveCustomization(
          draft,
          completedChallenges: 0,
          expectedSessionRevision: revision,
        ),
        isFalse,
      );
      expect(provider.mascot.themeId, 'nature');
    },
  );

  test('un chargement ancien ne remplace pas une sauvegarde récente du même compte', () async {
    final stale = Completer<Map<String, dynamic>>();
    final client = _Client()..read = () => stale.future;
    final provider = MascotProvider(client: client, userId: 'alice');
    addTearDown(provider.dispose);
    final loading = provider.loadMascot();
    await client.readStarted.future;
    final look = provider.mascot.copyWith(
      appearance: MascotAppearance(colors: const {'body': '#12AB9F'}),
    );
    await provider.saveCustomization(look, completedChallenges: 0);
    await provider.retrySync();
    stale.complete({'appearance': 'nature'});
    await loading;
    expect(provider.mascot, look);
  });
}
