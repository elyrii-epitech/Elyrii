import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../data/settings_repository.dart';
import '../models/app_settings.dart';
import '../models/user_profile.dart';

/// Provider managing user profile state
class UserProvider extends ChangeNotifier {
  final UserRepository _repository;

  UserProfile? _profile;
  AppSettings? _settings;
  bool _isLoading = false;
  String? _error;

  UserProvider({required ApiClient client})
    : _repository = UserRepository(client: client);

  UserProfile? get profile => _profile;
  AppSettings? get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch the current user's profile from the backend
  Future<void> loadProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _repository.getMe();
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _settings = await _repository.getSettings();
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateSettings({
    String? themeMode,
    bool? notificationsEnabled,
    bool? hapticsEnabled,
    String? privacyMode,
    String? language,
  }) async {
    final previous = _settings;
    if (previous != null) {
      _settings = previous.copyWith(
        themeMode: themeMode,
        notificationsEnabled: notificationsEnabled,
        hapticsEnabled: hapticsEnabled,
        privacyMode: privacyMode,
        language: language,
      );
      notifyListeners();
    }

    try {
      _settings = await _repository.updateSettings(
        themeMode: themeMode,
        notificationsEnabled: notificationsEnabled,
        hapticsEnabled: hapticsEnabled,
        privacyMode: privacyMode,
        language: language,
      );
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _settings = previous;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update the user's profile.
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
    try {
      _profile = await _repository.updateMe(
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
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount({required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.deleteAccount(password: password);
      _profile = null;
      _settings = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
