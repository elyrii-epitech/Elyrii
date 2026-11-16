import 'dart:async';

import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/mascot/data/models/mascot_appearance.dart';
import 'package:elyrii_app/features/mascot/data/models/mascot_model.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends ApiClient {
  _Client() : super(storage: SecureStorageService());
  Map<String, dynamic> remote = {'appearance': 'nature'};
  final updates = <Map<String, dynamic>>[];
  bool failWrites = false;
  int reads = 0;
  Completer<void>? firstWrite;
  final secondWrite = Completer<void>();

  @override
  Future<dynamic> get(
    String url, {
    bool auth = true,
    Map<String, String>? queryParams,
  }) async {
    reads++;
    return remote;
  }

  @override
  Future<dynamic> put(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    updates.add(body!);
    if (updates.length == 1 && firstWrite != null) await firstWrite!.future;
    if (failWrites) throw StateError('offline');
    remote = body;
    if (updates.length >= 2 && !secondWrite.isCompleted) secondWrite.complete();
    return body;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('normalise les couleurs et ignore les champs inconnus ou invalides', () {
    final appearance = MascotAppearance.fromJson(const {
      'colors': {
        'body': '12ab9f',
        'eyes': '#3B3549',
        'details': 'invalid',
        'unknown': '#FFFFFF',
      },
      'finish': 'unknown',
    });
    expect(appearance.colors, {'body': '#12AB9F', 'eyes': '#3B3549'});
    expect(appearance.finish, MascotFinish.velours);
    expect(MascotAppearance.normalizeHex('12#AB9F'), isNull);
    expect(() => appearance.colors['body'] = '#FFFFFF', throwsUnsupportedError);
    expect(
      MascotModel.fromJson(
        MascotModel.defaultMascot().copyWith(appearance: appearance).toJson(),
      ).appearance,
      appearance,
    );
  });

  test(
    'sauvegarde et restaure les quatre zones, leurs couleurs et la matière',
    () async {
      final client = _Client();
      final provider = MascotProvider(client: client, userId: 'user');
      await provider.loadMascot();
      final look = provider.mascot.copyWith(
        equippedCosmetics: [
          'beret',
          'round_glasses',
          'cozy_scarf',
          'mini_backpack',
        ],
        appearance: MascotAppearance(
          colors: const {
            'body': '#B8A3DC',
            'details': '#FFFFFF',
            'ears': '#F2CE94',
            'eyes': '#3B3549',
            'accessories': '#91C5BD',
          },
          finish: MascotFinish.satin,
        ),
      );
      expect(
        await provider.saveCustomization(look, completedChallenges: 36),
        isTrue,
      );
      await provider.retrySync();
      expect(
        client.updates.last['personality']['customization'],
        look.appearance.toJson(),
      );
      final restored = MascotProvider(userId: 'user');
      await restored.loadMascot();
      expect(restored.mascot, look);
      provider.dispose();
      restored.dispose();
    },
  );

  test('un brouillon contenant une récompense verrouillée ne modifie pas le look enregistré', () async {
    final client = _Client();
    final provider = MascotProvider(client: client, userId: 'user');
    await provider.loadMascot();
    final saved = provider.mascot;
    expect(
      await provider.saveCustomization(
        saved.copyWith(equippedCosmetics: ['mini_backpack']),
        completedChallenges: 2,
      ),
      isFalse,
    );
    expect(provider.mascot, saved);
    expect(client.updates, isEmpty);
    provider.dispose();
  });

  for (final failsWithException in [false, true]) {
    test(
      'a failed studio finalization restores a removed locked reward (exception: $failsWithException)',
      () async {
        final client = _Client()
          ..remote = {
            'appearance': 'nature',
            'equippedCosmetics': ['beret', 'cheek_sparkle'],
          };
        final provider = MascotProvider(client: client, userId: 'user');
        addTearDown(provider.dispose);
        await provider.loadMascot();
        final original = provider.mascot;
        final started = Completer<void>();
        final decision = Completer<bool>();
        final saving = provider.saveCustomization(
          original.copyWith(equippedCosmetics: ['cheek_sparkle']),
          completedChallenges: 0,
          finalize: () {
            started.complete();
            return decision.future;
          },
        );
        await started.future;
        final retrying = provider.retrySync();
        await Future<void>.delayed(Duration.zero);
        expect(client.updates, isEmpty);
        if (failsWithException) {
          decision.completeError(StateError('decor unavailable'));
        } else {
          decision.complete(false);
        }
        expect(await saving, isFalse);
        await retrying;
        await provider.flushed;
        expect(provider.mascot, original);
        expect(client.updates, isNotEmpty);
        expect(
          client.updates.every(
            (body) => (body['equippedCosmetics'] as List).contains('beret'),
          ),
          isTrue,
        );
        final restored = MascotProvider(userId: 'user');
        addTearDown(restored.dispose);
        await restored.loadMascot();
        expect(restored.mascot, original);
        // Restoration does not authorize selecting another locked reward.
        expect(
          await provider.saveCustomization(
            original.copyWith(equippedCosmetics: ['mini_backpack']),
            completedChallenges: 0,
          ),
          isFalse,
        );
      },
    );
  }

  test('a studio look is uploaded only after finalization succeeds', () async {
    final client = _Client()
      ..remote = {
        'appearance': 'nature',
        'equippedCosmetics': ['beret'],
      };
    final provider = MascotProvider(client: client, userId: 'user');
    addTearDown(provider.dispose);
    await provider.loadMascot();
    final draft = provider.mascot.copyWith(equippedCosmetics: []);
    final started = Completer<void>();
    final decision = Completer<bool>();
    final saving = provider.saveCustomization(
      draft,
      completedChallenges: 0,
      finalize: () {
        started.complete();
        return decision.future;
      },
    );
    await started.future;
    expect(client.updates, isEmpty);
    decision.complete(true);
    expect(await saving, isTrue);
    await provider.flushed;
    expect(provider.mascot, draft);
    expect(client.updates.single['equippedCosmetics'], isEmpty);
    final restored = MascotProvider(userId: 'user');
    addTearDown(restored.dispose);
    await restored.loadMascot();
    expect(restored.mascot, draft);
  });

  test('a late failed finalization does not replace a newer look', () async {
    final provider = MascotProvider(userId: 'user');
    addTearDown(provider.dispose);
    await provider.loadMascot();
    await provider.flushed;
    final started = Completer<void>();
    final decision = Completer<bool>();
    final saving = provider.saveCustomization(
      provider.mascot.copyWith(themeId: 'zen'),
      completedChallenges: 0,
      finalize: () {
        started.complete();
        return decision.future;
      },
    );
    await started.future;
    final latest = provider.mascot.copyWith(themeId: 'sakura');
    expect(
      await provider.saveCustomization(latest, completedChallenges: 0),
      isFalse,
      reason: 'A second studio transaction cannot capture an unconfirmed look',
    );
    provider.setTheme('sakura');
    decision.complete(false);
    expect(await saving, isFalse);
    await provider.flushed;
    expect(provider.mascot, latest);
    final restored = MascotProvider(userId: 'user');
    addTearDown(restored.dispose);
    await restored.loadMascot();
    expect(restored.mascot, latest);
  });

  test(
    'an old studio finalization cannot delay or restore into a new account',
    () async {
      final client = _Client()
        ..remote = {
          'appearance': 'nature',
          'equippedCosmetics': ['beret'],
        };
      final provider = MascotProvider(client: client, userId: 'alice');
      addTearDown(provider.dispose);
      await provider.loadMascot();
      final started = Completer<void>();
      final decision = Completer<bool>();
      final saving = provider.saveCustomization(
        provider.mascot.copyWith(equippedCosmetics: []),
        completedChallenges: 0,
        finalize: () {
          started.complete();
          return decision.future;
        },
      );
      await started.future;
      client.remote = {'appearance': 'sakura'};
      await provider.onUserChanged(userId: 'bob');
      final bob = provider.mascot.copyWith(themeId: 'zen');
      await provider.saveCustomization(bob, completedChallenges: 0);
      await provider.flushed;
      expect(client.updates.single['appearance'], 'zen');
      decision.complete(false);
      expect(await saving, isFalse);
      await provider.flushed;
      expect(provider.storageScope, 'bob');
      expect(provider.mascot, bob);
      final restored = MascotProvider(userId: 'bob');
      addTearDown(restored.dispose);
      await restored.loadMascot();
      expect(restored.mascot, bob);
      expect(client.updates, hasLength(1));
    },
  );

  test(
    'un look hors ligne survit à un ancien état serveur puis se synchronise',
    () async {
      final client = _Client()..failWrites = true;
      final provider = MascotProvider(client: client, userId: 'user');
      await provider.loadMascot();
      final look = provider.mascot.copyWith(
        appearance: MascotAppearance(colors: const {'body': '#12AB9F'}),
      );
      expect(
        await provider.saveCustomization(look, completedChallenges: 0),
        isTrue,
      );
      await provider.retrySync();
      final reads = client.reads;
      final restored = MascotProvider(client: client, userId: 'user');
      await restored.loadMascot();
      expect(restored.mascot.appearance, look.appearance);
      expect(
        client.reads,
        reads,
        reason:
            'Le serveur ancien ne doit pas écraser un look local en attente.',
      );
      client.failWrites = false;
      await restored.retrySync();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('elyrii_mascot_pending_sync_user'), isFalse);
      expect(
        client.remote['personality']['customization'],
        look.appearance.toJson(),
      );
      provider.dispose();
      restored.dispose();
    },
  );

  test(
    'les écritures serveur gardent leur ordre quand le premier look est lent',
    () async {
      final client = _Client()..firstWrite = Completer<void>();
      final provider = MascotProvider(client: client, userId: 'user');
      await provider.loadMascot();
      final first = provider.mascot.copyWith(
        appearance: MascotAppearance(colors: const {'body': '#B8A3DC'}),
      );
      await provider.saveCustomization(first, completedChallenges: 0);
      await Future<void>.delayed(Duration.zero);
      final latest = first.copyWith(
        appearance: MascotAppearance(colors: const {'body': '#91C5BD'}),
      );
      await provider.saveCustomization(latest, completedChallenges: 0);
      expect(client.updates, hasLength(1));
      client.firstWrite!.complete();
      await client.secondWrite.future;
      expect(
        client.updates.map(
          (body) => body['personality']['customization']['colors']['body'],
        ),
        ['#B8A3DC', '#91C5BD'],
      );
      expect(
        client.remote['personality']['customization'],
        latest.appearance.toJson(),
      );
      await Future<void>.delayed(Duration.zero);
      provider.dispose();
    },
  );
}
