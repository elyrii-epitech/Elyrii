import 'dart:convert';

import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/network/api_exception.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/gamification/data/models/gamification_models.dart';
import 'package:elyrii_app/features/gamification/data/repositories/gamification_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String?> getUserId() async => 'owner';
  @override
  Future<String?> getAccessToken() async => 'fixture';
}

Map<String, dynamic> row(String id, {String user = 'owner'}) => {
  'id': id,
  'userId': user,
  'challengeId': 'template',
  'status': 'COMPLETED',
  'createdAt': '2026-01-10T12:00:00.123Z',
  'updatedAt': '2026-01-10T12:00:00.123Z',
  'completedAt': '2026-01-10T12:00:00.123Z',
  'progress': {},
  'challenge': {
    'id': 'template',
    'title': 'Une fleur',
    'source': 'SYSTEM',
    'rewardPoints': 25,
    'conditions': [],
    'aggregator': 'ALL',
    'createdAt': '2026-01-10T12:00:00.123Z',
    'updatedAt': '2026-01-10T12:00:00.123Z',
  },
};
void main() {
  test('the repository follows bounded pages without truncating older garden records', () async {
    final queries = <Map<String, String>>[];
    final rows = List.generate(
      125,
      (i) => row('id-${(124 - i).toString().padLeft(3, '0')}'),
    );
    final api = ApiClient(
      storage: _Storage(),
      client: MockClient((request) async {
        queries.add(request.url.queryParameters);
        final first = queries.length == 1;
        return http.Response(
          jsonEncode({
            'items': first ? rows.take(100).toList() : rows.skip(100).toList(),
            'nextCursor': first
                ? {'id': rows[99]['id'], 'createdAt': rows[99]['createdAt']}
                : null,
          }),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    final result = await GamificationRepository(client: api)
        .getCompletedChallenges();
    expect(result, hasLength(125));
    expect(result.map((item) => item.id).toSet(), hasLength(125));
    expect(result.every((item) => item.displayTitle == 'Une fleur'), isTrue);
    expect(queries.first['pageSize'], '100');
    expect(queries.last['cursorId'], rows[99]['id']);
  });

  test(
    'another owner and repeated page cursors are rejected as protocol failures',
    () async {
      var wrongOwner = true;
      final api = ApiClient(
        storage: _Storage(),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'items': [
                row('one', user: wrongOwner ? 'another-owner' : 'owner'),
              ],
              'nextCursor': {
                'id': 'one',
                'createdAt': '2026-01-10T12:00:00.123Z',
              },
            }),
            200,
          ),
        ),
      );
      addTearDown(api.dispose);
      final repository = GamificationRepository(client: api);
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          repository.getCompletedChallenges(),
          throwsA(
            isA<ApiException>().having(
              (error) => error.kind,
              'kind',
              ApiFailureKind.protocol,
            ),
          ),
        );
        wrongOwner = false;
      }
    },
  );

  test('ANY progress uses the best condition and completed challenges show full progress', () {
    final now = DateTime.utc(2026);
    ChallengeTemplate template(String aggregator) => ChallengeTemplate(
      id: 'template',
      title: 'Test',
      source: 'AI',
      rewardPoints: 25,
      aggregator: aggregator,
      createdAt: now,
      updatedAt: now,
    );
    UserChallenge challenge(String aggregator, {String status = 'ACTIVE'}) =>
        UserChallenge(
          id: 'one',
          userId: 'owner',
          challengeId: 'template',
          status: status,
          createdAt: now,
          updatedAt: now,
          template: template(aggregator),
          progress: {
            'condition_0': {'current': 1, 'target': 2, 'completed': false},
            'condition_1': {'current': 1, 'target': 10, 'completed': false},
          },
        );
    expect(challenge('ANY').progressFraction, .5);
    expect(challenge('ALL').progressFraction, closeTo(.3, .0001));
    expect(challenge('ANY', status: 'COMPLETED').progressFraction, 1);
  });
}
