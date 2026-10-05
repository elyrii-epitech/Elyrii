import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_repository.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';

class _Repository extends JournalRepository {
  _Repository() : super(client: ApiClient(storage: SecureStorageService()));
  final loads = <Completer<List<JournalEntryModel>>>[];
  final created = Completer<JournalEntryModel>();
  @override
  Future<List<JournalEntryModel>> getEntries({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final result = Completer<List<JournalEntryModel>>();
    loads.add(result);
    return result.future;
  }

  @override
  Future<JournalEntryModel> createEntry({
    required String title,
    String? content,
    String? mood,
    List<String>? tags,
  }) => created.future;
}

JournalEntryModel _entry(String owner) => JournalEntryModel(
  id: owner,
  userId: owner,
  title: owner,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test(
    'deduplicates loads and ignores old-account responses after logout',
    () async {
      final repo = _Repository();
      final provider = JournalProvider(repository: repo);
      addTearDown(provider.dispose);
      final first = provider.loadEntries();
      expect(identical(first, provider.loadEntries()), isTrue);
      provider.resetSession();
      final second = provider.loadEntries();
      repo.loads.first.complete([_entry('account-a')]);
      await first;
      expect(provider.entries, isEmpty);
      expect(identical(second, provider.loadEntries()), isTrue);
      expect(repo.loads.length, 2);
      repo.loads.last.complete([_entry('account-b')]);
      await second;
      expect(provider.entries.single.userId, 'account-b');
    },
  );

  test(
    'an older failed request cannot replace the latest successful state',
    () async {
      final repo = _Repository();
      final provider = JournalProvider(repository: repo);
      addTearDown(provider.dispose);
      final older = provider.loadEntries();
      final latest = provider.loadEntries(startDate: DateTime(2026));
      repo.loads.last.complete([_entry('latest')]);
      await latest;
      repo.loads.first.completeError(StateError('old failure'));
      await older;
      expect(provider.error, isNull);
      expect(provider.entries.single.id, 'latest');
      expect(provider.isLoading, isFalse);
    },
  );

  test(
    'a save finishing after logout does not restore private notes in memory',
    () async {
      final repo = _Repository();
      final provider = JournalProvider(repository: repo);
      addTearDown(provider.dispose);
      final save = provider.createEntry(content: 'Private draft');
      provider.resetSession();
      repo.created.complete(_entry('account-a'));
      expect(await save, isNull);
      expect(provider.entries, isEmpty);
    },
  );
}
