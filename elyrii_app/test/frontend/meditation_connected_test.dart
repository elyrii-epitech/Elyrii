import 'dart:async';
import 'dart:io';

import 'package:elyrii_app/core/config/api_config.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/network/api_exception.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/meditation/data/repositories/meditation_repository.dart';
import 'package:elyrii_app/features/meditation/domain/models/meditation_exercises.dart';
import 'package:elyrii_app/features/meditation/presentation/controllers/meditation_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// Forward to the real API, then lose its first acknowledgement. This exercises
// actual committed rows and idempotent retries rather than fake server results.
class LostAcknowledgementClient extends http.BaseClient {
  final _transport = http.Client();
  bool loseStart = true, loseCompletion = true;
  Completer<void>? holdStart;
  Completer<void>? startCommitted;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _transport.send(request);
    final start = request.url.path.endsWith('/sessions/start');
    final complete = request.url.path.endsWith('/complete');
    if (response.statusCode < 300 &&
        ((start && loseStart) || (complete && loseCompletion))) {
      if (start) loseStart = false;
      if (complete) loseCompletion = false;
      await response.stream.drain<void>();
      throw http.ClientException('Fixture acknowledgement lost');
    }
    if (start && holdStart != null) {
      final bytes = await response.stream.toBytes();
      startCommitted?.complete();
      await holdStart!.future;
      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        headers: response.headers,
      );
    }
    return response;
  }

  @override
  void close() => _transport.close();
}

void main() {
  test('real meditation retries lost acknowledgements, records mood, cancels late starts and isolates accounts', () async {
    const base = String.fromEnvironment(
      'MOBILE_TEST_API_URL',
      defaultValue: 'http://127.0.0.1:3188',
    );
    expect(Uri.parse(base).host, '127.0.0.1');
    final previousBase = ApiConfig.baseUrl, overrides = HttpOverrides.current;
    ApiConfig.setBaseUrl(base);
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final transport = LostAcknowledgementClient();
    final storage = SecureStorageService();
    final api = ApiClient(storage: storage, client: transport);
    final auth = AuthProvider(client: api, storage: storage);
    api.onRefresh = auth.refreshAccessToken;
    auth.addListener(api.invalidateSession);
    final emails = List.generate(
      2,
      (_) => 'dart-meditation-${const Uuid().v4()}@example.test',
    );
    const password = 'MeditationFixture123';
    final controllers = <MeditationController>[];
    addTearDown(() async {
      for (final controller in controllers) {
        controller.dispose();
        await controller.synchronized;
      }
      for (final email in emails) {
        if (await auth.login(email: email, password: password)) {
          await api.delete(
            ApiConfig.userAccountUrl,
            body: {'password': password},
          );
        }
      }
      await auth.clearLocalSession();
      auth.dispose();
      api.dispose();
      ApiConfig.setBaseUrl(previousBase);
      HttpOverrides.global = overrides;
    });
    expect(
      await auth.register(
        email: emails[0],
        password: password,
        firstName: 'Meditation',
        lastName: 'Fixture',
      ),
      isTrue,
      reason: auth.error,
    );
    final repository = MeditationRepository(client: api);
    final catalog = await api.get('$base/meditation/catalog') as List;
    expect(
      catalog.map((p) => p['id']),
      containsAll(MeditationExercises.all.map((e) => e.id)),
    );
    final controller = MeditationController(repository: repository)
      ..setExercise(
        MeditationExercises.all.firstWhere((e) => e.id == 'coherence'),
      )
      ..setDuration(7);
    controllers.add(controller);
    await controller.startSession();
    expect(controller.isRunning, isTrue);
    expect(controller.backendError, isNotNull);
    final registered = (await repository.getSessions()).single;
    expect(registered.type, 'coherence');
    expect(registered.durationMinutes, 7);
    expect(registered.status, 'STARTED');
    for (var i = 0; i < 12; i++) {
      controller.tick();
    }
    await controller.stopSession(finished: true);
    await controller.synchronized;
    expect(controller.backendError, isNotNull);
    final firstCompletion = (await repository.getSessions()).single;
    expect(firstCompletion.status, 'COMPLETED');
    await controller.retrySync();
    expect(controller.backendError, isNull);
    expect(controller.backendSessionId, registered.id);
    await controller.selectMood(3, 'happy');
    final saved = (await MeditationRepository(
      client: api,
    ).getSessions()).single;
    expect(saved.id, registered.id);
    expect(saved.endedAt, firstCompletion.endedAt);
    expect(saved.moodAfter, 'happy');

    // Hold a real committed start until after the UI has interrupted and left.
    transport.holdStart = Completer<void>();
    transport.startCommitted = Completer<void>();
    final interrupted =
        MeditationController(repository: MeditationRepository(client: api))
          ..setExercise(
            MeditationExercises.all.firstWhere((e) => e.id == 'body-scan'),
          )
          ..setDuration(10);
    controllers.add(interrupted);
    final starting = interrupted.startSession();
    await transport.startCommitted!.future;
    await interrupted.stopSession();
    interrupted.resetToSetup();
    transport.holdStart!.complete();
    await starting;
    await interrupted.synchronized;
    transport.holdStart = null;
    expect(interrupted.backendSessionId, isNull);
    final canceled = (await repository.getSessions()).singleWhere(
      (s) => s.type == 'body-scan',
    );
    expect(canceled.status, 'CANCELED');

    await auth.clearLocalSession();
    expect(
      await auth.register(
        email: emails[1],
        password: password,
        firstName: 'Other',
        lastName: 'Fixture',
      ),
      isTrue,
      reason: auth.error,
    );
    final other = MeditationRepository(client: api);
    expect(await other.getSessions(), isEmpty);
    await expectLater(
      repository.getSessions(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.cancelled,
        ),
      ),
    );
    await expectLater(
      repository.startSession(type: 'facile', durationMinutes: 3),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      other.completeSession(sessionId: saved.id),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
    expect(await other.getSessions(), isEmpty);
    await auth.clearLocalSession();
    expect(
      await auth.login(email: emails[0], password: password),
      isTrue,
      reason: auth.error,
    );
    final restored = await MeditationRepository(client: api).getSessions();
    expect(restored, hasLength(2));
    expect(restored.singleWhere((s) => s.id == saved.id).moodAfter, 'happy');
    expect(restored.singleWhere((s) => s.id == canceled.id).status, 'CANCELED');
  }, skip: !const bool.fromEnvironment('MOBILE_API_INTEGRATION'));
}
