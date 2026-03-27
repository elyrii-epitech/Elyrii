import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../data/settings_repository.dart';
import '../models/user_profile.dart';

/// Provider managing user profile state
class UserProvider extends ChangeNotifier {
  final UserRepository _repository;

  UserProfile? _profile;
  bool _isLoading = false;
  String? _error;

  UserProvider({required ApiClient client})
      : _repository = UserRepository(client: client);

  UserProfile? get profile => _profile;
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
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update the user's profile
  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    int? age,
    String? pfp,
  }) async {
    try {
      _profile = await _repository.updateMe(
        firstName: firstName,
        lastName: lastName,
        age: age,
        pfp: pfp,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
