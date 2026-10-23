import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:elyrii_app/core/storage/local_database.dart';
import 'package:elyrii_app/core/export/private_export.dart';

Future<void> testExecutable(FutureOr<void> Function() main) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  sqfliteFfiInit();
  LocalDatabase.factoryOverride = databaseFactoryFfi;
  LocalDatabase.pathOverride = (_) => inMemoryDatabasePath;
  final temp = await Directory.systemTemp.createTemp('elyrii-tests-');
  PrivateExport.temporaryDirectory = () async => temp;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => temp.path,
      );
  try {
    await main();
  } finally {
    await temp.delete(recursive: true);
  }
}
