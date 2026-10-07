import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:elyrii_app/core/storage/local_database.dart';

Future<void> testExecutable(FutureOr<void> Function() main) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  sqfliteFfiInit();
  LocalDatabase.factoryOverride = databaseFactoryFfi;
  LocalDatabase.pathOverride = (_) => inMemoryDatabasePath;
  await main();
}
