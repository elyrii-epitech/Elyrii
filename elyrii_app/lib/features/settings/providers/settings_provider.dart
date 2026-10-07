import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../data/settings_repository.dart';
import '../models/app_settings.dart';
import '../models/user_profile.dart';

/// Account-owned profile and settings. Commands are serialized; optimistic
/// patches remain visible until their own response, never an older response.
class UserProvider extends ChangeNotifier {
  final UserRepository _repository;
  UserProfile? _profile;
  AppSettings? _settings;
  AppSettings? _confirmedSettings;
  String? _owner;
  int _session = 0;
  int _nextPatch = 0;
  int _busy = 0;
  bool _disposed = false;
  String? _error;
  final Map<int, _SettingsPatch> _pending = {};
  Future<void> _writes = Future.value();
  Future<void> _localWrites = Future.value();
  Future<void> get flushed => _localWrites;
  bool _deleting = false;
  Future<void> _persistSettings(AppSettings value, String? owner, int session) {
    final task = _localWrites.then((_) async {
      if (!_current(session) || owner == null) return;
      final prefs = await SharedPreferences.getInstance();
      if (!_current(session)) return;
      final saved = await prefs.setString(
        'account_settings_$owner',
        jsonEncode({
          'id': value.id,
          'userId': owner,
          'themeMode': value.themeMode,
          'notificationsEnabled': value.notificationsEnabled,
          'hapticsEnabled': value.hapticsEnabled,
          'privacyMode': value.privacyMode,
          'language': value.language,
        }),
      );
      if (!saved) throw StateError('Preference write refused');
    });
    _localWrites = task.catchError((Object _) {});
    return task;
  }

  Future<void>? _profileLoad;
  Future<void>? _settingsLoad;

  UserProvider({UserRepository? repository, ApiClient? client})
    : assert(repository != null || client != null),
      _repository = repository ?? UserRepository(client: client!);
  UserProfile? get profile => _profile;
  AppSettings? get settings => _settings;
  bool get isLoading => _busy > 0;
  bool get isSyncingSettings => _pending.isNotEmpty;
  String? get error => _error;
  bool _current(int session) => !_disposed && _session == session;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Impossible de synchroniser les modifications. Réessaie.';

  void onUserChanged({String? userId, bool isDemo = false}) {
    final owner = isDemo ? 'demo-user' : userId;
    if (_owner == owner) return;
    _owner = owner;
    _session++;
    _profile = null;
    _settings = null;
    _confirmedSettings = null;
    _error = null;
    _busy = 0;
    _deleting = false;
    _pending.clear();
    _profileLoad = null;
    _settingsLoad = null;
    _writes = Future.value();
    _notify();
  }

  void acceptProfile(Map<String, dynamic> profile) {
    final parsed = UserProfile.fromJson(profile);
    if (_owner != null && parsed.id != _owner) return;
    _profile = parsed;
    _error = null;
    _notify();
  }

  Future<void> _load(Future<void> Function() operation) async {
    final session = _session;
    _busy++;
    _error = null;
    _notify();
    try {
      await operation();
    } catch (e) {
      if (_current(session)) _error = _message(e);
    } finally {
      if (_current(session)) {
        _busy--;
        _notify();
      }
    }
  }

  Future<void> loadProfile() {
    if (_profileLoad != null) return _profileLoad!;
    final session = _session;
    late final Future<void> request;
    request =
        _load(() async {
          final profile = await _repository.getMe();
          if (_current(session) && (_owner == null || profile.id == _owner)) {
            _profile = profile;
          }
        }).whenComplete(() {
          if (identical(_profileLoad, request)) _profileLoad = null;
        });
    return _profileLoad = request;
  }

  Future<void> loadSettings() {
    if (_settingsLoad != null) return _settingsLoad!;
    final session = _session;
    final owner = _owner;
    final version = _nextPatch;
    late final Future<void> request;
    request =
        _load(() async {
          if (owner != null) {
            final prefs = await SharedPreferences.getInstance();
            final raw = prefs.getString('account_settings_$owner');
            if (_current(session) && version == _nextPatch && raw != null) {
              try {
                final cached = AppSettings.fromJson(
                  jsonDecode(raw) as Map<String, dynamic>,
                );
                if (cached.userId == owner) {
                  _confirmedSettings = cached;
                  _recompute();
                  _notify();
                }
              } catch (_) {
                await prefs.remove('account_settings_$owner');
              }
            }
          }
          if (!_current(session)) return;
          final settings = await _repository.getSettings();
          if (!_current(session) || version != _nextPatch) return;
          if (owner != null &&
              settings.userId.isNotEmpty &&
              settings.userId != owner) {
            throw const FormatException('Settings account mismatch');
          }
          _confirmedSettings = settings;
          _recompute();
          await _persistSettings(settings, owner, session);
        }).whenComplete(() {
          if (identical(_settingsLoad, request)) _settingsLoad = null;
        });
    return _settingsLoad = request;
  }

  void _recompute() {
    var next = _confirmedSettings;
    for (final patch in _pending.values) {
      if (next != null) next = patch.apply(next);
    }
    _settings = next;
  }

  Future<bool> updateSettings({
    String? themeMode,
    bool? notificationsEnabled,
    bool? hapticsEnabled,
    String? privacyMode,
    String? language,
  }) {
    if (_deleting) return Future.value(false);
    final session = _session;
    final owner = _owner;
    final id = ++_nextPatch;
    final patch = _SettingsPatch(
      themeMode,
      notificationsEnabled,
      hapticsEnabled,
      privacyMode,
      language,
    );
    _pending[id] = patch;
    _error = null;
    _recompute();
    _notify();
    final task = _writes.then((_) async {
      if (!_current(session)) return false;
      try {
        final result = await _repository.updateSettings(
          themeMode: themeMode,
          notificationsEnabled: notificationsEnabled,
          hapticsEnabled: hapticsEnabled,
          privacyMode: privacyMode,
          language: language,
        );
        if (!_current(session)) return false;
        if (owner != null &&
            result.userId.isNotEmpty &&
            result.userId != owner) {
          throw const FormatException('Settings account mismatch');
        }
        _confirmedSettings = result;
        _error = null;
        await _persistSettings(result, owner, session);
        return true;
      } catch (e) {
        if (_current(session)) _error = _message(e);
        return false;
      } finally {
        if (_current(session)) {
          _pending.remove(id);
          _recompute();
          _notify();
        }
      }
    });
    _writes = task.then<void>((_) {});
    return task;
  }

  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    int? age,
    String? pfp,
    bool clearPfp = false,
    String? bio,
    String? gender,
    String? pronouns,
    String? wellnessGoal,
    String? timezone,
  }) async {
    final session = _session;
    try {
      final profile = await _repository.updateMe(
        firstName: firstName,
        lastName: lastName,
        age: age,
        pfp: pfp,
        clearPfp: clearPfp,
        bio: bio,
        gender: gender,
        pronouns: pronouns,
        wellnessGoal: wellnessGoal,
        timezone: timezone,
      );
      if (!_current(session)) return false;
      if (_owner != null && profile.id != _owner) {
        throw const FormatException('Profile account mismatch');
      }
      _profile = profile;
      _error = null;
      _notify();
      return true;
    } catch (e) {
      if (_current(session)) {
        _error = _message(e);
        _notify();
      }
      return false;
    }
  }

  Future<bool> deleteAccount({required String password}) async {
    final session = _session;
    _busy++;
    _error = null;
    _notify();
    try {
      _deleting = true;
      await _writes;
      if (!_current(session)) return false;
      await _repository.deleteAccount(password: password);
      if (_current(session)) {
        _profile = null;
        _settings = null;
        _confirmedSettings = null;
      }
      return true;
    } catch (e) {
      if (_current(session)) _error = _message(e);
      return false;
    } finally {
      if (_current(session)) {
        _deleting = false;
        _busy--;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _session++;
    super.dispose();
  }
}

class _SettingsPatch {
  final String? themeMode;
  final bool? notifications;
  final bool? haptics;
  final String? privacy;
  final String? language;
  const _SettingsPatch(
    this.themeMode,
    this.notifications,
    this.haptics,
    this.privacy,
    this.language,
  );
  AppSettings apply(AppSettings value) => value.copyWith(
    themeMode: themeMode,
    notificationsEnabled: notifications,
    hapticsEnabled: haptics,
    privacyMode: privacy,
    language: language,
  );
}
