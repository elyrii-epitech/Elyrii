import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:elyrii_app/core/config/api_config.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/settings/providers/settings_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Interrupt real HTTP at response boundaries; successful writes still commit.
class SettingsTransport extends http.BaseClient {
  final _http = http.Client();
  bool offline = false, loseSave = false;
  String? heldMethod;
  Completer<void>? committed, release;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (offline) throw http.ClientException('Fixture offline');
    final response = await _http.send(request);
    if (request.url.path == '/user/settings') {
      if (loseSave && request.method == 'PUT') {
        loseSave = false;
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

  void hold(String method) {
    heldMethod = method;
    committed = Completer<void>();
    release = Completer<void>();
  }

  @override
  void close() => _http.close();
}

void main() {
  test('real settings serialize edits, recover offline and lost saves, restore without cache and isolate accounts', () async {
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
    final transport = SettingsTransport();
    final storage = SecureStorageService();
    final api = ApiClient(storage: storage, client: transport);
    final auth = AuthProvider(client: api, storage: storage);
    api.onRefresh = auth.refreshAccessToken;
    auth.addListener(api.invalidateSession);
    final emails = List.generate(
      2,
      (_) => 'dart-settings-${const Uuid().v4()}@example.test',
    );
    const password = 'SettingsFixture123';
    final user = UserProvider(client: api);
    addTearDown(() async {
      transport.offline = false;
      if (transport.release case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      user.dispose();
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
    Future<void> register(int index) async {
      expect(
        await auth.register(
          email: emails[index],
          password: password,
          firstName: 'Settings',
          lastName: 'Fixture',
        ),
        isTrue,
        reason: auth.error,
      );
      user.onUserChanged(userId: auth.accountId);
      await user.loadSettings();
      expect(user.error, isNull);
    }

    await register(0);
    final firstOwner = auth.accountId!;
    expect(user.settings!.themeMode, 'SYSTEM');
    transport.hold('PUT');
    final dark = user.updateSettings(themeMode: 'DARK');
    await transport.committed!.future;
    final vibration = user.updateSettings(hapticsEnabled: false);
    final reload = user.loadSettings();
    var flushed = false;
    final flushing = user.flushed.then((_) => flushed = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(flushed, isFalse);
    transport.release!.complete();
    expect(await dark, isTrue);
    expect(await vibration, isTrue);
    await Future.wait([reload, flushing]);
    expect(user.settings!.themeMode, 'DARK');
    expect(user.settings!.hapticsEnabled, isFalse);

    transport.offline = true;
    expect(await user.updateSettings(themeMode: 'LIGHT'), isFalse);
    expect(user.settings!.themeMode, 'DARK');
    expect(user.error, isNotNull);
    user.onUserChanged();
    user.onUserChanged(userId: firstOwner);
    await user.loadSettings();
    expect(user.settings!.themeMode, 'DARK');
    expect(user.settings!.hapticsEnabled, isFalse);
    transport.offline = false;
    transport.loseSave = true;
    expect(await user.updateSettings(themeMode: 'LIGHT'), isFalse);
    expect(user.settings!.themeMode, 'DARK');
    await user.loadSettings();
    expect(user.settings!.themeMode, 'LIGHT');
    expect(user.error, isNull);

    // A genuine older server snapshot cannot overwrite a newer edit.
    transport.hold('GET');
    final reading = user.loadSettings();
    await transport.committed!.future;
    expect(await user.updateSettings(themeMode: 'DARK'), isTrue);
    transport.release!.complete();
    await reading;
    expect(user.settings!.themeMode, 'DARK');

    await (await SharedPreferences.getInstance()).remove(
      'account_settings_$firstOwner',
    );
    user.onUserChanged();
    user.onUserChanged(userId: firstOwner);
    await user.loadSettings();
    expect(user.settings!.themeMode, 'DARK');
    expect(user.settings!.hapticsEnabled, isFalse);
    final exported = await api.get(ApiConfig.userExportUrl) as Map;
    expect(exported['profile']['id'], firstOwner);
    expect(exported['settings']['themeMode'], 'DARK');
    expect(exported['profile'].containsKey('password'), isFalse);

    // Hold an already committed response across a real authentication change.
    transport.hold('PUT');
    final late = user.updateSettings(themeMode: 'LIGHT');
    await transport.committed!.future;
    await auth.clearLocalSession();
    await register(1);
    final otherOwner = auth.accountId!;
    transport.release!.complete();
    expect(await late, isFalse);
    expect(user.settings!.userId, otherOwner);
    expect(user.settings!.themeMode, 'SYSTEM');
    expect(user.settings!.hapticsEnabled, isTrue);
    final cached = jsonDecode(
      (await SharedPreferences.getInstance()).getString(
        'account_settings_$otherOwner',
      )!,
    ) as Map;
    expect(cached['userId'], otherOwner);
    expect(cached['themeMode'], 'SYSTEM');
    final otherExport = await api.get(ApiConfig.userExportUrl) as Map;
    expect(otherExport['profile']['id'], otherOwner);
  }, skip: !const bool.fromEnvironment('MOBILE_API_INTEGRATION'));
}
