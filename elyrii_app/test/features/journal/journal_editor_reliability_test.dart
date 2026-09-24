import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_repository.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';
import 'package:elyrii_app/features/journal/presentation/widgets/journal_editor_sheet.dart';

final _entry = JournalEntryModel(
  id: 'note',
  userId: 'account-a',
  title: 'Note',
  content: 'Initial',
  createdAt: DateTime(2026, 9, 19),
  updatedAt: DateTime(2026, 9, 19),
);

class _Repository extends JournalRepository {
  _Repository() : super(client: ApiClient(storage: SecureStorageService()));
  bool fail = false;
  Completer<void>? gate;
  final List<String?> saved = [];
  @override
  Future<JournalEntryModel> updateEntry({
    required String id,
    String? title,
    String? content,
    String? mood,
  }) async {
    saved.add(content);
    await gate?.future;
    if (fail) throw const SocketException('Offline');
    return _entry;
  }
}

Future<void> _mount(WidgetTester tester, _Repository repository) async {
  final provider = JournalProvider(repository: repository);
  final dashboard = DashboardProvider(
    apiClient: ApiClient(storage: SecureStorageService()),
  );
  addTearDown(provider.dispose);
  addTearDown(dashboard.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: dashboard,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: JournalEditorSheet(provider: provider, entry: _entry),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'failed autosave retains the draft and does not claim it is saved',
    (tester) async {
      final repository = _Repository()..fail = true;
      await _mount(tester, repository);
      await tester.enterText(find.byType(TextField).last, 'Mon brouillon');
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(repository.saved, ['Mon brouillon']);
      expect(find.text('Échec de sauvegarde — réessaie'), findsOneWidget);
      expect(find.text('Sauvegardé'), findsNothing);
      expect(find.text('Mon brouillon'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'typing during a save queues the new revision without parallel requests',
    (tester) async {
      final gate = Completer<void>();
      final repository = _Repository()..gate = gate;
      await _mount(tester, repository);
      await tester.enterText(find.byType(TextField).last, 'Version un');
      await tester.pump(const Duration(seconds: 2));
      await tester.enterText(find.byType(TextField).last, 'Version deux');
      await tester.pump(const Duration(seconds: 2));
      expect(repository.saved, ['Version un']);
      gate.complete();
      await tester.pump();
      expect(find.text('Sauvegardé'), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(repository.saved, ['Version un', 'Version deux']);
      expect(find.text('Sauvegardé'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
