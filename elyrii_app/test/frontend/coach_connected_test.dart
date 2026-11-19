import 'dart:async';
import 'dart:io';

import 'package:elyrii_app/core/config/api_config.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/network/api_exception.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/parcours/data/connected_journey_repository.dart';
import 'package:elyrii_app/features/parcours/data/journey_catalog.dart';
import 'package:elyrii_app/features/parcours/data/journey_parser.dart';
import 'package:elyrii_app/features/parcours/data/journey_repository.dart';
import 'package:elyrii_app/features/parcours/domain/journey.dart';
import 'package:elyrii_app/features/parcours/presentation/providers/journey_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class CoachTransport extends http.BaseClient {
  final _client = http.Client();
  bool offline = false, loseStepAcknowledgement = false;
  Completer<void>? holdRead, readCommitted;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (offline) throw http.ClientException('Fixture offline');
    final response = await _client.send(request);
    if (request.url.path.contains('/coach/journey/steps/') &&
        loseStepAcknowledgement &&
        response.statusCode == 200) {
      loseStepAcknowledgement = false;
      await response.stream.drain<void>();
      throw http.ClientException('Fixture acknowledgement lost');
    }
    final gate = holdRead;
    if (request.url.path == '/coach/journey' && gate != null) {
      holdRead = null;
      final bytes = await response.stream.toBytes();
      readCommitted!.complete();
      await gate.future;
      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        headers: response.headers,
      );
    }
    return response;
  }

  @override
  void close() => _client.close();
}

void main() {
  test('Coach migrates and restores real progress, retries safely, reads offline and isolates accounts', () async {
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
    final transport = CoachTransport(), storage = SecureStorageService();
    final api = ApiClient(storage: storage, client: transport);
    final auth = AuthProvider(client: api, storage: storage);
    auth.addListener(api.invalidateSession);
    api.onRefresh = auth.refreshAccessToken;
    final cipher = ContentCipher(storage),
        local = JourneyRepository(cipher: ContentCipher(storage));
    final emails = List.generate(
      2,
      (_) => 'dart-coach-${const Uuid().v4()}@example.test',
    );
    const password = 'CoachFixture123';
    final repository = ConnectedJourneyRepository(client: api, cipher: cipher);
    var provider = JourneyProvider(repository: repository);
    addTearDown(() async {
      transport.offline = false;
      provider.dispose();
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
        firstName: 'Coach',
        lastName: 'Fixture',
      ),
      isTrue,
      reason: auth.error,
    );
    final owner = auth.accountId!;
    final chosen = await local.choose(
      owner,
      local.catalog.first,
      expected: null,
    );
    final advanced = await local.completeStep(
      owner,
      chosen.current,
      chosen.current.path.steps.first.stepId,
    );
    final paused = await local.pause(owner, advanced.current);
    provider.onUserChanged(userId: owner);
    await provider.load();
    expect(provider.error, isNull);
    expect(provider.current!.enrollmentId, paused.current.enrollmentId);
    expect(provider.current!.revision, paused.current.revision);
    expect(provider.current!.completedStepCount, 1);
    expect(provider.current!.status, JourneyStatus.paused);
    expect(provider.canWrite, isTrue);
    final serverCatalog = await api.get(ApiConfig.coachCatalogUrl);
    final reference = journeyCatalog
        .map(
          (path) => journeyEnrollmentToJson(
            JourneyEnrollment(
              enrollmentId: paused.current.enrollmentId,
              path: path,
              status: JourneyStatus.active,
              completedStepCount: 0,
              revision: 1,
              startedAt: paused.current.startedAt,
              updatedAt: paused.current.startedAt,
              completedAt: null,
            ),
          )['path'],
        )
        .toList();
    expect(
      serverCatalog,
      reference,
      reason: 'The backend must preserve the new frontend editorial content.',
    );
    expect(await provider.resume(), JourneyCommandResult.changed);
    final before = provider.current!;
    transport.loseStepAcknowledgement = true;
    expect(
      await provider.completeStep(before.currentStep!.stepId),
      JourneyCommandResult.failed,
    );
    expect(
      provider.current!.completedStepCount,
      1,
      reason: 'An unacknowledged action must not report success.',
    );
    expect(provider.canWrite, isFalse);
    await provider.load(force: true);
    expect(provider.error, isNull);
    expect(provider.current!.completedStepCount, 2);
    final replay = await api.post(
      '${ApiConfig.coachJourneyUrl}/steps/${before.currentStep!.stepId}/complete',
      body: {'enrollmentId': before.enrollmentId, 'revision': before.revision},
    );
    expect(replay['changed'], isFalse);
    expect(
      await provider.completeStep(provider.current!.currentStep!.stepId),
      JourneyCommandResult.changed,
    );
    expect(provider.current!.status, JourneyStatus.completed);
    expect(
      await provider.choose(provider.catalog.first),
      JourneyCommandResult.unchanged,
    );
    expect(
      await provider.choose(
        provider.catalog.firstWhere((p) => p.topic == JourneyTopic.calm),
      ),
      JourneyCommandResult.changed,
    );
    final newId = provider.current!.enrollmentId;
    provider.dispose();

    transport.offline = true;
    provider = JourneyProvider(
      repository: ConnectedJourneyRepository(client: api, cipher: cipher),
    )..onUserChanged(userId: owner);
    await provider.load();
    expect(provider.current!.enrollmentId, newId);
    expect(provider.hasLoadedData, isTrue);
    expect(provider.error, isNotNull);
    expect(provider.canWrite, isFalse);
    expect(
      await provider.completeStep(provider.current!.currentStep!.stepId),
      JourneyCommandResult.failed,
    );
    transport.offline = false;
    await provider.load(force: true);
    expect(provider.canWrite, isTrue);
    expect(provider.current!.completedStepCount, 0);
    // A stale device cache never replaces newer server progress.
    await local.cacheConfirmedProgress(owner, paused.current);
    await provider.load(force: true);
    expect(provider.current!.enrollmentId, newId);

    final gate = Completer<void>();
    transport.holdRead = gate;
    transport.readCommitted = Completer<void>();
    final oldLoad = provider.load(force: true);
    await transport.readCommitted!.future;
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
    provider.onUserChanged(userId: auth.accountId!);
    gate.complete();
    await oldLoad;
    await provider.load();
    expect(provider.error, isNull);
    expect(provider.current, isNull);
    await expectLater(
      repository.choose(owner, journeyCatalog.first, expected: null),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.cancelled,
        ),
      ),
    );
    expect((await api.get(ApiConfig.coachJourneyUrl))['current'], isNull);
    await auth.clearLocalSession();
    expect(
      await auth.login(email: emails[0], password: password),
      isTrue,
      reason: auth.error,
    );
    provider.onUserChanged(userId: owner);
    await provider.load();
    expect(provider.current!.enrollmentId, newId);
    expect(provider.current!.completedStepCount, 0);
    final exported = await provider.exportOwner(owner);
    expect(exported!['owner'], owner);
    expect((exported['current'] as Map)['enrollmentId'], newId);
  }, skip: !const bool.fromEnvironment('MOBILE_API_INTEGRATION'));
}
