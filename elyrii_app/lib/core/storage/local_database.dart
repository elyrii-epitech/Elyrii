import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as paths;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite/sqflite.dart' as mobile;

/// Native iOS/Android storage. Tests inject SQLite FFI through the same API.
abstract final class LocalDatabase {
  @visibleForTesting
  static DatabaseFactory? factoryOverride;
  @visibleForTesting
  static String Function(String name)? pathOverride;
  static DatabaseFactory get factory =>
      factoryOverride ?? mobile.databaseFactory;
  static Future<String> path(String name, DatabaseFactory factory) async =>
      pathOverride?.call(name) ??
      paths.join(await factory.getDatabasesPath(), name);
}
