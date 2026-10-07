import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../../../core/storage/local_database.dart';
import '../../../../core/storage/content_cipher.dart';
import '../models/journal_entry_model.dart';

/// Durable account-owned journal snapshots and drafts. Each mutation updates
/// one row; replacing a remote snapshot is transactional and revision-guarded.
class JournalStore {
  final ContentCipher cipher;
  final DatabaseFactory _factory;
  final String? _path;
  Future<Database>? _database;
  Future<void> _writes = Future.value();
  final Map<String, int> _revisions = {};
  final Set<String> _removedOwners = {};
  final Set<String> _migrated = {};
  JournalStore({required this.cipher, DatabaseFactory? factory, this._path})
    : _factory = factory ?? LocalDatabase.factory;
  int revision(String owner) => _revisions[owner] ?? 0;

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

  Future<Database> _open() async => _factory.openDatabase(
    _path ?? await LocalDatabase.path('elyrii_journal_v3.db', _factory),
    options: OpenDatabaseOptions(
      version: 1,
      singleInstance: false,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE entries(owner TEXT NOT NULL, id TEXT NOT NULL, data TEXT NOT NULL, createdAt TEXT NOT NULL, PRIMARY KEY(owner,id))',
        );
        await db.execute('CREATE TABLE snapshots(owner TEXT PRIMARY KEY)');
        await db.execute(
          'CREATE TABLE drafts(owner TEXT NOT NULL, id TEXT NOT NULL, data TEXT NOT NULL, PRIMARY KEY(owner,id))',
        );
      },
    ),
  );

  Future<T> _write<T>(Future<T> Function(Database db) operation) {
    final task = _writes.then((_) async => operation(await _db));
    _writes = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  void _ensureOwner(String owner) {
    if (owner.isEmpty || _removedOwners.contains(owner)) {
      throw StateError('No writable account');
    }
  }

  Future<Map<String, Object?>> _row(
    String owner,
    JournalEntryModel entry,
  ) async {
    if (entry.userId != owner || entry.id.isEmpty) {
      throw const FormatException('Journal account or id invalid');
    }
    return {
      'owner': owner,
      'id': entry.id,
      'createdAt': entry.createdAt.toIso8601String(),
      'data': await cipher.seal(
        owner,
        jsonEncode(entry.toCacheJson()),
        purpose: 'journal:${entry.id}',
      ),
    };
  }

  Future<void> _migrate(String owner) async {
    if (_migrated.contains(owner)) return;
    await _write((db) async {
      _ensureOwner(owner);
      if (_migrated.contains(owner)) return;
      final prefs = await SharedPreferences.getInstance();
      final scoped = 'cache_journal_entries_$owner';
      final raw =
          prefs.getString(scoped) ?? prefs.getString('cache_journal_entries');
      if (raw != null) {
        final all = jsonDecode(raw) as List;
        final own = all
            .where(
              (value) =>
                  value is Map &&
                  (value['userId'] ?? value['user_id']) == owner,
            )
            .map(
              (e) => JournalEntryModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
        final rows = [for (final entry in own) await _row(owner, entry)];
        await db.transaction((txn) async {
          for (final row in rows) {
            await txn.insert(
              'entries',
              row,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
          await txn.insert('snapshots', {
            'owner': owner,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        });
        if (prefs.containsKey(scoped)) {
          await prefs.remove(scoped);
        } else {
          final remaining = all
              .where(
                (value) =>
                    value is! Map ||
                    (value['userId'] ?? value['user_id']) != owner,
              )
              .toList();
          if (remaining.isEmpty) {
            await prefs.remove('cache_journal_entries');
          } else {
            await prefs.setString(
              'cache_journal_entries',
              jsonEncode(remaining),
            );
          }
        }
      }
      _migrated.add(owner);
    });
  }

  Future<bool> hasSnapshot(String owner) async {
    await _migrate(owner);
    await _writes;
    return (await (await _db).query(
      'snapshots',
      where: 'owner = ?',
      whereArgs: [owner],
    )).isNotEmpty;
  }

  Future<List<JournalEntryModel>> read(String owner) async {
    await _migrate(owner);
    await _writes;
    final rows = await (await _db).query(
      'entries',
      where: 'owner = ?',
      whereArgs: [owner],
      orderBy: 'createdAt DESC',
    );
    return [
      for (final row in rows)
        JournalEntryModel.fromJson(
          jsonDecode(
            await cipher.open(
              owner,
              row['data'] as String,
              purpose: 'journal:${row['id']}',
            ),
          ) as Map<String, dynamic>,
        ),
    ];
  }

  Future<void> replace(
    String owner,
    List<JournalEntryModel> entries, {
    required int expectedRevision,
  }) => _write((db) async {
    _ensureOwner(owner);
    if (revision(owner) != expectedRevision) return;
    final rows = [for (final entry in entries) await _row(owner, entry)];
    await db.transaction((txn) async {
      await txn.delete('entries', where: 'owner = ?', whereArgs: [owner]);
      for (final row in rows) {
        await txn.insert('entries', row);
      }
      await txn.insert('snapshots', {
        'owner': owner,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  });
  Future<void> upsert(String owner, JournalEntryModel entry) {
    _revisions[owner] = revision(owner) + 1;
    return _write((db) async {
      _ensureOwner(owner);
      final row = await _row(owner, entry);
      await db.insert(
        'entries',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert('snapshots', {
        'owner': owner,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  Future<void> delete(String owner, String id) {
    _revisions[owner] = revision(owner) + 1;
    return _write((db) async {
      _ensureOwner(owner);
      await db.delete(
        'entries',
        where: 'owner = ? AND id = ?',
        whereArgs: [owner, id],
      );
      await db.insert('snapshots', {
        'owner': owner,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  Future<Map<String, dynamic>?> readDraft(String owner, String id) async {
    await _writes;
    final rows = await (await _db).query(
      'drafts',
      where: 'owner = ? AND id = ?',
      whereArgs: [owner, id],
    );
    if (rows.isEmpty) return null;
    return jsonDecode(
      await cipher.open(
        owner,
        rows.single['data'] as String,
        purpose: 'draft:$id',
      ),
    ) as Map<String, dynamic>;
  }

  Future<void> saveDraft(String owner, String id, Map<String, dynamic> value) =>
      _write((db) async {
        _ensureOwner(owner);
        await db.insert('drafts', {
          'owner': owner,
          'id': id,
          'data': await cipher.seal(
            owner,
            jsonEncode(value),
            purpose: 'draft:$id',
          ),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
  Future<void> deleteDraft(String owner, String id) => _write(
    (db) => db.delete(
      'drafts',
      where: 'owner = ? AND id = ?',
      whereArgs: [owner, id],
    ),
  );
  Future<void> deleteOwner(String owner) {
    _removedOwners.add(owner);
    _revisions[owner] = revision(owner) + 1;
    return _write(
      (db) => db.transaction((txn) async {
        for (final table in ['entries', 'drafts', 'snapshots']) {
          await txn.delete(table, where: 'owner = ?', whereArgs: [owner]);
        }
      }),
    );
  }

  Future<void> close() async {
    await _writes;
    if (_database != null) await (await _database!).close();
  }
}
