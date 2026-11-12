import 'dart:convert';
import 'dart:io';

import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MemoryFactory implements DatabaseFactory {
  @override
  Future<String> getDatabasesPath() async => '/journal-benchmark';
  @override
  Future<Database> openDatabase(String path, {OpenDatabaseOptions? options}) =>
      databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: options);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountingCipher implements ContentCipher {
  _CountingCipher(this.delegate);
  final ContentCipher delegate;
  int opens = 0;
  @override
  SecureStorageService get storage => delegate.storage;
  @override
  Future<String> seal(String owner, String value, {required String purpose}) =>
      delegate.seal(owner, value, purpose: purpose);
  @override
  Future<String> open(String owner, String value, {required String purpose}) {
    opens++;
    return delegate.open(owner, value, purpose: purpose);
  }

  @override
  Future<void> deleteOwner(String owner) => delegate.deleteOwner(owner);
}

void main() {
  final evidence = <Map<String, Object>>[];
  tearDownAll(() {
    const output = String.fromEnvironment(
      'AUDIT_OUTPUT',
      defaultValue: 'build/a11y-evidence',
    );
    final file = File('$output/journal-scaling.json');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(evidence),
    );
  });
  for (final size in [100, 1000, 10000]) {
    test(
      'a page decrypts at most 100 entries in a $size-note encrypted history',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final cipher = _CountingCipher(ContentCipher(SecureStorageService()));
        final store = JournalStore(cipher: cipher, factory: _MemoryFactory());
        addTearDown(store.close);
        final now = DateTime.utc(2026, 10, 10);
        final entries = List.generate(
          size,
          (i) => JournalEntryModel(
            id: i.toString().padLeft(8, '0'),
            userId: 'scaling-fixture',
            title: 'Synthetic note $i',
            content: List.filled(50, 'Synthetic private text.').join(' '),
            createdAt: now.add(Duration(minutes: i)),
            updatedAt: now,
          ),
        );
        final writing = Stopwatch()..start();
        await store.replace('scaling-fixture', entries, expectedRevision: 0);
        writing.stop();
        final paging = Stopwatch()..start();
        final first = await store.read(
          'scaling-fixture',
          limit: 100,
          newestFirst: true,
        );
        paging.stop();
        expect(first.length, 100);
        expect(first.first.id, entries.last.id);
        expect(cipher.opens, 100);
        expect(await store.count('scaling-fixture'), size);
        expect(cipher.opens, 100, reason: 'Counting must not decrypt history');
        cipher.opens = 0;
        final next = await store.read(
          'scaling-fixture',
          limit: 100,
          offset: 100,
          newestFirst: true,
        );
        expect(next.length, size == 100 ? 0 : 100);
        expect(cipher.opens, next.length);
        expect(
          first
              .map((e) => e.id)
              .toSet()
              .intersection(next.map((e) => e.id).toSet()),
          isEmpty,
        );
        expect(await store.read('another-owner', limit: 100), isEmpty);
        evidence.add({
          'notes': size,
          'rowsDecryptedPerPage': 100,
          'prepareEncryptedStoreMs': writing.elapsedMilliseconds,
          'firstPageMs': paging.elapsedMilliseconds,
          'environment': 'Flutter VM, SQLite FFI, in-memory, synthetic 1 KB notes; not a native-device latency benchmark',
        });
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
