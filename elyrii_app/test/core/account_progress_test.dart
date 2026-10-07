import 'dart:async';

import 'package:elyrii_app/core/network/api_exception.dart';

import 'package:elyrii_app/core/config/dev_session.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/dashboard/data/models/dashboard_models.dart';
import 'package:elyrii_app/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/gamification/data/models/gamification_models.dart';
import 'package:elyrii_app/features/gamification/data/repositories/gamification_repository.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/mascot/data/models/mascot_accessory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends ApiClient {
  _Client() : super(storage: SecureStorageService());
  bool offline = false;
  @override
  Future<dynamic> get(
    String url, {
    bool auth = true,
    Map<String, String>? queryParams,
  }) async {
    if (offline) {
      throw const ApiException(
        statusCode: 0,
        message: 'offline',
        kind: ApiFailureKind.offline,
      );
    }
    return {
      'stats': {'completedChallengesCount': 4, 'totalPoints': 200},
    };
  }
}

class _Challenges extends GamificationRepository {
  _Challenges() : super(client: _Client());
  int calls = 0;
  Future<List<UserChallenge>>? completed;
  @override
  Future<List<ChallengeTemplate>> getAvailableChallenges() async {
    calls++;
    return [];
  }

  @override
  Future<List<UserChallenge>> getActiveChallenges() async {
    calls++;
    return [];
  }

  @override
  Future<List<UserChallenge>> getProposals() async {
    calls++;
    return [];
  }

  @override
  Future<List<UserChallenge>> getCompletedChallenges() {
    calls++;
    return completed ?? Future.value([]);
  }
}

class _Dashboard extends DashboardRepository {
  _Dashboard() : super(client: _Client());
  int reads = 0;
  int moodWrites = 0;
  Future<DashboardData>? response;
  @override
  Future<DashboardData> getDashboard({String range = '30d'}) {
    reads++;
    return response ??
        Future.value(
          DashboardData.fromJson({
            'stats': {'completedChallengesCount': 4, 'totalPoints': 200},
          }),
        );
  }

  @override
  Future<void> logMood(String moodType) async {
    moodWrites++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('la démo débloque la collection localement et un vrai compte garde sa progression', () async {
    final repository = _Challenges();
    final provider = GamificationProvider(repository: repository);
    addTearDown(provider.dispose);
    provider.onUserChanged(userId: DevSession.userId, isDemo: true);
    await provider.loadAll();
    expect(
      provider.completedChallenges,
      hasLength(DevSession.completedChallengeCount),
    );
    expect(
      MascotAccessories.all.every(
        (piece) => piece.isUnlocked(provider.completedChallenges.length),
      ),
      isTrue,
    );
    expect(repository.calls, 0);
    provider.onUserChanged(userId: 'bob');
    await provider.loadAll();
    expect(provider.completedChallenges, isEmpty);
    expect(repository.calls, 4);
  });

  test('une réponse de défis ancienne ne remplace pas la progression du nouveau compte', () async {
    final stale = Completer<List<UserChallenge>>();
    final repository = _Challenges()..completed = stale.future;
    final provider = GamificationProvider(repository: repository);
    addTearDown(provider.dispose);
    provider.onUserChanged(userId: 'alice');
    final loading = provider.loadAll();
    provider.onUserChanged(userId: DevSession.userId, isDemo: true);
    await provider.loadAll();
    stale.complete([]);
    await loading;
    expect(
      provider.completedChallenges,
      hasLength(DevSession.completedChallengeCount),
    );
    expect(provider.isLoading, isFalse);
  });

  test(
    'le dashboard de démonstration reste local, cohérent et réinitialisable',
    () async {
      var demo = true;
      final repository = _Dashboard();
      final provider = DashboardProvider(
        repository: repository,
        isDemoSession: () => demo,
      );
      addTearDown(provider.dispose);
      provider.onUserChanged(userId: DevSession.userId, isDemo: true);
      await provider.loadDashboardData();
      await provider.selectMood(MoodType.happy);
      expect(
        provider.completedChallengesCount,
        DevSession.completedChallengeCount,
      );
      expect(provider.totalPoints, DevSession.totalPoints);
      expect(repository.reads, 0);
      expect(repository.moodWrites, 0);
      demo = false;
      provider.onUserChanged(userId: 'bob');
      expect(provider.selectedMood, isNull);
      expect(provider.moodHistory, isEmpty);
      expect(provider.completedChallengesCount, 0);
      await provider.loadDashboardData();
      expect(provider.completedChallengesCount, 4);
      expect(provider.totalPoints, 200);
    },
  );

  test(
    'un ancien dashboard ne remplace pas les statistiques du compte actif',
    () async {
      var demo = false;
      final stale = Completer<DashboardData>();
      final repository = _Dashboard()..response = stale.future;
      final provider = DashboardProvider(
        repository: repository,
        isDemoSession: () => demo,
      );
      addTearDown(provider.dispose);
      provider.onUserChanged(userId: 'alice');
      final loading = provider.loadDashboardData();
      demo = true;
      provider.onUserChanged(userId: DevSession.userId, isDemo: true);
      await provider.loadDashboardData();
      stale.complete(
        DashboardData.fromJson({
          'latestMood': 'sad',
          'stats': {'completedChallengesCount': 1},
        }),
      );
      await loading;
      expect(
        provider.completedChallengesCount,
        DevSession.completedChallengeCount,
      );
      expect(provider.selectedMood, isNull);
      expect(provider.isLoading, isFalse);
    },
  );

  test('le cache du dashboard hors ligne est isolé par compte', () async {
    final client = _Client();
    final repository = DashboardRepository(client: client);
    repository.onUserChanged(userId: 'alice');
    await repository.getDashboard();
    await Future<void>.delayed(Duration.zero);
    client.offline = true;
    repository.onUserChanged(userId: 'bob');
    expect(repository.getDashboard(), throwsA(isA<ApiException>()));
    repository.onUserChanged(userId: 'alice');
    expect((await repository.getDashboard()).stats.completedChallengesCount, 4);
  });
}
