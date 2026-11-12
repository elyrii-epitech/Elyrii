import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:elyrii_app/core/config/api_config.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/dashboard/data/accueil_activities.dart';
import 'package:elyrii_app/features/dashboard/domain/civil_day.dart';
import 'package:elyrii_app/features/dashboard/presentation/mood_presentation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class HomeTransport extends http.BaseClient {
  final _http = http.Client();
  bool offline = false, loseCommand = false;
  String? heldMethod;
  Completer<void>? committed, release;
  void hold(String method) {
    heldMethod = method;
    committed = Completer<void>();
    release = Completer<void>();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (offline) throw http.ClientException('Fixture offline');
    final response = await _http.send(request);
    if (request.url.path.startsWith('/user/home')) {
      if (loseCommand && request.url.path.endsWith('/commands')) {
        loseCommand = false;
        await response.stream.drain<void>();
        throw http.ClientException('Fixture acknowledgement lost');
      }
      if (heldMethod == request.method) {
        heldMethod = null;
        final bytes = await response.stream.toBytes();
        committed!.complete();
        await release!.future;
        return http.StreamedResponse(
          Stream.value(bytes),
          response.statusCode,
          headers: response.headers,
        );
      }
    }
    return response;
  }

  @override
  void close() => _http.close();
}

void main() {
  test('real Home imports legacy facts, merges devices, restores, recovers lost saves and isolates late responses', () async {
    const base = String.fromEnvironment(
      'MOBILE_TEST_API_URL',
      defaultValue: 'http://127.0.0.1:3188',
    );
    expect(Uri.parse(base).host, '127.0.0.1');
    final previous = ApiConfig.baseUrl, overrides = HttpOverrides.current;
    ApiConfig.setBaseUrl(base);
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final transport = HomeTransport(), storage = SecureStorageService();
    final api = ApiClient(storage: storage, client: transport);
    final auth = AuthProvider(client: api, storage: storage);
    api.onRefresh = auth.refreshAccessToken;
    auth.addListener(api.invalidateSession);
    final cipher = ContentCipher(storage), stores = <AccueilActivities>[];
    final emails = List.generate(
      2,
      (_) => 'dart-home-${const Uuid().v4()}@example.test',
    );
    const password = 'HomeFixture123';
    final day = CivilDay.fromLocal(DateTime.now());
    final monday = AccueilActivities.mondayOf(day);
    addTearDown(() async {
      transport.offline = false;
      if (transport.release case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      for (final store in stores) {
        store.dispose();
        await store.flushed;
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
      ApiConfig.setBaseUrl(previous);
      HttpOverrides.global = overrides;
    });
    Future<void> register(int index) async => expect(
      await auth.register(
        email: emails[index],
        password: password,
        firstName: 'Home',
        lastName: 'Fixture',
      ),
      isTrue,
      reason: auth.error,
    );
    Future<AccueilActivities> device(String owner, {bool remote = true}) async {
      final store = AccueilActivities(
        cipher: cipher,
        client: remote ? api : null,
      );
      stores.add(store);
      store.onUserChanged(userId: owner);
      await store.flushed;
      expect(store.snapshot.error, isNull);
      return store;
    }

    await register(0);
    final owner = auth.accountId!;
    final local = await device(owner, remote: false);
    await local.setRitualDone(day: day, ritual: AccueilRitual.walk, done: true);
    await local.addRitual(AccueilRitual.water);
    await local.setDecor(MascotDecor.hills, completedChallenges: 0);
    await local.recordMood(day: day, mood: MoodType.happy);
    final prefs = await SharedPreferences.getInstance();
    final legacyRaw = prefs.getString('accueil_activities_$owner');
    final first = await device(owner);
    expect(first.snapshot.rituals[day]!.isDone(AccueilRitual.walk), isTrue);
    expect(first.snapshot.decor, MascotDecor.hills);
    expect(first.snapshot.moodDays[day], MoodType.happy);
    expect(prefs.getString('accueil_activities_legacy_$owner'), legacyRaw);
    expect(
      prefs.getString('accueil_activities_$owner'),
      startsWith('aesgcm1:'),
    );
    final note = await api.post(
      ApiConfig.journalUrl,
      body: {'title': 'Owned follow-up', 'content': 'Fixture content'},
    ) as Map;
    final entryId = note['body']['id'] as String;
    expect(
      await first.answerThread(entryId: entryId, reply: ThreadReply.ratherGood),
      isTrue,
    );
    final second = await device(owner);
    expect(
      await first.setRitualDone(
        day: day,
        ritual: AccueilRitual.walk,
        done: false,
      ),
      isTrue,
    );
    expect(await second.completeSocialStep(day: day), isTrue);
    expect(second.snapshot.rituals[day]!.isDone(AccueilRitual.walk), isFalse);
    expect(await first.nextJournalQuestion(day: day, count: 3), isTrue);
    expect(first.snapshot.socialWeeks[monday]!.isDone(day), isTrue);
    expect(
      await first.setDecor(MascotDecor.clearing, completedChallenges: 10),
      isFalse,
    );
    expect(first.snapshot.decor, MascotDecor.hills);
    await first.reload();

    transport.loseCommand = true;
    expect(await first.nextSocialIdea(day: day), isFalse);
    expect(first.snapshot.socialWeeks[monday]!.ideaIndex, 0);
    await first.reload();
    expect(first.snapshot.error, isNull);
    expect(first.snapshot.socialWeeks[monday]!.ideaIndex, 1);
    transport.offline = true;
    expect(
      await first.setDecor(MascotDecor.waves, completedChallenges: 0),
      isFalse,
    );
    expect(first.snapshot.decor, MascotDecor.hills);
    await first.reload();
    expect(first.snapshot.decor, MascotDecor.hills);
    expect(first.snapshot.error, isNotNull);
    transport.offline = false;
    await first.reload();
    await prefs.remove('accueil_activities_$owner');
    final restored = await device(owner);
    expect(
      restored.snapshot.threadAnswers[entryId]!.reply,
      ThreadReply.ratherGood,
    );
    expect(restored.snapshot.socialWeeks[monday]!.ideaIndex, 1);
    expect(restored.snapshot.journalQuestion, isNotNull);
    expect(restored.snapshot.addedRituals, contains(AccueilRitual.water));
    final export = await api.get(ApiConfig.userExportUrl) as Map;
    expect(export['home']['userId'], owner);
    expect(export['home']['activities']['decor'], 'hills');
    expect(export['home']['activities'].containsKey('moodDays'), isFalse);
    expect(
      (await restored.exportOwner(owner)).keys,
      contains('accueil_activities_legacy'),
    );

    transport.hold('POST');
    final late = restored.setDecor(MascotDecor.waves, completedChallenges: 0);
    await transport.committed!.future;
    await auth.clearLocalSession();
    await register(1);
    final otherOwner = auth.accountId!;
    restored.onUserChanged(userId: otherOwner);
    await restored.reload();
    transport.release!.complete();
    expect(await late, isFalse);
    expect(restored.snapshot.decor, MascotDecor.arches);
    expect(restored.snapshot.threadAnswers, isEmpty);
    expect(restored.snapshot.rituals, isEmpty);
    final other = await api.get(ApiConfig.userHomeUrl) as Map;
    expect(other['owner'], otherOwner);
    expect(other['activities']['decor'], 'arches');
    final cache = jsonDecode(
      await cipher.open(
        otherOwner,
        prefs.getString('accueil_activities_$otherOwner')!,
        purpose: 'accueil-activities:v1',
      ),
    ) as Map;
    expect(cache['owner'], otherOwner);
    expect(cache['decor'], 'arches');
    transport.hold('GET');
    final lateRead = restored.reload();
    await transport.committed!.future;
    expect(
      await restored.setDecor(MascotDecor.hills, completedChallenges: 0),
      isFalse,
    );
    expect(await auth.login(email: emails[0], password: password), isTrue);
    restored.onUserChanged(userId: owner);
    await restored.reload();
    transport.release!.complete();
    await lateRead;
    expect(restored.snapshot.decor, MascotDecor.waves);
    expect(
      restored.snapshot.threadAnswers[entryId]!.reply,
      ThreadReply.ratherGood,
    );
  }, skip: !const bool.fromEnvironment('MOBILE_API_INTEGRATION'));
}
