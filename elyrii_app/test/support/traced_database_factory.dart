import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Counts actual rows crossing the SQLite API on the measured production path.
class TracedDatabaseFactory implements DatabaseFactory {
  int rows = 0;
  @override
  Future<Database> openDatabase(
    String path, {
    OpenDatabaseOptions? options,
  }) async => _TraceDatabase(
    await databaseFactoryFfi.openDatabase(path, options: options),
    this,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TraceDatabase implements Database {
  final Database delegate;
  final TracedDatabaseFactory trace;
  _TraceDatabase(this.delegate, this.trace);
  @override
  bool get isOpen => delegate.isOpen;
  @override
  String get path => delegate.path;
  @override
  Future<void> close() => delegate.close();
  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) =>
      delegate.execute(sql, arguments);
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) => delegate.transaction(action, exclusive: exclusive);
  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final rows = await delegate.rawQuery(sql, arguments);
    trace.rows += rows.length;
    return rows;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final rows = await delegate.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    trace.rows += rows.length;
    return rows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
