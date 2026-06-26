import '../../../core/network/api_client.dart';
import '../../../core/config/api_config.dart';
import '../models/app_settings.dart';
import '../models/user_profile.dart';

/// Repository handling user profile API calls
class UserRepository {
  final ApiClient _client;

  UserRepository({required ApiClient client}) : _client = client;

  /// Fetch the authenticated user's profile
  Future<UserProfile> getMe() async {
    final response =
        await _client.get(ApiConfig.userMeUrl) as Map<String, dynamic>;
    return UserProfile.fromJson(response);
  }

  /// Update the authenticated user's profile
  Future<UserProfile> updateMe({
    String? firstName,
    String? lastName,
    int? age,
    String? pfp,
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (age != null) body['age'] = age;
    if (pfp != null) body['pfp'] = pfp;
    final response =
        await _client.put(ApiConfig.userMeUrl, body: body)
            as Map<String, dynamic>;
    return UserProfile.fromJson(response);
  }

  Future<AppSettings> getSettings() async {
    final response =
        await _client.get(ApiConfig.userSettingsUrl) as Map<String, dynamic>;
    return AppSettings.fromJson(response);
  }

  Future<AppSettings> updateSettings({
    String? themeMode,
    bool? notificationsEnabled,
    String? privacyMode,
  }) async {
    final body = <String, dynamic>{};
    if (themeMode != null) body['themeMode'] = themeMode;
    if (notificationsEnabled != null) {
      body['notificationsEnabled'] = notificationsEnabled;
    }
    if (privacyMode != null) body['privacyMode'] = privacyMode;

    final response =
        await _client.put(ApiConfig.userSettingsUrl, body: body)
            as Map<String, dynamic>;
    return AppSettings.fromJson(response);
  }
}
