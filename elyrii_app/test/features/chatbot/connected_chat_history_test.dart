import 'dart:convert';
import 'dart:io';

import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/network/api_exception.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/chatbot/data/repositories/connected_chat_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const conversation = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

class _Storage extends SecureStorageService {
  @override
  Future<String?> getUserId() async => owner;
  @override
  Future<String?> getAccessToken() async => 'fixture';
}

void main() {
  test(
    'remote message pages retain timestamp ties and remain bounded offline',
    () async {
      var offline = false;
      final rows = List.generate(
        125,
        (i) => {
          'id': 'm${i.toString().padLeft(3, '0')}',
          'userId': owner,
          'conversationId': conversation,
          'role': i.isEven ? 'user' : 'ai',
          'message': 'Fixture $i',
          'createdAt': '2026-09-18T12:00:00.123Z',
        },
      );
      final api = ApiClient(
        storage: _Storage(),
        client: MockClient((request) async {
          if (offline) throw const SocketException('Offline fixture');
          if (request.url.path.endsWith('/conversations')) {
            return http.Response(
              jsonEncode([
                {
                  'id': conversation,
                  'userId': owner,
                  'title': 'Fixture',
                  'messageCount': 125,
                  'createdAt': rows.first['createdAt'],
                  'updatedAt': rows.last['createdAt'],
                },
              ]),
              200,
            );
          }
          final before = request.url.queryParameters['beforeId'];
          final end = before == null
              ? rows.length
              : rows.indexWhere((m) => m['id'] == before);
          final start = (end - 50).clamp(0, end);
          return http.Response(jsonEncode(rows.sublist(start, end)), 200);
        }),
      );
      final history = ConnectedChatHistory(client: api);
      addTearDown(api.dispose);
      addTearDown(history.close);
      expect((await history.sessions(owner)).single.messageCount, 125);
      final first = await history.messages(owner, conversation);
      final second = await history.messages(
        owner,
        conversation,
        beforeId: first.first.id,
      );
      final third = await history.messages(
        owner,
        conversation,
        beforeId: second.first.id,
      );
      expect([first.length, second.length, third.length], [50, 50, 25]);
      expect(
        [...first, ...second, ...third].map((m) => m.id).toSet().length,
        125,
      );
      offline = true;
      expect(
        (await history.messages(owner, conversation)).map((m) => m.id),
        first.map((m) => m.id),
      );
      expect(
        (await history.messages(
          owner,
          conversation,
          beforeId: first.first.id,
        )).map((m) => m.id),
        second.map((m) => m.id),
      );
      expect(await history.sessions('other-owner'), isEmpty);
    },
  );

  test('401 and malformed ownership never fall back to or overwrite confirmed history', () async {
    var mode = 'valid';
    final api = ApiClient(
      storage: _Storage(),
      client: MockClient((_) async {
        if (mode == 'unauthorized') {
          return http.Response('{"error":"Unauthorized"}', 401);
        }
        return http.Response(
          jsonEncode([
            {
              'id': conversation,
              'userId': mode == 'wrong-owner' ? 'someone-else' : owner,
              'title': 'Private',
              'messageCount': 2,
              'createdAt': '2026-09-18T12:00:00Z',
              'updatedAt': '2026-09-18T12:00:00Z',
            },
          ]),
          200,
        );
      }),
    );
    final history = ConnectedChatHistory(client: api);
    addTearDown(api.dispose);
    addTearDown(history.close);
    expect((await history.sessions(owner)).single.title, 'Private');
    mode = 'wrong-owner';
    await expectLater(
      history.sessions(owner),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.protocol,
        ),
      ),
    );
    mode = 'unauthorized';
    await expectLater(
      history.sessions(owner),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.unauthorized,
        ),
      ),
    );
    mode = 'valid';
    expect((await history.sessions(owner)).single.title, 'Private');
  });
}
