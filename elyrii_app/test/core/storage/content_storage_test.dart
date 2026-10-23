import 'dart:io';

import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/core/storage/local_database.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_session.dart';
import 'package:elyrii_app/features/chatbot/data/repositories/chat_history_service.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _RecoveringStorage extends SecureStorageService {
  bool failing = true;
  @override
  Future<String?> read({required String key}) {
    if (failing) throw StateError('Temporary secure storage failure');
    return super.read(key: key);
  }
}

class _RootDatabaseFactory implements DatabaseFactory {
  @override
  Future<String> getDatabasesPath() async => '/';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('database names remain distinct when the platform directory is its root', () async {
    final previous = LocalDatabase.pathOverride;
    LocalDatabase.pathOverride = null;
    addTearDown(() => LocalDatabase.pathOverride = previous);
    final factory = _RootDatabaseFactory();
    final chat = await LocalDatabase.path('elyrii_chat_v2.db', factory);
    final journal = await LocalDatabase.path('elyrii_journal_v3.db', factory);
    // A leading // is an authority in a browser URL. SQLite's browser VFS
    // would resolve both names to /, sharing a file and corrupting its schema.
    for (final name in [chat, journal]) {
      expect(Uri.parse(name).hasAuthority, isFalse);
      expect(Uri.parse(name).path, endsWith('.db'));
    }
    expect(chat, isNot(journal));
  });
  test(
    'chat plaintext migration can be retried after secure storage recovers',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'elyrii-chat-migration-',
      );
      final databasePath = '${dir.path}/chat.db';
      final initial = ChatHistoryService(
        factory: databaseFactoryFfi,
        path: databasePath,
      );
      final date = DateTime.utc(2026, 10, 6);
      await initial.append(
        'migration',
        ChatSession(
          id: 'session',
          title: 'Title',
          createdAt: date,
          updatedAt: date,
          messages: const [],
        ),
        ChatMessage(
          id: 'message',
          content: 'Message',
          isUser: true,
          timestamp: date,
        ),
      );
      await initial.close();
      final db = await databaseFactoryFfi.openDatabase(databasePath);
      await db.update(
        'sessions',
        {'title': 'LEGACY_TITLE'},
        where: 'owner = ?',
        whereArgs: ['migration'],
      );
      await db.close();
      final storage = _RecoveringStorage();
      final history = ChatHistoryService(
        factory: databaseFactoryFfi,
        path: databasePath,
        cipher: ContentCipher(storage),
      );
      addTearDown(() async {
        await history.close();
        await dir.delete(recursive: true);
      });
      await expectLater(history.sessions('migration'), throwsStateError);
      storage.failing = false;
      expect(
        (await history.sessions('migration')).single.title,
        'LEGACY_TITLE',
      );
      final encryptedDb = await databaseFactoryFfi.openDatabase(databasePath);
      expect(
        (await encryptedDb.query('sessions')).single['title'],
        startsWith('aesgcm1:'),
      );
      await encryptedDb.close();
    },
  );
  test('a transient secure-storage error does not permanently poison the content key', () async {
    final storage = _RecoveringStorage();
    final cipher = ContentCipher(storage);
    await expectLater(
      cipher.seal('recovery', 'Private content', purpose: 'draft'),
      throwsStateError,
    );
    storage.failing = false;
    final sealed = await cipher.seal(
      'recovery',
      'Private content',
      purpose: 'draft',
    );
    expect(
      await cipher.open('recovery', sealed, purpose: 'draft'),
      'Private content',
    );
  });
  test(
    'ciphertext is randomized and bound to both account and resource',
    () async {
      final cipher = ContentCipher(SecureStorageService());
      final first = await cipher.seal(
        'alice',
        'Private thoughts',
        purpose: 'journal:one',
      );
      final second = await cipher.seal(
        'alice',
        'Private thoughts',
        purpose: 'journal:one',
      );
      expect(first, isNot(second));
      expect(first, isNot(contains('Private thoughts')));
      expect(
        await cipher.open('alice', first, purpose: 'journal:one'),
        'Private thoughts',
      );
      await expectLater(
        cipher.open('bob', first, purpose: 'journal:one'),
        throwsA(anything),
      );
      await expectLater(
        cipher.open('alice', first, purpose: 'journal:two'),
        throwsA(anything),
      );
      final damaged = '${first.substring(0, first.length - 8)}AAAAAAAA';
      await expectLater(
        cipher.open('alice', damaged, purpose: 'journal:one'),
        throwsA(anything),
      );
    },
  );
  test('encrypted journal drafts survive reopening without plaintext SQLite content', () async {
    final dir = await Directory.systemTemp.createTemp('elyrii-journal-test-');
    final path = '${dir.path}/journal.db';
    final cipher = ContentCipher(SecureStorageService());
    final store = JournalStore(
      cipher: cipher,
      factory: databaseFactoryFfi,
      path: path,
    );
    await store.saveDraft('alice', 'new', {
      'content': 'PRIVATE_DRAFT_SENTINEL',
    });
    await store.saveDraft('bob', 'new', {'content': 'Bob private draft'});
    await store.close();
    final reopened = JournalStore(
      cipher: cipher,
      factory: databaseFactoryFfi,
      path: path,
    );
    addTearDown(() async {
      await reopened.close();
      await dir.delete(recursive: true);
    });
    expect(
      (await reopened.readDraft('alice', 'new'))!['content'],
      'PRIVATE_DRAFT_SENTINEL',
    );
    final db = await databaseFactoryFfi.openDatabase(path);
    final rows = await db.query('drafts');
    expect(
      rows.map((row) => row['data']).join(),
      isNot(contains('PRIVATE_DRAFT_SENTINEL')),
    );
    await db.close();
    await reopened.deleteOwner('alice');
    expect(await reopened.readDraft('alice', 'new'), isNull);
    expect(
      (await reopened.readDraft('bob', 'new'))!['content'],
      'Bob private draft',
    );
    await expectLater(
      reopened.saveDraft('alice', 'new', {'content': 'Late write'}),
      throwsStateError,
    );
  });
  test('chat purge cascades its messages, preserves other accounts and rejects late writes', () async {
    final history = ChatHistoryService(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(history.close);
    final first = ChatSession.create();
    final second = ChatSession.create();
    await history.append('alice', first, ChatMessage.user('Private Alice'));
    await history.append('bob', second, ChatMessage.user('Private Bob'));
    await history.deleteOwner('alice');
    expect(await history.sessions('alice'), isEmpty);
    expect(await history.messages('alice', first.id), isEmpty);
    expect(await history.messages('bob', second.id), hasLength(1));
    await expectLater(
      history.append('alice', first, ChatMessage.user('Late Alice')),
      throwsStateError,
    );
  });
}
