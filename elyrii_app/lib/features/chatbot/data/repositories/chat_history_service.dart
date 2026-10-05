import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../entities/chat_message.dart';
import '../entities/chat_session.dart';

/// Incremental, account-scoped storage; no full-history JSON rewrites.
class ChatHistoryService {
  ChatHistoryService({DatabaseFactory? factory, String? path})
    : _factory = factory ?? databaseFactory,
      _path = path;
  final DatabaseFactory _factory;
  final String? _path;
  Future<Database>? _database;
  static const pageSize = 50;
  Future<Database> get _db => _database ??= _open();

  Future<Database> _open() async {
    final path =
        _path ?? '${await _factory.getDatabasesPath()}/elyrii_chat_v2.db';
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE sessions (
          owner TEXT NOT NULL, id TEXT NOT NULL, title TEXT NOT NULL,
          createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL,
          messageCount INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(owner, id))''');
          await db.execute('''CREATE TABLE messages (
          seq INTEGER PRIMARY KEY AUTOINCREMENT, owner TEXT NOT NULL,
          sessionId TEXT NOT NULL, id TEXT NOT NULL, content TEXT NOT NULL,
          isUser INTEGER NOT NULL, timestamp TEXT NOT NULL,
          UNIQUE(owner, id), FOREIGN KEY(owner, sessionId)
          REFERENCES sessions(owner, id) ON DELETE CASCADE)''');
          await db.execute(
            'CREATE INDEX message_page ON messages(owner, sessionId, seq)',
          );
          await db.execute(
            'CREATE INDEX session_page ON sessions(owner, updatedAt DESC, id)',
          );
        },
      ),
    );
  }

  Future<List<ChatSession>> sessions(
    String owner, {
    ChatSession? before,
  }) async {
    final rows = await (await _db).query(
      'sessions',
      where: before == null
          ? 'owner = ?'
          : 'owner = ? AND (updatedAt < ? OR (updatedAt = ? AND id > ?))',
      whereArgs: [
        owner,
        if (before != null) ...[
          before.updatedAt.toIso8601String(),
          before.updatedAt.toIso8601String(),
          before.id,
        ],
      ],
      orderBy: 'updatedAt DESC, id',
      limit: pageSize,
    );
    return rows
        .map((row) => ChatSession.fromJson({...row, 'messages': const []}))
        .toList();
  }

  Future<List<ChatMessage>> messages(
    String owner,
    String sessionId, {
    String? beforeId,
  }) async {
    final rows = await (await _db).rawQuery(
      '''SELECT * FROM messages
      WHERE owner = ? AND sessionId = ?
      ${beforeId == null ? '' : 'AND seq < (SELECT seq FROM messages WHERE owner = ? AND id = ?)'}
      ORDER BY seq DESC LIMIT ?''',
      [
        owner,
        sessionId,
        if (beforeId != null) ...[owner, beforeId],
        pageSize,
      ],
    );
    return rows.reversed
        .map(
          (row) => ChatMessage.fromJson({...row, 'isUser': row['isUser'] == 1}),
        )
        .toList();
  }

  Future<void> append(
    String owner,
    ChatSession session,
    ChatMessage message,
  ) async {
    await (await _db).transaction((txn) async {
      await _upsert(txn, owner, session);
      await txn.rawInsert(
        '''INSERT OR IGNORE INTO messages
        (owner, sessionId, id, content, isUser, timestamp) VALUES (?, ?, ?, ?, ?, ?)''',
        [
          owner,
          session.id,
          message.id,
          message.content,
          message.isUser ? 1 : 0,
          message.timestamp.toIso8601String(),
        ],
      );
      final changed =
          Sqflite.firstIntValue(await txn.rawQuery('SELECT changes()')) ?? 0;
      if (changed > 0) {
        await txn.rawUpdate(
          'UPDATE sessions SET messageCount = messageCount + 1 WHERE owner = ? AND id = ?',
          [owner, session.id],
        );
      }
    });
  }

  Future<void> _upsert(
    DatabaseExecutor db,
    String owner,
    ChatSession session,
  ) async {
    await db.rawInsert(
      '''INSERT OR IGNORE INTO sessions(owner, id, title, createdAt, updatedAt)
      VALUES (?, ?, ?, ?, ?)''',
      [
        owner,
        session.id,
        session.title,
        session.createdAt.toIso8601String(),
        session.updatedAt.toIso8601String(),
      ],
    );
    // Both statements run inside the caller's transaction. Avoid UPSERT
    // (SQLite 3.24+) and REPLACE (which would cascade-delete the messages).
    await db.rawUpdate(
      'UPDATE sessions SET title = ?, updatedAt = ? WHERE owner = ? AND id = ?',
      [session.title, session.updatedAt.toIso8601String(), owner, session.id],
    );
  }

  Future<void> delete(String owner, String sessionId) async {
    await (await _db).delete(
      'sessions',
      where: 'owner = ? AND id = ?',
      whereArgs: [owner, sessionId],
    );
  }

  Future<void> clearMessages(String owner, ChatSession session) async {
    await (await _db).transaction((txn) async {
      await txn.delete(
        'messages',
        where: 'owner = ? AND sessionId = ?',
        whereArgs: [owner, session.id],
      );
      await _upsert(txn, owner, session);
      await txn.rawUpdate(
        'UPDATE sessions SET messageCount = 0 WHERE owner = ? AND id = ?',
        [owner, session.id],
      );
    });
  }

  Future<bool> hasLegacyHistory() async =>
      (await SharedPreferences.getInstance()).containsKey('chat_history_v1');

  /// Old JSON has no account identifier. Import requires explicit consent;
  /// never silently assign another user's history to the next signed-in user.
  Future<void> importLegacy(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_history_v1');
    if (raw == null) return;
    final decoded = await compute(_decodeLegacy, raw);
    await (await _db).transaction((txn) async {
      for (final session in decoded) {
        await _upsert(txn, owner, session);
        final batch = txn.batch();
        for (final message in session.messages) {
          batch.rawInsert(
            '''INSERT OR IGNORE INTO messages
            (owner, sessionId, id, content, isUser, timestamp) VALUES (?, ?, ?, ?, ?, ?)''',
            [
              owner,
              session.id,
              message.id,
              message.content,
              message.isUser ? 1 : 0,
              message.timestamp.toIso8601String(),
            ],
          );
        }
        await batch.commit(noResult: true);
        await txn.rawUpdate(
          '''UPDATE sessions SET messageCount =
          (SELECT COUNT(*) FROM messages WHERE owner = ? AND sessionId = ?)
          WHERE owner = ? AND id = ?''',
          [owner, session.id, owner, session.id],
        );
      }
    });
    // Transaction first; corrupted data remains available for recovery.
    await prefs.remove('chat_history_v1');
  }

  static List<ChatSession> _decodeLegacy(String raw) =>
      (jsonDecode(raw) as List)
          .map(
            (row) =>
                ChatSession.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();

  Future<void> close() async {
    if (_database != null) await (await _database!).close();
    _database = null;
  }
}
