import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_repository.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';

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
}
