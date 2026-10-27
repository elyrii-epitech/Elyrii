import 'dart:async';

import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/gamification/data/models/gamification_models.dart';
import 'package:elyrii_app/features/gamification/data/repositories/gamification_repository.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends GamificationRepository {
  _Repository() : super(client: ApiClient(storage: SecureStorageService()));
  final history = Completer<List<UserChallenge>>();
  int loads = 0;
  @override
  Future<List<ChallengeTemplate>> getAvailableChallenges() async {
    loads++;
    return [];
  }

  @override
  Future<List<UserChallenge>> getActiveChallenges() async {
    loads++;
    return [];
  }

  @override
  Future<List<UserChallenge>> getProposals() async {
    loads++;
    return [];
  }

  @override
  Future<List<UserChallenge>> getCompletedChallenges() {
    loads++;
    return history.future;
  }
}

void main() {
  test('1000 completed challenges retain their data and concurrent loads are shared', () async {
    final repository = _Repository();
    final provider = GamificationProvider(repository: repository)
      ..onUserChanged(userId: 'alice');
    addTearDown(provider.dispose);
    final first = provider.loadAll();
    final second = provider.loadAll();
    expect(identical(first, second), isTrue);
    expect(repository.loads, 4);
    repository.history.complete(
      List.generate(
        1000,
        (index) => UserChallenge(
          id: 'challenge-$index',
          userId: 'alice',
          challengeId: 'template-$index',
          status: 'COMPLETED',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ),
    );
    await Future.wait([first, second]);
    expect(provider.completedChallenges, hasLength(1000));
    expect(provider.completedChallenges.first.id, 'challenge-0');
    expect(provider.completedChallenges.last.id, 'challenge-999');
  });
}
