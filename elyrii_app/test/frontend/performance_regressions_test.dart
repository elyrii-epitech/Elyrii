import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_session.dart';
import 'package:elyrii_app/features/chatbot/data/repositories/chat_history_service.dart';
import 'package:elyrii_app/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';
import 'package:elyrii_app/features/chatbot/presentation/widgets/chat_message_bubble.dart';
import 'package:elyrii_app/features/dashboard/data/models/dashboard_models.dart';
import 'package:elyrii_app/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/traced_database_factory.dart';

class _Storage extends SecureStorageService {
  @override
  Future<String?> getUserId() async => 'alice';
  @override
  Future<String?> getAccessToken() async => 'fixture';
}

class _History extends ChatHistoryService {
  final List<ChatMessage> all;
  late final session = ChatSession(
    id: 'session',
    title: 'Fixture',
    createdAt: all.first.timestamp,
    updatedAt: all.last.timestamp,
    messages: const [],
    messageCount: all.length,
  );
  _History(int count)
    : all = List.generate(
        count,
        (i) => ChatMessage(
          id: 'm$i',
          content: 'Message-$i with selectable content.',
          isUser: i.isEven,
          timestamp: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
        ),
      );
  @override
  Future<List<ChatSession>> sessions(
    String owner, {
    ChatSession? before,
  }) async => [session];
  @override
  Future<List<ChatMessage>> messages(
    String owner,
    String sessionId, {
    String? beforeId,
  }) async {
    final end = beforeId == null
        ? all.length
        : all.indexWhere((m) => m.id == beforeId);
    return all.sublist(math.max(0, end - ChatHistoryService.pageSize), end);
  }

  @override
  Future<bool> hasLegacyHistory() async => false;
  @override
  Future<void> close() async {}
}

class _RacingDashboard extends DashboardRepository {
  final cached = Completer<DashboardData?>();
  final remote = Completer<DashboardData>();
  _RacingDashboard(ApiClient client) : super(client: client);
  @override
  Future<DashboardData?> getCachedDashboard({
    String? scope,
    String range = '30d',
  }) => cached.future;
  @override
  Future<DashboardData> getDashboard({String range = '30d'}) => remote.future;
}

Widget _chatHost(ChatbotProvider provider) => ChangeNotifierProvider.value(
  value: provider,
  child: MaterialApp(theme: AppTheme.lightTheme, home: const ChatbotPage()),
);

Finder _message(String content) => find.byWidgetPredicate(
  (widget) => widget is ChatMessageBubble && widget.message == content,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'reopening encrypted chat reads a bounded page instead of the full history',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'elyrii-history-budget-',
      );
      final path = '${dir.path}/chat.db';
      final history = ChatHistoryService(
        factory: databaseFactoryFfi,
        path: path,
      );
      final session = ChatSession.create();
      for (var i = 0; i < 200; i++) {
        await history.append(
          'alice',
          session,
          ChatMessage.user('Private message $i'),
        );
      }
      await history.sessions('alice');
      await history.close();
      final trace = TracedDatabaseFactory();
      final reopened = ChatHistoryService(factory: trace, path: path);
      try {
        expect((await reopened.sessions('alice')).single.messageCount, 200);
        expect(await reopened.messages('alice', session.id), hasLength(50));
        expect(
          trace.rows,
          lessThan(100),
          reason: 'Reopen must not scan/decode every stored message',
        );
      } finally {
        await reopened.close();
        await dir.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'opening a long chat builds a bounded viewport at the newest message',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final history = _History(1050);
      final provider = ChatbotProvider(
        storage: _Storage(),
        history: history,
        initialOwner: 'alice',
      );
      await provider.ready;
      for (var page = 1; page < 20; page++) {
        await provider.loadOlderMessages();
      }
      expect(provider.messages.length, 1000);
      await tester.pumpWidget(_chatHost(provider));
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byType(ListView));
      expect(
        viewport.overlaps(tester.getRect(_message(history.all.last.content))),
        isTrue,
      );
      expect(find.byType(ChatMessageBubble).evaluate().length, lessThan(30));
      expect(
        tester.getCenter(_message(history.all[1048].content)).dy,
        lessThan(tester.getCenter(_message(history.all.last.content)).dy),
      );
      // Selectable assistant messages retain their copy controls, but editors
      // and selection controllers remain bounded to the visible viewport.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(EditableText).evaluate().length, lessThan(20));
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    },
  );

  testWidgets('loading older messages preserves the visible reading position', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final history = _History(150);
    final provider = ChatbotProvider(
      storage: _Storage(),
      history: history,
      initialOwner: 'alice',
    );
    await provider.ready;
    await tester.pumpWidget(_chatHost(provider));
    await tester.pumpAndSettle();
    final older = find.byKey(const ValueKey('chat-older-page'));
    await tester.scrollUntilVisible(
      older,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
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
    final before = tester.getCenter(_message(content)).dy;
    await tester.tap(older);
    await tester.pumpAndSettle();
    expect(provider.messages.length, 100);
    expect(tester.getCenter(_message(content)).dy, closeTo(before, 1));
    expect(provider.messages.map((m) => m.id).toSet().length, 100);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('assistant text still supports selection and copying', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.hasStrings') return {'value': false};
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final history = _History(2);
    final provider = ChatbotProvider(
      storage: _Storage(),
      history: history,
      initialOwner: 'alice',
    );
    await provider.ready;
    await tester.pumpWidget(_chatHost(provider));
    await tester.pumpAndSettle();
    await tester.longPress(find.text(history.all.last.content));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(copied, isNotEmpty);
    expect(history.all.last.content, contains(copied!));
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'dashboard shows its encrypted cache while the refresh is pending',
    () async {
      final response = Completer<http.Response>();
      var reads = 0;
      final api = ApiClient(
        storage: _Storage(),
        client: MockClient((_) async {
          if (++reads > 1) return response.future;
          return http.Response(
            '{"latestMood":"happy","stats":{"streak":7}}',
            200,
          );
        }),
      );
      addTearDown(api.dispose);
      final repository = DashboardRepository(client: api)
        ..onUserChanged(userId: 'alice');
      await repository.getDashboard();
      final provider = DashboardProvider(repository: repository)
        ..onUserChanged(userId: 'alice');
      addTearDown(provider.dispose);
      final cached = Completer<void>();
      provider.addListener(() {
        if (provider.currentStreak == 7 &&
            !provider.isLoading &&
            !cached.isCompleted) {
          cached.complete();
        }
      });
      final refresh = provider.loadDashboardData();
      await cached.future.timeout(const Duration(seconds: 2));
      expect(response.isCompleted, isFalse);
      expect(provider.cachedAt, isNotNull);
      response.complete(
        http.Response('{"latestMood":"happy","stats":{"streak":9}}', 200),
      );
      await refresh;
      expect(provider.currentStreak, 9);
      expect(provider.cachedAt, isNull);
    },
  );

  test(
    'a late dashboard cache cannot replace a faster fresh response',
    () async {
      final api = ApiClient(storage: _Storage());
      addTearDown(api.dispose);
      final repository = _RacingDashboard(api);
      final provider = DashboardProvider(repository: repository)
        ..onUserChanged(userId: 'alice');
      addTearDown(provider.dispose);
      final refresh = provider.loadDashboardData();
      repository.remote.complete(
        DashboardData.fromJson({
          'stats': {'streak': 9},
        }),
      );
      await refresh;
      repository.cached.complete(
        DashboardData.fromJson({
          'stats': {'streak': 7},
        }, cachedAt: DateTime.now()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(provider.currentStreak, 9);
      expect(provider.cachedAt, isNull);
    },
  );

  test('account changes discard both pending dashboard sources', () async {
    final api = ApiClient(storage: _Storage());
    addTearDown(api.dispose);
    final repository = _RacingDashboard(api);
    final provider = DashboardProvider(repository: repository)
      ..onUserChanged(userId: 'alice');
    addTearDown(provider.dispose);
    final refresh = provider.loadDashboardData();
    provider.onUserChanged(userId: 'bob');
    repository.cached.complete(
      DashboardData.fromJson({
        'stats': {'streak': 7},
      }),
    );
    repository.remote.complete(
      DashboardData.fromJson({
        'stats': {'streak': 9},
      }),
    );
    await refresh;
    expect(provider.currentStreak, 0);
    expect(provider.cachedAt, isNull);
  });

  test('garden freshness expires, is account scoped, and never skips explicit refresh or commands', () async {
    var now = DateTime.utc(2026, 10, 14);
    var reads = 0;
    final api = ApiClient(
      storage: _Storage(),
      client: MockClient((request) async {
        if (request.method == 'GET') {
          reads++;
          return http.Response('[]', 200);
        }
        return http.Response(
          '{"id":"assignment","userId":"alice","challengeId":"fixture","status":"ACTIVE","createdAt":"2026-10-14T00:00:00Z","updatedAt":"2026-10-14T00:00:00Z"}',
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    final provider = GamificationProvider(client: api, now: () => now)
      ..onUserChanged(userId: 'alice');
    addTearDown(provider.dispose);
    await provider.loadAll();
    expect(reads, 4);
    await provider.loadAll();
    expect(reads, 4);
    await provider.loadAll(force: true);
    expect(reads, 8);
    expect(await provider.startChallenge('fixture'), isTrue);
    expect(reads, 12);
    now = now.add(const Duration(seconds: 31));
    await provider.loadAll();
    expect(reads, 16);
    provider.onUserChanged(userId: 'bob');
    await provider.loadAll();
    expect(reads, 20);
  });
}
