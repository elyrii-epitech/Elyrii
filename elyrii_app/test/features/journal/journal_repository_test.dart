import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:elyrii_app/core/network/api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_repository.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';

class _Storage extends SecureStorageService {
  String? owner = 'account-a';
  @override
  Future<String?> getUserId() async => owner;
  @override
  Future<String?> getAccessToken() async => 'fixture';
}

Map<String, dynamic> _entry(String owner) => JournalEntryModel(
  id: 'entry-$owner',
  userId: owner,
  title: 'Note privée',
  createdAt: DateTime(2026, 9, 19),
  updatedAt: DateTime(2026, 9, 19),
).toCacheJson();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JournalEntryModel Serialization', () {
    test(
      'toCacheJson préserve tous les champs nécessaires à la reconstruction',
      () {
        final now = DateTime(2026, 3, 15, 10, 30);
        final entry = JournalEntryModel(
          id: 'entry_123',
          userId: 'user_456',
          title: 'Pensée du matin',
          content: 'Je me sens calme et serein.',
          mood: 'happy',
          createdAt: now,
          updatedAt: now,
        );

        final cacheMap = entry.toCacheJson();

        expect(cacheMap['id'], equals('entry_123'));
        expect(cacheMap['userId'], equals('user_456'));
        expect(cacheMap['title'], equals('Pensée du matin'));
        expect(cacheMap['content'], equals('Je me sens calme et serein.'));
        expect(cacheMap['mood'], equals('happy'));
        expect(cacheMap['createdAt'], equals(now.toIso8601String()));

        // Reconstruction exacte depuis le cache
        final restored = JournalEntryModel.fromJson(cacheMap);
        expect(restored.id, equals(entry.id));
        expect(restored.userId, equals(entry.userId));
        expect(restored.title, equals(entry.title));
        expect(restored.content, equals(entry.content));
        expect(restored.mood, equals(entry.mood));
      },
    );
  });

  group('JournalRepository Offline Cache', () {
    late JournalRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final storage = SecureStorageService();
      final client = ApiClient(storage: storage);
      repository = JournalRepository(client: client);
    });

    test('getCachedEntries retourne une liste vide si aucun cache', () async {
      final cached = await repository.getCachedEntries();
      expect(cached, isEmpty);
    });
  });

  test(
    'legacy cache only exposes entries belonging to the current account',
    () async {
      SharedPreferences.setMockInitialValues({
        'cache_journal_entries': jsonEncode([
          _entry('account-a'),
          _entry('account-b'),
        ]),
      });
      final storage = _Storage();
      final repository = JournalRepository(client: ApiClient(storage: storage));
      expect((await repository.getCachedEntries()).single.userId, 'account-a');
      storage.owner = 'account-b';
      expect((await repository.getCachedEntries()).single.userId, 'account-b');
      storage.owner = null;
      expect(await repository.getCachedEntries(), isEmpty);
    },
  );

  test(
    'offline requests use the account cache, but never mask a rejected session',
    () async {
      SharedPreferences.setMockInitialValues({
        'cache_journal_entries_account-a': jsonEncode([_entry('account-a')]),
      });
      var unauthorized = false;
      final client = ApiClient(
        storage: _Storage(),
        client: MockClient((request) async {
          if (unauthorized) return http.Response('{"message":"Expired"}', 401);
          throw const SocketException('Offline');
        }),
      );
      final repository = JournalRepository(client: client);
      expect((await repository.getEntries()).single.userId, 'account-a');
      unauthorized = true;
      await expectLater(repository.getEntries(), throwsA(isA<ApiException>()));
    },
  );

  test(
    'a request started without an account cannot fall back to a newly signed-in account',
    () async {
      SharedPreferences.setMockInitialValues({
        'cache_journal_entries_account-b': jsonEncode([_entry('account-b')]),
      });
      final storage = _Storage()..owner = null;
      final repository = JournalRepository(
        client: ApiClient(
          storage: storage,
          client: MockClient((request) async {
            storage.owner = 'account-b';
            throw const SocketException('Offline');
          }),
        ),
      );
      await expectLater(
        repository.getEntries(),
        throwsA(isA<SocketException>()),
      );
    },
  );
}
