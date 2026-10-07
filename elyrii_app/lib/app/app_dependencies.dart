import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/services/secure_storage_service.dart';
import '../core/services/theme_provider.dart';
import '../core/storage/content_cipher.dart';
import '../core/storage/account_preferences.dart';
import '../core/design_system/haptics/elyrii_haptics.dart';
import '../core/diagnostics/app_diagnostics.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/data/models/user_model.dart';
import '../features/chatbot/data/repositories/chat_history_service.dart';
import '../features/chatbot/presentation/providers/chatbot_provider.dart';
import '../features/journal/data/repositories/journal_repository.dart';
import '../features/journal/data/repositories/journal_store.dart';
import '../features/journal/presentation/providers/journal_provider.dart';
import '../features/settings/providers/settings_provider.dart';
import '../features/coach/presentation/providers/coach_provider.dart';
import '../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../features/gamification/presentation/providers/gamification_provider.dart';
import '../features/mascot/presentation/providers/mascot_provider.dart';

/// Composition and lifetime owner for all application services. Session-bound
/// state is invalidated synchronously, before background account hydration.
class AppDependencies {
  final SecureStorageService storage;
  final ApiClient api;
  final ThemeProvider theme;
  final ValueNotifier<bool> profileSetupDone = ValueNotifier(true);
  late final ContentCipher cipher;
  late final JournalStore journalStore;
  late final ChatHistoryService history;
  late final AuthProvider auth;
  late final UserProvider user;
  late final JournalProvider journal;
  late final CoachProvider coach;
  late final ChatbotProvider chat;
  late final DashboardProvider dashboard;
  late final GamificationProvider gamification;
  late final MascotProvider mascot;
  String? _scope;
  int _revision = -1;
  bool _disposed = false;
  bool _deleting = false;
  bool get isDeletingAccount => _deleting;

  AppDependencies({
    required this.storage,
    required this.api,
    required this.theme,
  }) {
    cipher = ContentCipher(storage);
    journalStore = JournalStore(cipher: cipher);
    history = ChatHistoryService(cipher: cipher);
    auth = AuthProvider(client: api, storage: storage);
    user = UserProvider(client: api);
    journal = JournalProvider(
      repository: JournalRepository(client: api, store: journalStore),
    );
    coach = CoachProvider(client: api);
    chat = ChatbotProvider(
      storage: storage,
      history: history,
      initialOwner: 'local-guest',
    );
    dashboard = DashboardProvider(
      apiClient: api,
      isDemoSession: () => auth.isDemoSession,
    );
    gamification = GamificationProvider(
      client: api,
      isDemoSession: () => auth.isDemoSession,
    );
    mascot = MascotProvider(client: api);
    auth.addListener(_authChanged);
    user.addListener(_preferencesChanged);
    api.onUnauthorized = (owner) {
      if (!_disposed && auth.isAuthenticated && auth.accountId == owner) {
        _track(auth.clearLocalSession(), 'session_expired');
      }
    };
    _authChanged();
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    for (final owner
        in prefs.getStringList('pending_account_deletions') ?? <String>[]) {
      await Future.wait([
        () async {
          if (await storage.getUserId() == owner) await storage.clearAuthData();
        }(),
        _purgeOwner(owner),
      ], eagerError: false);
      await _removeDeletionMarker(owner);
    }
    await auth.restoreLocalSession();
  }

  void _track(Future<void> operation, String event) {
    unawaited(
      operation.catchError(
        (Object error) => AppDiagnostics.record(event, error),
      ),
    );
  }

  void _authChanged() {
    if (_disposed) return;
    if (_revision != auth.sessionRevision) {
      _revision = auth.sessionRevision;
      api.invalidateSession();
    }
    final owner = auth.isAuthenticated ? auth.accountId : null;
    final scope = auth.isDemoSession ? 'demo' : owner ?? 'guest';
    if (_scope == scope) return;
    _scope = scope;
    final revision = _revision;
    profileSetupDone.value = auth.isDemoSession || owner == null;
    user.onUserChanged(userId: owner, isDemo: auth.isDemoSession);
    coach.onUserChanged(userId: owner, isDemo: auth.isDemoSession);
    journal.onUserChanged(owner);
    dashboard.onUserChanged(userId: owner, isDemo: auth.isDemoSession);
    gamification.onUserChanged(userId: owner, isDemo: auth.isDemoSession);
    _track(
      mascot.onUserChanged(
        userId: owner,
        isDemo: auth.isDemoSession,
        migrateLegacy: true,
      ),
      'mascot_binding',
    );
    _track(chat.onUserChanged(owner), 'chat_binding');
    _preferencesChanged();
    if (owner == null) return;
    _track(() async {
      final done =
          auth.isDemoSession || await storage.isProfileSetupCompletedFor(owner);
      if (_disposed || revision != _revision) return;
      profileSetupDone.value = done;
      if (auth.isDemoSession) {
        user.acceptProfile({
          'id': owner,
          'email': auth.user?.email ?? '',
          'firstName': auth.user?.firstName,
        });
        return;
      }
      final loadedProfile = await auth.fetchProfile(
        onProfile: user.acceptProfile,
      );
      if (!loadedProfile &&
          !_disposed &&
          revision == _revision &&
          auth.isAuthenticated) {
        await user.loadProfile();
      }
      if (_disposed || revision != _revision || !auth.isAuthenticated) return;
      await Future.wait([user.loadSettings(), gamification.loadAll()]);
    }(), 'account_hydration');
  }

  void _preferencesChanged() {
    if (_disposed) return;
    final profile = user.profile;
    if (profile != null) {
      auth.acceptProfile(
        UserModel(
          id: profile.id,
          email: profile.email,
          firstName: profile.firstName,
          lastName: profile.lastName,
        ),
      );
    }
    ElyriiHaptics.setEnabled(user.settings?.hapticsEnabled ?? true);
    theme.setThemeMode(
      user.settings?.themeModeValue ?? ThemeMode.system,
      persist: false,
    );
  }

  Future<bool> deleteAccount(String password) async {
    if (_deleting || !auth.isAuthenticated || auth.isDemoSession) return false;
    final owner = auth.accountId!;
    final revision = auth.sessionRevision;
    _deleting = true;
    try {
      if (!await user.deleteAccount(password: password)) return false;
      try {
        final prefs = await SharedPreferences.getInstance();
        final pending = {
          ...?prefs.getStringList('pending_account_deletions'),
          owner,
        };
        if (!await prefs.setStringList(
          'pending_account_deletions',
          pending.toList(),
        )) {
          throw StateError('Deletion marker write refused');
        }
      } catch (error) {
        // The server has already accepted deletion. A marker failure must
        // still trigger credential removal and every local purge below.
        AppDiagnostics.record('deletion_marker_failed', error);
      }
      await Future.wait([
        if (auth.sessionRevision == revision) auth.clearLocalSession(),
        () async {
          try {
            await Future.wait([chat.flushed, user.flushed, mascot.flushed]);
          } finally {
            await _purgeOwner(owner);
          }
        }(),
      ], eagerError: false);
      await _removeDeletionMarker(owner);
      return true;
    } catch (e) {
      AppDiagnostics.record('account_deletion_failed', e);
      rethrow;
    } finally {
      _deleting = false;
    }
  }

  Future<void> _purgeOwner(String owner) async {
    final operations = <Future<void>>[
      journalStore.deleteOwner(owner),
      history.deleteOwner(owner),
      storage.clearProfileSetup(owner),
      cipher.deleteOwner(owner),
      () async {
        final prefs = await SharedPreferences.getInstance();
        await AccountPreferences.removeOwner(prefs, owner);
        if (prefs.getString('elyrii_mascot_legacy_owner') == owner) {
          for (final key in const [
            'elyrii_mascot_legacy_owner',
            'elyrii_mascot_customization',
            'elyrii_mascot_theme',
            'elyrii_mascot_appearance',
            'elyrii_mascot_pending_sync',
            'elyrii_seen_cosmetic_unlocks',
          ]) {
            await prefs.remove(key);
          }
        }
        final raw = prefs.getString('cache_journal_entries');
        if (raw != null) {
          final remaining = (jsonDecode(raw) as List)
              .where(
                (entry) =>
                    entry['userId'] != owner && entry['user_id'] != owner,
              )
              .toList();
          if (remaining.isEmpty) {
            await prefs.remove('cache_journal_entries');
          } else {
            await prefs.setString(
              'cache_journal_entries',
              jsonEncode(remaining),
            );
          }
        }
      }(),
    ];
    // Every purge runs, even if another store fails. The tombstone survives
    // until all stores and the encryption key have been removed.
    await Future.wait(operations, eagerError: false);
  }

  Future<void> _removeDeletionMarker(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList('pending_account_deletions') ?? [];
    final saved = await prefs.setStringList(
      'pending_account_deletions',
      pending.where((id) => id != owner).toList(),
    );
    if (!saved) throw StateError('Deletion marker removal refused');
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    auth.removeListener(_authChanged);
    user.removeListener(_preferencesChanged);
    api.onUnauthorized = null;
    chat.dispose();
    journal.dispose();
    coach.dispose();
    user.dispose();
    dashboard.dispose();
    gamification.dispose();
    mascot.dispose();
    auth.dispose();
    theme.dispose();
    profileSetupDone.dispose();
    api.dispose();
    _track(chat.flushed.then((_) => history.close()), 'chat_close');
    _track(journalStore.close(), 'journal_close');
  }
}
