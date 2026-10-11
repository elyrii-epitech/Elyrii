// Audit evidence for frontend commit 4b90d68. These tests describe observed
// defects; passing them confirms the reproductions, not acceptable behavior.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/services/theme_provider.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/core/storage/local_database.dart';
import 'package:elyrii_app/core/theme/app_colors.dart';
import 'package:elyrii_app/features/auth/presentation/widgets/glass_auth_text_field.dart';
import 'package:elyrii_app/features/chatbot/presentation/widgets/crisis_detection_banner.dart';
import 'package:elyrii_app/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_repository.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_store.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';
import 'package:elyrii_app/features/journal/presentation/widgets/glass_journal_card.dart';
import 'package:elyrii_app/features/gamification/data/repositories/gamification_repository.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';

class AuditStorage extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => 'audit-token';
  @override
  Future<String?> getUserId() async => 'audit-user';
}

Map<String, dynamic> noteJson() => JournalEntryModel(
  id: 'note-1',
  userId: 'audit-user',
  title: 'Note privée',
  content: 'Contenu audit synthétique',
  createdAt: DateTime.utc(2026, 10, 10),
  updatedAt: DateTime.utc(2026, 10, 10),
).toCacheJson();

class RefusingJournalStore extends JournalStore {
  RefusingJournalStore(SecureStorageService storage)
    : super(cipher: ContentCipher(storage));
  @override
  Future<void> upsert(String owner, JournalEntryModel entry) async {
    throw const FileSystemException('Synthetic disk-full error');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    LocalDatabase.factoryOverride = databaseFactoryFfi;
    LocalDatabase.pathOverride = (_) => inMemoryDatabasePath;
  });

  test(
    'JOURNAL: delayed GET hides a successfully created note in memory',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final client = ApiClient(
        storage: AuditStorage(),
        client: MockClient((r) async {
          if (r.method == 'GET') {
            started.complete();
            return response.future;
          }
          return http.Response(jsonEncode(noteJson()), 200);
        }),
      );
      final repository = JournalRepository(client: client);
      final provider = JournalProvider(repository: repository)
        ..onUserChanged('audit-user');
      final load = provider.loadEntries();
      await started.future;
      expect(
        await provider.createEntry(content: 'Contenu audit synthétique'),
        isNotNull,
      );
      expect(provider.entries, hasLength(1));
      response.complete(http.Response('[]', 200));
      await load;
      expect(provider.entries, isEmpty);
      expect(await repository.getCachedEntries(), hasLength(1));
      print(
        'EVIDENCE: UI=0 notes, encrypted local cache=1 note after stale GET',
      );
      provider.dispose();
      await repository.store.close();
      client.dispose();
    },
  );

  test(
    'JOURNAL: delayed GET shows a successfully deleted note again',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final client = ApiClient(
        storage: AuditStorage(),
        client: MockClient((r) async {
          if (r.method == 'GET') {
            started.complete();
            return response.future;
          }
          return http.Response('{}', 200);
        }),
      );
      final repository = JournalRepository(client: client);
      await repository.store.upsert(
        'audit-user',
        JournalEntryModel.fromJson(noteJson()),
      );
      final provider = JournalProvider(repository: repository)
        ..onUserChanged('audit-user');
      final load = provider.loadEntries();
      await started.future;
      expect(await provider.deleteEntry('note-1'), isTrue);
      response.complete(http.Response(jsonEncode([noteJson()]), 200));
      await load;
      expect(provider.entries.single.id, 'note-1');
      expect(await repository.getCachedEntries(), isEmpty);
      print(
        'EVIDENCE: UI=1 deleted note, encrypted local cache=0 notes after stale GET',
      );
      provider.dispose();
      await repository.store.close();
      client.dispose();
    },
  );

  test(
    'JOURNAL: local cache failure turns server success into retryable failure',
    () async {
      var remoteCreates = 0;
      final storage = AuditStorage();
      final client = ApiClient(
        storage: storage,
        client: MockClient((r) async {
          remoteCreates++;
          return http.Response(jsonEncode(noteJson()), 200);
        }),
      );
      final repository = JournalRepository(
        client: client,
        store: RefusingJournalStore(storage),
      );
      final provider = JournalProvider(repository: repository)
        ..onUserChanged('audit-user');
      expect(await provider.createEntry(content: 'La même note'), isNull);
      expect(await provider.createEntry(content: 'La même note'), isNull);
      expect(remoteCreates, 2);
      expect(provider.error, contains('disk-full'));
      print(
        'EVIDENCE: 2 accepted server POSTs, 0 acknowledged saves in frontend',
      );
      provider.dispose();
      await repository.store.close();
      client.dispose();
    },
  );

  test(
    'PRIVACY: dashboard persists mood and challenges as readable JSON',
    () async {
      final payload = {
        'latestMood': 'anxious',
        'stats': {
          'rangeDays': 30,
          'moodDistribution': [
            {'moodType': 'anxious', 'count': 7},
          ],
        },
        'challenges': {
          'active': [
            {'title': 'Objectif personnel synthétique'},
          ],
          'pending': [],
        },
      };
      final client = ApiClient(
        storage: AuditStorage(),
        client: MockClient(
          (r) async => http.Response(jsonEncode(payload), 200),
        ),
      );
      final repository = DashboardRepository(client: client)
        ..onUserChanged(userId: 'audit-user');
      await repository.getDashboard();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cache_dashboard_data_audit-user_30d')!;
      expect(raw, contains('anxious'));
      expect(raw, contains('Objectif personnel synthétique'));
      print(
        'EVIDENCE: dashboard mood/distribution/challenge contents readable in SharedPreferences',
      );
      client.dispose();
    },
  );

  test(
    'DEMO: opening journal against a rejecting gateway clears demo session',
    () async {
      final storage = SecureStorageService();
      final calls = <String>[];
      final app = AppDependencies(
        storage: storage,
        api: ApiClient(
          storage: storage,
          client: MockClient((r) async {
            calls.add('${r.method} ${r.url.path}');
            return http.Response('{"message":"Unauthorized demo token"}', 401);
          }),
        ),
        theme: ThemeProvider(),
      );
      await app.auth.startDemoSession();
      await app.chat.ready;
      await app.mascot.flushed;
      expect(app.auth.isDemoSession, isTrue);
      await app.journal.loadEntries();
      expect(calls, contains('GET /journal'));
      expect(app.auth.isAuthenticated, isFalse);
      print(
        'EVIDENCE: demo sends GET /journal; server 401 signs the visitor out',
      );
      app.dispose();
      await app.chat.flushed;
      await app.history.close();
      await app.journalStore.close();
    },
  );

  test('SAFETY: lexical crisis heuristic gives everyday positives and an intent negative', () {
    expect(containsCrisisKeyword('Je vais sauter à la corde'), isTrue);
    expect(containsCrisisKeyword('Je vais avaler mon petit déjeuner'), isTrue);
    expect(containsCrisisKeyword('Je veux en finir avec tout'), isFalse);
    print(
      'EVIDENCE: sauter/avaler => alert; "Je veux en finir avec tout" => no alert',
    );
  });

  test(
    'CHALLENGES: delayed GET restores a successfully rejected proposal',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final proposal = {
        'id': 'proposal-1',
        'userId': 'audit-user',
        'challengeId': 'template-1',
        'status': 'PENDING',
        'createdAt': '2026-10-10T00:00:00Z',
        'updatedAt': '2026-10-10T00:00:00Z',
      };
      final client = ApiClient(
        storage: AuditStorage(),
        client: MockClient((r) async {
          if (r.method == 'POST')
            return http.Response(
              jsonEncode({...proposal, 'status': 'REJECTED'}),
              200,
            );
          if (r.url.path.contains('proposals')) {
            started.complete();
            return response.future;
          }
          return http.Response('[]', 200);
        }),
      );
      final provider = GamificationProvider(
        repository: GamificationRepository(client: client),
      );
      provider.onUserChanged(userId: 'audit-user', isDemo: false);
      final load = provider.loadAll();
      await started.future;
      expect(await provider.rejectChallenge('proposal-1'), isTrue);
      expect(provider.proposals, isEmpty);
      response.complete(http.Response(jsonEncode([proposal]), 200));
      await load;
      expect(provider.proposals.single.id, 'proposal-1');
      print(
        'EVIDENCE: UI restores proposal-1 as PENDING after server accepted REJECTED',
      );
      provider.dispose();
      client.dispose();
    },
  );

  testWidgets('JOURNAL: UTC timestamp is displayed without local conversion', (
    tester,
  ) async {
    final date = DateTime.parse('2026-10-09T23:30:00Z');
    expect(date.isUtc, isTrue);
    expect(
      date.toLocal().day,
      10,
      reason: 'Run the evidence suite with TZ=Europe/Paris',
    );
    final entry = JournalEntryModel(
      id: 'utc-note',
      userId: 'audit-user',
      title: 'Date synthétique',
      createdAt: date,
      updatedAt: date,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlassJournalCard(entry: entry, onTap: () {}),
        ),
      ),
    );
    expect(find.text(' · 23:30'), findsOneWidget);
    print(
      'EVIDENCE: card renders 9 Oct 23:30 UTC instead of local 10 Oct 01:30 in Europe/Paris',
    );
  });

  test('CONTRAST: direct success/error text colors miss 4.5:1 on the relevant surfaces', () {
    double ratio(Color fg, Color bg) {
      final a = fg.computeLuminance(), b = bg.computeLuminance();
      return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
    }

    final success = ratio(AppColors.success, Colors.white);
    final error = ratio(AppColors.error, AppColors.scaffoldDark);
    expect(success, lessThan(4.5));
    expect(error, lessThan(4.5));
    print(
      'EVIDENCE: success on white=${success.toStringAsFixed(2)}:1; fixed error on dark scaffold=${error.toStringAsFixed(2)}:1',
    );
  });

  testWidgets(
    'AUTH: empty password field and visibility icon have no semantic names or autofill',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassAuthTextField(
              controller: controller,
              hint: '',
              prefixIcon: Icons.lock_outline,
              isPassword: true,
            ),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofillHints, isEmpty);
      expect(field.onSubmitted, isNull);
      expect(
        tester.getSemantics(find.byType(EditableText)).getSemanticsData().label,
        isEmpty,
      );
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).tooltip,
        isNull,
      );
      print(
        'EVIDENCE: password semantic label="", visibility tooltip=null, autofillHints=[], submit callback=null',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      semantics.dispose();
    },
  );
}
