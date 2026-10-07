import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/storage/local_database.dart';
import '../../../../core/storage/content_cipher.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../entities/chat_message.dart';
import '../entities/chat_session.dart';

/// Incremental, account-scoped storage; no full-history JSON rewrites.
class ChatHistoryService {
  ChatHistoryService({
    DatabaseFactory? factory,
    this._path,
    ContentCipher? cipher,
  }) : _factory = factory ?? LocalDatabase.factory,
       cipher = cipher ?? ContentCipher(SecureStorageService());
  final ContentCipher cipher;
  final Set<String> _removed = {};
  final Map<String, Future<void>> _migrations = {};
  void _ensureOwner(String owner) {
    if (_removed.contains(owner)) throw StateError('Account history removed');
  }

  Future<void> _migrateOwner(String owner) async {
    final existing = _migrations[owner];
    if (existing != null) return existing;
    final request = _migrateOwnerRows(owner);
    _migrations[owner] = request;
    try {
      await request;
    } catch (_) {
      if (identical(_migrations[owner], request)) _migrations.remove(owner);
      rethrow;
    }
  }

  Future<void> _migrateOwnerRows(String owner) async {
    final db = await _db;
    final sessions = await db.query(
      'sessions',
      where: 'owner = ?',
      whereArgs: [owner],
    );
    final messages = await db.query(
      'messages',
      where: 'owner = ?',
      whereArgs: [owner],
    );
    final titles = <String, String>{};
    final contents = <String, String>{};
    for (final row in sessions) {
      final raw = row['title'] as String;
      if (!raw.startsWith('aesgcm1:')) {
        titles[row['id'] as String] = await cipher.seal(
          owner,
          raw,
          purpose: 'chat-title:${row['id']}',
        );
      }
    }
    for (final row in messages) {
      final raw = row['content'] as String;
      if (!raw.startsWith('aesgcm1:')) {
        contents[row['id'] as String] = await cipher.seal(
          owner,
          raw,
          purpose: 'chat-message:${row['id']}',
        );
      }
    }
    _ensureOwner(owner);
    await db.transaction((txn) async {
      for (final item in titles.entries) {
        await txn.update(
          'sessions',
          {'title': item.value},
          where: 'owner = ? AND id = ?',
          whereArgs: [owner, item.key],
        );
      }
      for (final item in contents.entries) {
        await txn.update(
          'messages',
          {'content': item.value},
          where: 'owner = ? AND id = ?',
          whereArgs: [owner, item.key],
        );
      }
    });
  }

  final DatabaseFactory _factory;
  final String? _path;
  Future<Database>? _database;
  static const pageSize = 50;
  Future<Database> get _db {
    if (_database != null) return _database!;
    late final Future<Database> opening;
    opening = _open().then(
      (db) => db,
      onError: (Object error, StackTrace stack) {
        if (identical(_database, opening)) _database = null;
        Error.throwWithStackTrace(error, stack);
      },
    );
    return _database = opening;
  }

  Future<Database> _open() async {
    final path =
        _path ?? await LocalDatabase.path('elyrii_chat_v2.db', _factory);
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        singleInstance: false,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          // This PRAGMA returns a row, even when assigning its value. The
          // native Android/iOS drivers require the query API for such SQL.
          await db.rawQuery('PRAGMA secure_delete = ON');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              "ALTER TABLE messages ADD COLUMN delivery TEXT NOT NULL DEFAULT 'delivered'",
            );
          }
        },
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE sessions (
          owner TEXT NOT NULL, id TEXT NOT NULL, title TEXT NOT NULL,
          createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL,
          messageCount INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(owner, id))''');
          await db.execute('''CREATE TABLE messages (
          seq INTEGER PRIMARY KEY AUTOINCREMENT, owner TEXT NOT NULL,
          sessionId TEXT NOT NULL, id TEXT NOT NULL, content TEXT NOT NULL,
          isUser INTEGER NOT NULL, timestamp TEXT NOT NULL,
          delivery TEXT NOT NULL DEFAULT 'delivered',
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
    if (_removed.contains(owner)) return const [];
    await _migrateOwner(owner);
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
    return [
      for (final row in rows)
        ChatSession.fromJson({
          ...row,
          'title': await cipher.open(
            owner,
            row['title'] as String,
            purpose: 'chat-title:${row['id']}',
          ),
          'messages': const [],
        }),
    ];
  }

  Future<List<ChatMessage>> messages(
    String owner,
    String sessionId, {
    String? beforeId,
  }) async {
    if (_removed.contains(owner)) return const [];
    await _migrateOwner(owner);
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
    return [
      for (final row in rows.reversed)
        ChatMessage.fromJson({
          ...row,
          'content': await cipher.open(
            owner,
            row['content'] as String,
            purpose: 'chat-message:${row['id']}',
          ),
          'isUser': row['isUser'] == 1,
        }),
    ];
  }

  Future<void> append(
    String owner,
    ChatSession session,
    ChatMessage message,
  ) async {
    _ensureOwner(owner);
    final encrypted = await cipher.seal(
      owner,
      message.content,
      purpose: 'chat-message:${message.id}',
    );
    await (await _db).transaction((txn) async {
      _ensureOwner(owner);
      await _upsert(txn, owner, session);
      await txn.rawInsert(
        '''INSERT OR IGNORE INTO messages
        (owner, sessionId, id, content, isUser, timestamp, delivery) VALUES (?, ?, ?, ?, ?, ?, ?)''',
        [
          owner,
          session.id,
          message.id,
          encrypted,
          message.isUser ? 1 : 0,
          message.timestamp.toIso8601String(),
          message.delivery.name,
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

  Future<void> updateDelivery(
    String owner,
    String id,
    MessageDelivery delivery,
  ) async {
    _ensureOwner(owner);
    await (await _db).update(
      'messages',
      {'delivery': delivery.name},
      where: 'owner = ? AND id = ?',
      whereArgs: [owner, id],
    );
  }

  Future<void> _upsert(
    DatabaseExecutor db,
    String owner,
    ChatSession session,
  ) async {
    _ensureOwner(owner);
    final title = await cipher.seal(
      owner,
      session.title,
      purpose: 'chat-title:${session.id}',
    );
    await db.rawInsert(
      '''INSERT OR IGNORE INTO sessions(owner, id, title, createdAt, updatedAt)
      VALUES (?, ?, ?, ?, ?)''',
      [
        owner,
        session.id,
        title,
        session.createdAt.toIso8601String(),
        session.updatedAt.toIso8601String(),
      ],
    );
    // Both statements run inside the caller's transaction. Avoid UPSERT
    // (SQLite 3.24+) and REPLACE (which would cascade-delete the messages).
    await db.rawUpdate(
      'UPDATE sessions SET title = ?, updatedAt = ? WHERE owner = ? AND id = ?',
      [title, session.updatedAt.toIso8601String(), owner, session.id],
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
    _ensureOwner(owner);
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
    _ensureOwner(owner);
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
            (owner, sessionId, id, content, isUser, timestamp, delivery) VALUES (?, ?, ?, ?, ?, ?, ?)''',
            [
              owner,
              session.id,
              message.id,
              await cipher.seal(
                owner,
                message.content,
                purpose: 'chat-message:${message.id}',
              ),
              message.isUser ? 1 : 0,
              message.timestamp.toIso8601String(),
              message.delivery.name,
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

  Future<void> deleteOwner(String owner) async {
    _removed.add(owner);
    try {
      await _migrations[owner];
    } catch (_) {}
    await (await _db).delete(
      'sessions',
      where: 'owner = ?',
      whereArgs: [owner],
    );
    // Compact deleted plaintext pages from old databases as well.
    await (await _db).rawQuery('PRAGMA secure_delete = ON');
    await (await _db).execute('VACUUM');
  }

  Future<void> close() async {
    if (_database != null) await (await _database!).close();
    _database = null;
  }
}
