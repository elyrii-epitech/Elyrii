// Run explicitly; these benchmarks are outside the default regression suite.
// Flutter VM/widget timings are host measurements, not native GPU/FPS results.
// Opt-in flutter_test file outside test/; plugin mocks are intentional here.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:elyrii_app/app/launch/elyrii_launch.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_session.dart';
import 'package:elyrii_app/features/chatbot/data/repositories/chat_history_service.dart';
import 'package:elyrii_app/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';
import 'package:elyrii_app/features/chatbot/presentation/widgets/chat_message_bubble.dart';
import 'package:elyrii_app/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_store.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/gamification/presentation/pages/challenges_page.dart';
import 'package:elyrii_app/features/journal/presentation/pages/journal_page.dart';
import 'package:elyrii_app/features/coach/presentation/pages/coach_page.dart';
import 'package:elyrii_app/features/meditation/presentation/pages/meditation_page.dart';
import 'package:elyrii_app/features/settings/pages/settings_page.dart';
import 'package:elyrii_app/features/reviews/presentation/pages/reviews_page.dart';
import 'package:elyrii_app/features/mascot/presentation/pages/mascot_customization_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test/support/accessibility_fixture.dart' as layout;
import '../test/support/traced_database_factory.dart';

import 'package:elyrii_app/features/auth/presentation/pages/login_page.dart';
import 'package:elyrii_app/features/auth/presentation/pages/register_page.dart';
import 'package:elyrii_app/features/auth/presentation/pages/password_reset_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/profile_setup_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/edit_profile_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/avatar_picker_page.dart';

const _iterations = 9;
const _widgetWarmups = 3;
const _widgetIterations = 9;
const _owner = 'performance-fixture';
const _networkDelay = Duration(milliseconds: 200);
const _credentialDelay = Duration(milliseconds: 20);
final _results = <String, Object>{};

Map<String, Object> _distribution(List<double> values) {
  final sorted = [...values]..sort();
  double percentile(double p) =>
      sorted[math.min(sorted.length - 1, (sorted.length * p).ceil() - 1)];
  return {'samples': values, 'median': percentile(.5), 'p95': percentile(.95)};
}

void _record(String name, List<double> times, [Map<String, Object>? work]) {
  _results[name] = {
    'sample_count': times.length,
    'milliseconds': _distribution(times),
    ...?work,
  };
  // Intentionally machine-readable and contains synthetic data only.
  // ignore: avoid_print
  print('PERF $name ${jsonEncode(_results[name])}');
}

Future<double> _time(Future<void> Function() action) async {
  final watch = Stopwatch()..start();
  await action();
  return watch.elapsedMicroseconds / 1000;
}

String _validToken() {
  final exp =
      DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/
      1000;
  final payload = base64Url.encode(utf8.encode(jsonEncode({'exp': exp})));
  return 'fixture.$payload.fixture';
}

class _Storage extends SecureStorageService {
  final Duration delay;
  _Storage({this.delay = Duration.zero});
  @override
  Future<String?> getUserId() async {
    await Future<void>.delayed(delay);
    return _owner;
  }

  @override
  Future<String?> getAccessToken() async {
    await Future<void>.delayed(delay);
    return _validToken();
  }
}

class _PagedHistory extends ChatHistoryService {
  final List<ChatMessage> all;
  late final session = ChatSession(
    id: 'fixture-session',
    title: 'Fixture',
    createdAt: all.first.timestamp,
    updatedAt: all.last.timestamp,
    messageCount: all.length,
    messages: const [],
  );
  _PagedHistory(int count)
    : all = List.generate(
        count,
        (i) => ChatMessage(
          id: 'message-$i',
          content: 'Message $i: ${'A calm conversation. ' * (1 + i % 7)}',
          isUser: i.isEven,
          timestamp: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
        ),
      );
  @override
  Future<List<ChatSession>> sessions(
    String owner, {
    ChatSession? before,
  }) async => before == null ? [session] : [];
  @override
  Future<List<ChatMessage>> messages(
    String owner,
    String sessionId, {
    String? beforeId,
  }) async {
    final end = beforeId == null
        ? all.length
        : all.indexWhere((message) => message.id == beforeId);
    return all.sublist(math.max(0, end - ChatHistoryService.pageSize), end);
  }

  @override
  Future<bool> hasLegacyHistory() async => false;
  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Elyrii',
      packageName: 'com.elyrii.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await initializeDateFormatting('fr');
    final fonts = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });
  tearDownAll(() async {
    const output = String.fromEnvironment('PERF_OUTPUT');
    if (output.isEmpty) return;
    final file = File(output);
    await file.parent.create(recursive: true);
    final report = {
      'schema_version': 1,
      'phase': const String.fromEnvironment(
        'PERF_PHASE',
        defaultValue: 'local',
      ),
      'baseline_commit': 'f8f2f174ca3a8c81fe363bfda9417c1ab224565a',
      'runtime': Platform.version,
      'os': Platform.operatingSystem,
      'iterations': _iterations,
      'widget_warmups': _widgetWarmups,
      'scope':
          'Flutter VM JIT + headless widgets; SQLite FFI on temporary disk databases; '
          'real AES-GCM; synthetic content; controlled local HTTP responses. '
          'No OS cold-launch, native WebView/GPU, FPS, energy or production-network claims.',
      'network_delay_ms': _networkDelay.inMilliseconds,
      'credential_delay_ms': _credentialDelay.inMilliseconds,
      'results': _results,
    };
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
  });

  testWidgets('launch gate', (tester) async {
    final elapsed = <double>[];
    for (var i = 0; i < 3; i++) {
      await tester.pumpWidget(
        const MaterialApp(
          home: ElyriiLaunch(child: Scaffold(body: Text('Ready'))),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage(ElyriiLaunchScene.markAsset),
          tester.element(find.byType(ElyriiLaunch)),
        );
      });
      await tester.pump();
      var simulatedMs = 0;
      while (find.byType(ElyriiLaunchScene).evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 16));
        simulatedMs += 16;
        expect(simulatedMs, lessThan(5000));
      }
      elapsed.add(simulatedMs.toDouble());
      await tester.pumpWidget(const SizedBox());
    }
    _record('launch_input_gate', elapsed, {
      'scope': 'Simulated Flutter frame clock after asset decode; animation/input floor only',
    });
  });

  test('credential request', () async {
    final restoration = <double>[];
    final request = <double>[];
    for (var i = 0; i <= _iterations; i++) {
      final storage = _Storage(delay: _credentialDelay);
      final api = ApiClient(
        storage: storage,
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      final auth = AuthProvider(client: api, storage: storage);
      final restored = await _time(auth.restoreLocalSession);
      expect(auth.isAuthenticated, isTrue);
      final loaded = await _time(() async {
        await api.get('https://fixture.invalid/content');
      });
      if (i > 0) {
        restoration.add(restored);
        request.add(loaded);
      }
      auth.dispose();
      api.dispose();
    }
    _record('session_restoration', restoration);
    _record('authenticated_request_credentials', request);
  });

  test('cold chat history', () async {
    final dir = await Directory.systemTemp.createTemp('elyrii-perf-chat-');
    try {
      for (final count in [100, 1000, 10000]) {
        final path = '${dir.path}/chat-$count.db';
        final cipher = ContentCipher(SecureStorageService());
        final seed = ChatHistoryService(
          factory: databaseFactoryFfi,
          path: path,
          cipher: cipher,
        );
        // Establish the schema and completed migration before seeding a
        // representative database containing already-encrypted messages.
        await seed.sessions(_owner);
        await seed.close();
        final db = await databaseFactoryFfi.openDatabase(path);
        final date = DateTime.utc(2026, 1, 1).toIso8601String();
        final batch = db.batch();
        batch.insert('sessions', {
          'owner': _owner,
          'id': 'session',
          'title': await cipher.seal(
            _owner,
            'Fixture',
            purpose: 'chat-title:session',
          ),
          'createdAt': date,
          'updatedAt': date,
          'messageCount': count,
        });
        final body = 'A private synthetic conversation. ' * 32;
        for (var i = 0; i < count; i++) {
          batch.insert('messages', {
            'owner': _owner,
            'sessionId': 'session',
            'id': 'm$i',
            'content': await cipher.seal(
              _owner,
              body,
              purpose: 'chat-message:m$i',
            ),
            'isUser': i % 2,
            'timestamp': date,
            'delivery': 'delivered',
          });
        }
        await batch.commit(noResult: true);
        await db.close();
        final cold = <double>[];
        final older = <double>[];
        final rowCounts = <int>[];
        for (var i = 0; i <= _iterations; i++) {
          final trace = TracedDatabaseFactory();
          final history = ChatHistoryService(
            factory: trace,
            path: path,
            cipher: cipher,
          );
          late List<ChatMessage> first;
          final opening = await _time(() async {
            expect((await history.sessions(_owner)).single.messageCount, count);
            first = await history.messages(_owner, 'session');
          });
          expect(first.length, ChatHistoryService.pageSize);
          final rowsRead = trace.rows;
          final paging = await _time(() async {
            final page = await history.messages(
              _owner,
              'session',
              beforeId: first.first.id,
            );
            expect(page.length, ChatHistoryService.pageSize);
            expect(page.last.id, 'm${count - 51}');
          });
          if (i > 0) {
            cold.add(opening);
            older.add(paging);
            rowCounts.add(rowsRead);
          }
          await history.close();
        }
        _record('chat_reopen_$count', cold, {
          'rows_read': rowCounts,
          'messages_in_database': count,
        });
        _record('chat_older_page_$count', older);
      }
    } finally {
      await dir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('journal page cache', () async {
    final dir = await Directory.systemTemp.createTemp('elyrii-perf-journal-');
    final store = JournalStore(
      cipher: ContentCipher(SecureStorageService()),
      factory: databaseFactoryFfi,
      path: '${dir.path}/journal.db',
    );
    try {
      await store.hasSnapshot(_owner);
      final entries = List.generate(
        100,
        (i) => JournalEntryModel(
          id: 'note-$i',
          userId: _owner,
          title: 'Note $i',
          content: 'A synthetic private journal entry. ' * 32,
          createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final writes = <double>[];
      final reads = <double>[];
      for (var i = 0; i <= _iterations; i++) {
        final write = await _time(
          () => store.mergePage(
            _owner,
            entries,
            expectedRevision: store.revision(_owner),
          ),
        );
        final read = await _time(() async {
          expect(await store.read(_owner, limit: 100), hasLength(100));
        });
        if (i > 0) {
          writes.add(write);
          reads.add(read);
        }
      }
      _record('journal_cache_100_writes', writes);
      _record('journal_cache_100_reads', reads);
    } finally {
      await store.close();
      await dir.delete(recursive: true);
    }
  });

  test('dashboard cached content', () async {
    final firstContent = <double>[];
    final complete = <double>[];
    for (var i = 0; i <= _iterations; i++) {
      SharedPreferences.setMockInitialValues({});
      var requests = 0;
      final api = ApiClient(
        storage: _Storage(),
        client: MockClient((_) async {
          requests++;
          if (requests > 1) await Future<void>.delayed(_networkDelay);
          return http.Response(
            '{"latestMood":"happy","stats":{"streak":7}}',
            200,
          );
        }),
      );
      final repository = DashboardRepository(client: api)
        ..onUserChanged(userId: _owner);
      await repository.getDashboard();
      final provider = DashboardProvider(repository: repository)
        ..onUserChanged(userId: _owner);
      final ready = Completer<double>();
      final watch = Stopwatch()..start();
      provider.addListener(() {
        if (!provider.isLoading &&
            provider.currentStreak == 7 &&
            !ready.isCompleted) {
          ready.complete(watch.elapsedMicroseconds / 1000);
        }
      });
      await provider.loadDashboardData();
      final done = watch.elapsedMicroseconds / 1000;
      final visible = await ready.future;
      if (i > 0) {
        firstContent.add(visible);
        complete.add(done);
      }
      expect(requests, 2);
      provider.dispose();
      api.dispose();
    }
    _record('dashboard_first_cached_content', firstContent);
    _record('dashboard_refresh_complete', complete);
  });

  test('garden revisit', () async {
    final times = <double>[];
    final calls = <int>[];
    for (var i = 0; i <= _iterations; i++) {
      var requests = 0;
      final api = ApiClient(
        storage: _Storage(),
        client: MockClient((_) async {
          requests++;
          await Future<void>.delayed(_networkDelay);
          return http.Response('[]', 200);
        }),
      );
      final provider = GamificationProvider(client: api)
        ..onUserChanged(userId: _owner);
      await provider.loadAll();
      requests = 0;
      final revisit = await _time(provider.loadAll);
      if (i > 0) {
        times.add(revisit);
        calls.add(requests);
      }
      provider.dispose();
      api.dispose();
    }
    _record('garden_revisit', times, {'http_requests': calls});
  });

  testWidgets('long chat viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opens = <double>[];
    final scrolls = <double>[];
    final builds = <int>[];
    final latestVisible = <bool>[];
    final previousHook = debugOnRebuildDirtyWidget;
    var bubbleBuilds = 0;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (element.widget is ChatMessageBubble) bubbleBuilds++;
      previousHook?.call(element, builtOnce);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previousHook);
    for (var i = 0; i < _widgetWarmups + _widgetIterations; i++) {
      final history = _PagedHistory(1050);
      final provider = ChatbotProvider(
        storage: _Storage(),
        history: history,
        initialOwner: _owner,
      );
      await provider.ready;
      // Load 1,000 messages through the production pagination path. Keep one
      // further page available so the leading "older" row is also exercised.
      for (var page = 1; page < 20; page++) {
        await provider.loadOlderMessages();
      }
      expect(provider.messages.length, 1000);
      bubbleBuilds = 0;
      final opening = await _time(() async {
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ChatbotPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });
      final openingBuilds = bubbleBuilds;
      final newest = find.byWidgetPredicate(
        (w) => w is ChatMessageBubble && w.message == history.all.last.content,
      );
      final visible =
          newest.evaluate().isNotEmpty &&
          tester
              .getRect(newest)
              .overlaps(tester.getRect(find.byType(ListView).first));
      // Start both scroll measurements at the actual newest message. Record
      // initial-open failures above; exclude corrective alignment from timing.
      final list = tester.widget<ListView>(find.byType(ListView).first);
      for (var attempt = 0; attempt < 100; attempt++) {
        list.controller!.jumpTo(
          list.reverse ? 0 : list.controller!.position.maxScrollExtent,
        );
        await tester.pump();
        if (newest.evaluate().isNotEmpty &&
            tester
                .getRect(newest)
                .overlaps(tester.getRect(find.byType(ListView).first))) {
          break;
        }
        expect(
          attempt,
          lessThan(99),
          reason: 'Cannot align the scroll fixture to the newest message',
        );
      }
      final scrolling = await _time(() async {
        for (var step = 0; step < 20; step++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, 300));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
      });
      if (i >= _widgetWarmups) {
        opens.add(opening);
        scrolls.add(scrolling);
        builds.add(openingBuilds);
        latestVisible.add(visible);
      }
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    }
    _record('chat_open_1000_loaded', opens, {
      'bubble_builds': builds,
      'latest_visible': latestVisible,
    });
    _record('chat_scroll_20_drags', scrolls, {
      'scope': 'Host wall-clock for widget gesture/layout work; not native frame timings',
    });
  });

  testWidgets('older chat page viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final times = <double>[];
    final preserved = <bool>[];
    final builds = <int>[];
    final previousHook = debugOnRebuildDirtyWidget;
    var bubbleBuilds = 0;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (element.widget is ChatMessageBubble) bubbleBuilds++;
      previousHook?.call(element, builtOnce);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previousHook);
    for (var i = 0; i < _widgetWarmups + _widgetIterations; i++) {
      final history = _PagedHistory(1050);
      final provider = ChatbotProvider(
        storage: _Storage(),
        history: history,
        initialOwner: _owner,
      );
      await provider.ready;
      for (var page = 1; page < 20; page++) {
        await provider.loadOlderMessages();
      }
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ChatbotPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(find.byType(ListView));
      final older = find.text('Messages précédents');
      // Variable-height slivers refine their estimated far edge after layout.
      // Align programmatically outside timing; text-selection gestures must
      // not determine whether this storage/layout fixture reaches the edge.
      for (var attempt = 0; attempt < 100; attempt++) {
        list.controller!.jumpTo(
          list.reverse ? list.controller!.position.maxScrollExtent : 0,
        );
        await tester.pump();
        if (older.evaluate().isNotEmpty) break;
        expect(
          attempt,
          lessThan(99),
          reason: 'Cannot align to the older-page control',
        );
      }
      await tester.ensureVisible(older);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byType(ListView)).deflate(20);
      final anchor = find
          .byType(ChatMessageBubble)
          .evaluate()
          .firstWhere(
            (element) => viewport.contains(
              tester.getCenter(find.byWidget(element.widget)),
            ),
          );
      final content = (anchor.widget as ChatMessageBubble).message;
      final before = tester.getCenter(find.byWidget(anchor.widget)).dy;
      bubbleBuilds = 0;
      final elapsed = await _time(() async {
        await tester.tap(older);
        await tester.pumpAndSettle();
      });
      final same = find.byWidgetPredicate(
        (widget) => widget is ChatMessageBubble && widget.message == content,
      );
      final stays =
          same.evaluate().isNotEmpty &&
          (tester.getCenter(same).dy - before).abs() < 1;
      expect(provider.messages.length, 1050);
      if (i >= _widgetWarmups) {
        times.add(elapsed);
        preserved.add(stays);
        builds.add(bubbleBuilds);
      }
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    }
    _record('chat_older_page_visible_1000', times, {
      'reading_position_preserved': preserved,
      'bubble_builds': builds,
      'scope': 'Host widget time for paging 50 older messages and settling layout; storage represented by a bounded in-memory fixture',
    });
  });

  testWidgets('screen first layout', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = (await tester.runAsync(layout.fixture))!;
    final pages = <String, Widget>{
      'login': const LoginPage(),
      'register': const RegisterPage(),
      'password_reset': const PasswordResetPage(),
      'profile_setup': const ProfileSetupPage(),
      'profile_edit': const EditProfilePage(),
      'avatar': const AvatarPickerPage(),
      'dashboard': const DashboardPage(),
      'garden': const ChallengesPage(),
      'journal': const JournalPage(),
      'meditation': const MeditationPage(),
      'coach': const CoachPage(),
      'chat': const ChatbotPage(),
      'settings': const SettingsPage(),
      'reviews': const ReviewsPage(),
      'mascot': const MascotCustomizationPage(),
    };
    try {
      for (final page in pages.entries) {
        final times = <double>[];
        for (var i = 0; i < _widgetWarmups + _widgetIterations; i++) {
          final elapsed = await _time(() async {
            await tester.pumpWidget(
              layout.host(app, page.value, GlobalKey(), false, 1),
            );
            await tester.pump();
          });
          if (i >= _widgetWarmups) times.add(elapsed);
          expect(tester.takeException(), isNull, reason: page.key);
          // Drain zero-duration flutter_animate timers outside the measured
          // first-frame interval before disposing this page.
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 1));
        }
        _record('screen_first_layout_${page.key}', times, {
          'scope': 'Warm host widget build/layout with demo data and native views mocked; excludes network and route transitions',
        });
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
      layout.visualJournals.remove(app)?.dispose();
      await tester.runAsync(() async {
        app.dispose();
        await app.chat.flushed;
      });
    }
  });
}
