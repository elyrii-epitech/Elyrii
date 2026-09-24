import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_session.dart';
import 'package:elyrii_app/features/chatbot/data/repositories/chat_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late ChatHistoryService history;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    history = ChatHistoryService(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });
  tearDown(() => history.close());

  test(
    'updating session metadata preserves its messages and original creation date',
    () async {
      final session = ChatSession.create();
      await history.append('a', session, ChatMessage.user('First'));
      final updated = session.copyWith(
        title: 'Renamed',
        updatedAt: DateTime(2027),
      );
      await history.append('a', updated, ChatMessage.user('Second'));
      final stored = (await history.sessions('a')).single;
      expect(stored.title, 'Renamed');
      expect(stored.createdAt, session.createdAt);
      expect(stored.updatedAt, DateTime(2027));
      expect(stored.messageCount, 2);
      expect((await history.messages('a', session.id)).map((m) => m.content), [
        'First',
        'Second',
      ]);
    },
  );

  test(
    'writes one message at a time, counts duplicates once, pages in order',
    () async {
      final session = ChatSession.create();
      for (var i = 0; i < 125; i++) {
        final message = ChatMessage(
          id: 'm$i',
          content: 'Message $i',
          isUser: true,
          timestamp: DateTime(2026),
        );
        await history.append('a', session, message);
        await history.append('a', session, message);
      }
      final summaries = await history.sessions('a');
      expect(summaries.single.messageCount, 125);
      expect(summaries.single.messages, isEmpty);
      final latest = await history.messages('a', session.id);
      expect(latest, hasLength(50));
      expect(latest.first.id, 'm75');
      final older = await history.messages(
        'a',
        session.id,
        beforeId: latest.first.id,
      );
      expect(older.first.id, 'm25');
      final first = await history.messages(
        'a',
        session.id,
        beforeId: older.first.id,
      );
      expect(first, hasLength(25));
      expect(first.first.id, 'm0');
    },
  );

  test('accounts are isolated, including delete and clear', () async {
    final session = ChatSession.create();
    await history.append('a', session, ChatMessage.user('private a'));
    expect(await history.sessions('b'), isEmpty);
    expect(await history.messages('b', session.id), isEmpty);
    await history.append('b', session, ChatMessage.user('private b'));
    await history.delete('a', session.id);
    expect(await history.messages('a', session.id), isEmpty);
    expect(
      (await history.messages('b', session.id)).single.content,
      'private b',
    );
    await history.clearMessages('b', session);
    expect((await history.sessions('b')).single.messageCount, 0);
  });

  test(
    'session keyset pagination handles equal timestamps without duplicates',
    () async {
      for (var i = 0; i < 125; i++) {
        final session = ChatSession(
          id: 'session-${i.toString().padLeft(3, '0')}',
          title: 'Conversation $i',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          messages: const [],
        );
        await history.append('a', session, ChatMessage.user('Bonjour'));
      }
      final first = await history.sessions('a');
      final second = await history.sessions('a', before: first.last);
      final third = await history.sessions('a', before: second.last);
      expect(first.length, 50);
      expect(second.length, 50);
      expect(third.length, 25);
      expect(
        {...first, ...second, ...third}.map((s) => s.id).toSet().length,
        125,
      );
    },
  );

  test('legacy history is retained until explicit successful import', () async {
    final session = ChatSession.create().copyWith(
      messages: [ChatMessage.user('legacy')],
    );
    SharedPreferences.setMockInitialValues({
      'chat_history_v1': jsonEncode([session.toJson()]),
    });
    expect(await history.hasLegacyHistory(), isTrue);
    expect(await history.sessions('a'), isEmpty);
    await history.importLegacy('a');
    expect(await history.hasLegacyHistory(), isFalse);
    expect((await history.messages('a', session.id)).single.content, 'legacy');
    expect(await history.sessions('b'), isEmpty);
    await history.importLegacy('a');
    expect((await history.sessions('a')).single.messageCount, 1);
  });

  test('corrupt legacy data is not deleted or partially imported', () async {
    SharedPreferences.setMockInitialValues({'chat_history_v1': 'not json'});
    await expectLater(history.importLegacy('a'), throwsFormatException);
    expect(await history.hasLegacyHistory(), isTrue);
    expect(await history.sessions('a'), isEmpty);
  });
}
