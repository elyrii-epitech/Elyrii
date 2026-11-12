// Non-regression scenarios discovered in the frontend audit.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:elyrii_app/app/router/app_router.dart';
import 'package:elyrii_app/core/constants/avatar_options.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/data/models/user_model.dart';
import 'package:elyrii_app/features/auth/data/repositories/auth_repository.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_session.dart';
import 'package:elyrii_app/features/chatbot/data/repositories/chat_history_service.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';
import 'package:elyrii_app/features/chatbot/presentation/widgets/chat_history_sheet.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_repository.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:elyrii_app/features/meditation/domain/models/meditation_exercises.dart';
import 'package:elyrii_app/features/meditation/presentation/controllers/meditation_controller.dart';
import 'package:elyrii_app/features/meditation/presentation/pages/meditation_session_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/avatar_picker_page.dart';
import 'package:elyrii_app/features/settings/data/settings_repository.dart';
import 'package:elyrii_app/features/settings/models/app_settings.dart';
import 'package:elyrii_app/features/settings/providers/settings_provider.dart';
import 'package:elyrii_app/routes/app_routes.dart';

class MemoryStorage extends SecureStorageService {
  String? token;
  String? owner = 'alice';
  @override
  Future<String?> getUserId() async => owner;
  @override
  Future<String?> getAccessToken() async => token;
  @override
  Future<void> saveAccessToken(String value) async {
    token = value;
  }

  @override
  Future<void> saveUserId(String value) async {
    owner = value;
  }

  @override
  Future<void> clearAuthData() async {
    token = null;
    owner = null;
  }
}

ApiClient dummyClient(MemoryStorage storage) => ApiClient(
  storage: storage,
  client: MockClient((_) async => http.Response('{}', 200)),
);

class PendingAuthRepository extends AuthRepository {
  PendingAuthRepository(MemoryStorage storage)
    : super(client: dummyClient(storage));
  final result = Completer<AuthResult>();
  @override
  Future<AuthResult> login({required String email, required String password}) =>
      result.future;
}

class RacingSettingsRepository extends UserRepository {
  RacingSettingsRepository() : super(client: dummyClient(MemoryStorage()));
  final first = Completer<AppSettings>();
  final second = Completer<AppSettings>();
  int calls = 0;
  @override
  Future<AppSettings> getSettings() async => settings();
  @override
  Future<AppSettings> updateSettings({
    String? themeMode,
    bool? notificationsEnabled,
    bool? hapticsEnabled,
    String? privacyMode,
    String? language,
  }) => calls++ == 0 ? first.future : second.future;
}

AppSettings settings({bool notifications = true, bool haptics = true}) =>
    AppSettings.fromJson({
      'id': 'settings-alice',
      'userId': 'alice',
      'notificationsEnabled': notifications,
      'hapticsEnabled': haptics,
    });

class OldHistory extends ChatHistoryService {
  OldHistory() : super(factory: databaseFactoryFfi);
  @override
  Future<List<ChatSession>> sessions(
    String owner, {
    ChatSession? before,
  }) async => [
    ChatSession(
      id: 'old-session',
      title: 'Ancienne conversation',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now().subtract(const Duration(days: 10)),
      messages: const [],
      messageCount: 1,
    ),
  ];
  @override
  Future<List<ChatMessage>> messages(
    String owner,
    String sessionId, {
    String? beforeId,
  }) async => [];
  @override
  Future<bool> hasLegacyHistory() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  setUpAll(() => initializeDateFormatting('fr'));

  test(
    'une réponse de login tardive ne réouvre pas une session déconnectée',
    () async {
      final storage = MemoryStorage();
      final repository = PendingAuthRepository(storage);
      final auth = AuthProvider(repository: repository, storage: storage);
      final login = auth.login(
        email: 'alice@example.test',
        password: 'fixture',
      );
      await auth.clearLocalSession();
      expect(auth.isAuthenticated, isFalse);
      repository.result.complete(
        const AuthResult(
          token: 'fixture-token',
          user: UserModel(id: 'alice', email: 'alice@example.test'),
          message: 'ok',
        ),
      );
      expect(await login, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(storage.token, isNull);
      auth.dispose();
    },
  );

  test('une authentification sans token est refusée', () async {
    final storage = MemoryStorage();
    final repository = PendingAuthRepository(storage);
    final auth = AuthProvider(repository: repository, storage: storage);
    final login = auth.login(email: 'alice@example.test', password: 'fixture');
    repository.result.complete(const AuthResult(token: '', message: 'ok'));
    expect(await login, isFalse);
    expect(auth.isAuthenticated, isFalse);
    expect(storage.token, isNull);
    auth.dispose();
  });

  test('une note supprimée reste supprimée hors ligne', () async {
    final entry = JournalEntryModel(
      id: 'note-1',
      userId: 'alice',
      title: 'Note',
      content: 'Fixture',
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );
    SharedPreferences.setMockInitialValues({
      'cache_journal_entries_alice': jsonEncode([entry.toCacheJson()]),
    });
    final client = ApiClient(
      storage: MemoryStorage(),
      client: MockClient((r) async {
        if (r.method == 'DELETE') return http.Response('', 204);
        throw const SocketException('Fixture offline');
      }),
    );
    final journal = JournalRepository(client: client);
    await journal.deleteEntry('note-1');
    expect(await journal.getEntries(), isEmpty);
    await journal.store.close();
    client.dispose();
  });

  test(
    'les préférences sont sérialisées sans annuler le dernier choix',
    () async {
      final repository = RacingSettingsRepository();
      final user = UserProvider(repository: repository);
      await user.loadSettings();
      final first = user.updateSettings(notificationsEnabled: false);
      final second = user.updateSettings(hapticsEnabled: false);
      await Future<void>.delayed(Duration.zero);
      expect(repository.calls, 1);
      expect(user.settings!.hapticsEnabled, isFalse);
      repository.first.complete(settings(notifications: false, haptics: true));
      expect(await first, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(repository.calls, 2);
      expect(user.settings!.hapticsEnabled, isFalse);
      repository.second.complete(
        settings(notifications: false, haptics: false),
      );
      expect(await second, isTrue);
      expect(user.settings!.hapticsEnabled, isFalse);
      user.dispose();
    },
  );

  testWidgets(
    'les dates françaises anciennes sont affichables après initialisation',
    (tester) async {
      final chat = ChatbotProvider(
        storage: MemoryStorage(),
        history: OldHistory(),
      );
      await chat.ready;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: chat,
          child: const MaterialApp(home: Scaffold(body: ChatHistorySheet())),
        ),
      );
      final error = tester.takeException();
      expect(error, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      chat.dispose();
    },
  );

  testWidgets('la fin de méditation autorise le retour système', (
    tester,
  ) async {
    final controller = MeditationController()
      ..setExercise(
        MeditationExercises.all.firstWhere((e) => e.id == 'body-scan'),
      )
      ..setDuration(1);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Catalogue')),
        ),
        GoRoute(
          path: '/session',
          builder: (_, _) => MeditationSessionPage(controller: controller),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MascotProvider(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await controller.startSession();
    router.push('/session');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    while (!controller.isFinished) {
      controller.tick();
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final scope = tester.widget<PopScope>(
      find.byWidgetPredicate((w) => w is PopScope).first,
    );
    expect(controller.isFinished, isTrue);
    expect(scope.canPop, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    controller.dispose();
    router.dispose();
  });

  testWidgets('la route avatar conserve la photo transmise dans extra', (
    tester,
  ) async {
    final storage = MemoryStorage();
    final auth = AuthProvider(client: dummyClient(storage), storage: storage);
    final setup = ValueNotifier<bool>(true);
    final source = AppRouter.createRouter(
      authProvider: auth,
      profileSetupDone: setup,
    );
    final route = source.configuration.routes.whereType<GoRoute>().firstWhere(
      (r) => r.path == AppRoutes.avatarPicker,
    );
    final router = GoRouter(
      initialLocation: AppRoutes.avatarPicker,
      initialExtra: kAvatarOptions[1].url,
      routes: [route],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MascotProvider(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    final page = tester.widget<AvatarPickerPage>(find.byType(AvatarPickerPage));
    expect(page.currentPfp, kAvatarOptions[1].url);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    source.dispose();
    setup.dispose();
    auth.dispose();
  });
}
