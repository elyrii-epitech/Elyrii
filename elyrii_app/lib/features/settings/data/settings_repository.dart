import '../../../core/network/json_response.dart';
import '../../../core/data/json_contract.dart';
import '../../../core/network/api_client.dart';

import 'package:cross_file/cross_file.dart';

import '../../../core/config/api_config.dart';
import '../../../core/constants/avatar_options.dart';
import '../models/app_settings.dart';
import '../models/user_profile.dart';

/// Repository handling user profile API calls
class UserRepository {
  final ApiClient _client;

  UserRepository({required this._client});

  /// Fetch the authenticated user's profile
  Future<UserProfile> getMe() async {
    final response = await _client.get(ApiConfig.userMeUrl);
    return decodeResponse(response, UserProfile.fromJson);
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
    final context = _client.sessionGeneration;
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
    _client.ensureSession(context);
    final response = await _client.put(ApiConfig.userMeUrl, body: body);
    return decodeResponse(response, UserProfile.fromJson);
  }

  Future<String> uploadAvatar(String filePath) async {
    final response = await _client.uploadXFile(
      ApiConfig.userAvatarUrl,
      fieldName: 'avatar',
      file: XFile(
        localAvatarFilePath(filePath),
        name: filePath.startsWith('blob:') || filePath.startsWith('data:')
            ? 'avatar.png'
            : null,
      ),
    );
    return decodeResponse(
      response,
      (json) => requiredJsonString(json['pfp'], 'pfp'),
    );
  }

  Future<AppSettings> getSettings() async {
    final response = await _client.get(ApiConfig.userSettingsUrl);
    return decodeResponse(response, AppSettings.fromJson);
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

    final response = await _client.put(ApiConfig.userSettingsUrl, body: body);
    return decodeResponse(response, AppSettings.fromJson);
  }

  Future<void> deleteAccount({required String password}) async {
    await _client.delete(
      ApiConfig.userAccountUrl,
      body: {'password': password},
    );
  }
}
