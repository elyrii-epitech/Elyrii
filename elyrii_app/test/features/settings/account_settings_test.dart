import 'dart:async';

import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/settings/data/settings_repository.dart';
import 'package:elyrii_app/features/settings/models/app_settings.dart';
import 'package:elyrii_app/features/settings/models/user_profile.dart';
import 'package:elyrii_app/features/settings/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

AppSettings settings(String owner, String mode) => AppSettings.fromJson({
  'id': 'settings-$owner',
  'userId': owner,
  'themeMode': mode,
});

class _Repository extends UserRepository {
  _Repository() : super(client: ApiClient(storage: SecureStorageService()));
  final profiles = <Completer<UserProfile>>[];
  final reads = <Completer<AppSettings>>[];
  final writes = <Completer<AppSettings>>[];
  @override
  Future<UserProfile> getMe() {
    final gate = Completer<UserProfile>();
    profiles.add(gate);
    return gate.future;
  }

  @override
  Future<AppSettings> getSettings() {
    final gate = Completer<AppSettings>();
    reads.add(gate);
    return gate.future;
  }

  @override
  Future<AppSettings> updateSettings({
    String? themeMode,
    bool? notificationsEnabled,
    bool? hapticsEnabled,
    String? privacyMode,
    String? language,
  }) {
    final gate = Completer<AppSettings>();
    writes.add(gate);
    return gate.future;
  }
}

void main() {
  test(
    'late profile/settings responses cannot hydrate the next account',
    () async {
      final repository = _Repository();
      final provider = UserProvider(repository: repository);
      addTearDown(provider.dispose);
      provider.onUserChanged(userId: 'alice');
      final profileA = provider.loadProfile();
      final settingsA = provider.loadSettings();
      await Future<void>.delayed(Duration.zero);
      provider.onUserChanged(userId: 'bob');
      final profileB = provider.loadProfile();
      final settingsB = provider.loadSettings();
      await Future<void>.delayed(Duration.zero);
      repository.profiles[0].complete(
        const UserProfile(id: 'alice', email: 'alice@example.test'),
      );
      repository.reads[0].complete(settings('alice', 'DARK'));
      await Future.wait([profileA, settingsA]);
      expect(provider.profile, isNull);
      expect(provider.settings, isNull);
      expect(identical(provider.loadSettings(), settingsB), isTrue);
      repository.profiles[1].complete(
        const UserProfile(id: 'bob', email: 'bob@example.test'),
      );
      repository.reads[1].complete(settings('bob', 'LIGHT'));
      await Future.wait([profileB, settingsB]);
      expect(provider.profile!.id, 'bob');
      expect(provider.settings!.themeMode, 'LIGHT');
    },
  );
  test('failed older preference rolls back only its own patch, then persists the newest confirmation', () async {
    final repository = _Repository();
    final provider = UserProvider(repository: repository);
    addTearDown(provider.dispose);
    provider.onUserChanged(userId: 'alice');
    final loading = provider.loadSettings();
    await Future<void>.delayed(Duration.zero);
    repository.reads.single.complete(settings('alice', 'LIGHT'));
    await loading;
    final first = provider.updateSettings(themeMode: 'DARK');
    final second = provider.updateSettings(themeMode: 'SYSTEM');
    await Future<void>.delayed(Duration.zero);
    expect(repository.writes, hasLength(1));
    expect(provider.settings!.themeMode, 'SYSTEM');
    repository.writes.first.completeError(StateError('offline'));
    expect(await first, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(provider.settings!.themeMode, 'SYSTEM');
    repository.writes.last.complete(settings('alice', 'SYSTEM'));
    expect(await second, isTrue);
    expect(provider.isSyncingSettings, isFalse);
    await provider.flushed;
  });
}
