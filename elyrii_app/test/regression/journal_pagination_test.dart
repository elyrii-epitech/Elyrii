import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String?> getUserId() async => 'paging-owner';
  @override
  Future<String?> getAccessToken() async => 'fixture';
}

JournalEntryModel _note(String id) => JournalEntryModel(
  id: id,
  userId: 'paging-owner',
  title: id,
  createdAt: DateTime.utc(2026, 10, 10),
  updatedAt: DateTime.utc(2026, 10, 10),
);
http.Response _page(List<String> ids, {String? cursor}) => http.Response(
  jsonEncode({
    'entries': ids.map((id) => _note(id).toCacheJson()).toList(),
    'totalCount': 4,
    'nextCursor': cursor == null
        ? null
        : {'id': cursor, 'createdAt': '2026-10-10T00:00:00.000Z'},
  }),
  200,
);

void main() {
  test('the client follows the server cursor and preserves it when a concurrent mutation invalidates a page', () async {
    final delayed = Completer<http.Response>();
    final received = Completer<void>();
    final queries = <Map<String, String>>[];
    final api = ApiClient(
      storage: _Storage(),
      client: MockClient((request) async {
        queries.add(request.url.queryParameters);
        if (queries.length == 1) return _page(['one', 'two'], cursor: 'two');
        if (queries.length == 2) {
          received.complete();
          return delayed.future;
        }
        return _page(['three', 'four']);
      }),
    );
    addTearDown(api.dispose);
    final repository = JournalRepository(client: api);
    addTearDown(repository.store.close);
    expect((await repository.getEntries()).length, 2);
    expect(queries.first['limit'], '100');
    expect(repository.hasMore, isTrue);
    final pending = repository.getMoreEntries();
    await received.future;
    await repository.store.upsert('paging-owner', _note('acknowledged-new'));
    delayed.complete(_page(['three', 'four']));
    await pending;
    expect(
      repository.hasMore,
      isTrue,
      reason: 'An invalidated page must not consume the continuation',
    );
    expect((await repository.getMoreEntries()).map((e) => e.id), [
      'three',
      'four',
    ]);
    expect(queries[1]['cursorId'], 'two');
    expect(queries[2]['cursorId'], 'two');
    expect(repository.hasMore, isFalse);
    expect(
      (await repository.store.read('paging-owner')).map((e) => e.id),
      contains('acknowledged-new'),
    );
  });

  test('offline continuation reads bounded pages without duplicates or another owner', () async {
    final api = ApiClient(
      storage: _Storage(),
      client: MockClient(
        (_) async => throw const SocketException('offline fixture'),
      ),
    );
    addTearDown(api.dispose);
    final repository = JournalRepository(client: api);
    addTearDown(repository.store.close);
    await repository.store.replace(
      'paging-owner',
      List.generate(240, (i) => _note('id-${i.toString().padLeft(4, '0')}')),
      expectedRevision: 0,
    );
    await repository.store.upsert(
      'other-owner',
      JournalEntryModel(
        id: 'other-private',
        userId: 'other-owner',
        title: 'Other',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final first = await repository.getEntries();
    final second = await repository.getMoreEntries();
    final third = await repository.getMoreEntries();
    expect([first.length, second.length, third.length], [100, 100, 40]);
    expect(
      [...first, ...second, ...third].map((e) => e.id).toSet().length,
      240,
    );
    expect(
      [...first, ...second, ...third].every((e) => e.userId == 'paging-owner'),
      isTrue,
    );
    expect(repository.hasMore, isFalse);
  });
}
