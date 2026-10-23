import 'dart:async';

import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/services/theme_provider.dart';
import 'package:elyrii_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Dependencies extends AppDependencies {
  _Dependencies()
    : super(
        storage: SecureStorageService(),
        api: ApiClient(storage: SecureStorageService()),
        theme: ThemeProvider(),
      );
  bool wasDisposed = false;
  @override
  void dispose() {
    wasDisposed = true;
    super.dispose();
  }
}

void main() {
  testWidgets(
    'bootstrap shows retry after initialization fails and releases late services',
    (tester) async {
      final late = Completer<AppDependencies>();
      var attempts = 0;
      await tester.pumpWidget(
        ApplicationBootstrap(
          initialize: () {
            attempts++;
            if (attempts == 1) {
              return Future.error(StateError('storage unavailable'));
            }
            return late.future;
          },
        ),
      );
      await tester.pump();
      expect(find.text('Réessayer'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      expect(attempts, 2);
      await tester.pumpWidget(const SizedBox());
      final services = _Dependencies();
      late.complete(services);
      await tester.pump();
      expect(services.wasDisposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
