import 'dart:convert';
import 'dart:io';

import 'package:elyrii_app/core/diagnostics/app_diagnostics.dart';
import 'package:elyrii_app/core/export/private_export.dart';
import 'package:elyrii_app/core/media/avatar_files.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('owned avatar cleanup never removes the source image or another account photo', () async {
    SharedPreferences.setMockInitialValues({});
    final gallery = await Directory.systemTemp.createTemp('fixture-gallery-');
    addTearDown(() => gallery.delete(recursive: true));
    final original = File('${gallery.path}/source.jpg');
    await original.writeAsBytes([1, 2, 3]);
    final first = await AvatarFiles.adopt(original.path, 'fixture-owner-a');
    final second = await AvatarFiles.adopt(original.path, 'fixture-owner-b');
    expect(first, isNot(original.path));
    await AvatarFiles.release(original.path);
    expect(await original.exists(), isTrue);
    await AvatarFiles.deleteOwner('fixture-owner-a');
    expect(await File(first).exists(), isFalse);
    expect(await File(second).exists(), isTrue);
    expect(await original.exists(), isTrue);
    await AvatarFiles.deleteOwner('fixture-owner-b');
  });

  testWidgets(
    'a changed account cannot open sharing and its prepared plaintext file is removed',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Export fixture'))),
      );
      final context = tester.element(find.byType(Scaffold));
      final result = await tester.runAsync(() async {
        final result = await PrivateExport.share(
          context,
          {'privateFixture': 'owned text'},
          title: 'Fixture export',
          isCurrentOwner: () => false,
        );
        final root = await PrivateExport.temporaryDirectory();
        final files = await Directory('${root.path}/elyrii-exports')
            .list()
            .toList();
        expect(files, isEmpty);
        return result;
      });
      expect(result!.status, ShareResultStatus.dismissed);
    },
  );

  test(
    'technical diagnostics expire, remain bounded and omit exception payloads',
    () async {
      SharedPreferences.setMockInitialValues({
        'technical_diagnostics_v1': jsonEncode([
          {
            'event': 'expired',
            'category': 'StateError',
            'at': DateTime.now()
                .subtract(const Duration(days: 8))
                .toUtc()
                .toIso8601String(),
          },
        ]),
      });
      PackageInfo.setMockInitialValues(
        appName: 'Elyrii',
        packageName: 'fixture',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      await AppDiagnostics.initialize();
      for (var i = 0; i < 101; i++) {
        AppDiagnostics.record(
          'fixture_event',
          StateError('secret-payload-must-not-be-exported'),
        );
      }
      final data = await AppDiagnostics.export();
      expect((data['events'] as List).length, 100);
      expect(jsonEncode(data), isNot(contains('secret-payload')));
      expect(jsonEncode(data), isNot(contains('expired')));
      await AppDiagnostics.initialize();
      expect(((await AppDiagnostics.export())['events'] as List).length, 100);
    },
  );
}
