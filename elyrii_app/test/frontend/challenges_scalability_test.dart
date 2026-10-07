import 'dart:async';

import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/gamification/data/models/gamification_models.dart';
import 'package:elyrii_app/features/gamification/data/repositories/gamification_repository.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/gamification/presentation/widgets/challenge_sections.dart';
import 'package:elyrii_app/features/gamification/presentation/widgets/quest_tile.dart';
import 'package:flutter/material.dart';
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
  testWidgets(
    '1000 completed challenges stay lazy and concurrent loads are shared',
    (tester) async {
      final repository = _Repository();
      final provider = GamificationProvider(repository: repository)
        ..onUserChanged(userId: 'alice');
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
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [ChallengeHistorySliver(provider: provider)],
            ),
          ),
        ),
      );
      expect(find.byType(QuestTile).evaluate().length, lessThan(20));
      expect(find.byKey(const ValueKey('challenge-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('challenge-999')), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.byType(QuestTile).evaluate().length, lessThan(25));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    },
  );
}
