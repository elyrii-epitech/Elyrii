import 'dart:async';

import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/dashboard/data/models/dashboard_models.dart';
import 'package:elyrii_app/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:elyrii_app/features/reviews/presentation/pages/reviews_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _Repository extends DashboardRepository {
  _Repository() : super(client: ApiClient(storage: SecureStorageService()));
  final calls = <String>[];
  final pending = <Completer<DashboardStats>>[];
  @override
  Future<DashboardStats> getStats({String range = '30d'}) {
    calls.add(range);
    final result = Completer<DashboardStats>();
    pending.add(result);
    return result.future;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));
  testWidgets(
    'injected repository handles periods, stale results and visible errors',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: ReviewsPage(
              repository: repository,
              now: () => DateTime(2026, 10, 23),
            ),
          ),
        ),
      );
      expect(repository.calls, ['7d']);
      await tester.tap(find.text('Mois'));
      await tester.pump();
      expect(repository.calls, ['7d', '23d']);
      repository.pending[0].complete(DashboardStats.empty());
      repository.pending[1].completeError(StateError('offline'));
      await tester.pump();
      expect(
        find.text('Impossible de charger le bilan pour le moment.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Trimestre'));
      await tester.pump();
      repository.pending[2].complete(DashboardStats.empty());
      await tester.pump();
      expect(repository.calls.last, '90d');
      expect(
        find.text('Impossible de charger le bilan pour le moment.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
