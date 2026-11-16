import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_store.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntryModel note(String id, {String owner = 'owner'}) =>
    JournalEntryModel(
      id: id,
      userId: owner,
      title: id,
      createdAt: DateTime.utc(2026, 10, 10, 12, 0, 0, 123, 456),
      updatedAt: DateTime.utc(2026, 10, 10),
    );

void main() {
  for (final newest in [true, false]) {
    test('refresh reconciles only known page ranges (newestFirst=$newest)', () async {
      final store = JournalStore(cipher: ContentCipher(SecureStorageService()));
      addTearDown(store.close);
      await store.replace(
        'owner',
        ['a', 'b', 'c', 'd', 'e'].map(note).toList(),
        expectedRevision: 0,
      );
      await store.upsert('other', note('private', owner: 'other'));
      final first = newest ? ['e', 'c'] : ['a', 'c'];
      await store.mergePage(
        'owner',
        first.map(note).toList(),
        expectedRevision: store.revision('owner'),
        newestFirst: newest,
        hasMore: true,
      );
      expect(
        (await store.read('owner')).map((e) => e.id).toSet(),
        newest ? {'a', 'b', 'c', 'e'} : {'a', 'c', 'd', 'e'},
      );
      // Last empty page proves all remaining stale rows were deleted remotely.
      await store.mergePage(
        'owner',
        [],
        expectedRevision: store.revision('owner'),
        newestFirst: newest,
        hasMore: false,
        after: (createdAt: note('c').createdAt, id: 'c'),
      );
      expect(
        (await store.read('owner')).map((e) => e.id).toSet(),
        first.toSet(),
      );
      expect((await store.read('other')).single.id, 'private');
      await store.mergePage(
        'owner',
        [],
        expectedRevision: store.revision('owner'),
        newestFirst: newest,
        hasMore: false,
      );
      expect(await store.read('owner'), isEmpty);
    });
  }
}
