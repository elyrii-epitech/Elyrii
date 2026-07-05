import '../../../core/network/api_client.dart';
import '../../../core/config/api_config.dart';
import '../../../core/constants/avatar_options.dart';
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

  /// Update the authenticated user's profile.
  Future<UserProfile> updateMe({
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
    final body = <String, dynamic>{};
    final uploadedPfp = pfp != null && isLocalAvatarPath(pfp)
        ? await uploadAvatar(pfp)
        : pfp;

    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (age != null) body['age'] = age;
    if (clearPfp) {
      body['pfp'] = null;
    } else if (uploadedPfp != null) {
      body['pfp'] = uploadedPfp;
    }
    if (bio != null) body['bio'] = bio;
    if (gender != null) body['gender'] = gender;
    if (pronouns != null) body['pronouns'] = pronouns;
    if (wellnessGoal != null) body['wellnessGoal'] = wellnessGoal;
    if (timezone != null) body['timezone'] = timezone;
    final response =
        await _client.put(ApiConfig.userMeUrl, body: body)
            as Map<String, dynamic>;
    return UserProfile.fromJson(response);
  }

  Future<String> uploadAvatar(String filePath) async {
    final response =
        await _client.uploadFile(
              ApiConfig.userAvatarUrl,
              fieldName: 'avatar',
              filePath: localAvatarFilePath(filePath),
            )
            as Map<String, dynamic>;
    return response['pfp'] as String;
  }

  Future<AppSettings> getSettings() async {
    final response =
        await _client.get(ApiConfig.userSettingsUrl) as Map<String, dynamic>;
    return AppSettings.fromJson(response);
  }

  Future<AppSettings> updateSettings({
    String? themeMode,
    bool? notificationsEnabled,
    bool? hapticsEnabled,
    String? privacyMode,
    String? language,
  }) async {
    final body = <String, dynamic>{};
    if (themeMode != null) body['themeMode'] = themeMode;
    if (notificationsEnabled != null) {
      body['notificationsEnabled'] = notificationsEnabled;
    }
    if (hapticsEnabled != null) body['hapticsEnabled'] = hapticsEnabled;
    if (privacyMode != null) body['privacyMode'] = privacyMode;
    if (language != null) body['language'] = language;

    final response =
        await _client.put(ApiConfig.userSettingsUrl, body: body)
            as Map<String, dynamic>;
    return AppSettings.fromJson(response);
  }
}
