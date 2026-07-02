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
  ///
  /// ┌──────────────────────────────────────────────────────────────────┐
  // │ BACKEND TEAM: PROBLEME CONNU - quand [pfp] est null (l'utilisateur │
  // │ choisit la mascotte), le champ n'est pas envoye au backend (ligne  │
  // │ `if (pfp != null)`). Si l'utilisateur avait deja une URL d'avatar, │
  // │ elle ne sera PAS effacee.                                          │
  // │                                                                    │
  // │ Solution proposee: ajouter un parametre [clearPfp] ou accepter une │
  // │ string vide "" pour forcer la reinitialisation. Le backend (zod    │
  // │ `updateProfileValidation`) devra aussi accepter "" au lieu de      │
  // │ `.url().optional()` strict.                                        │
  // │                                                                    │
  // │ NOUVEAUX CHAMPS: [bio], [gender], [pronouns], [wellnessGoal],      │
  // │ [timezone] doivent etre ajoutes au schema zod et a la table users. │
  // │                                                                    │
  // │ UPLOAD D'AVATAR: Quand l'utilisateur importe une image personnelle,│
  // │ [pfp] contient le path local du fichier (file://...). Il faudra    │
  // │ un endpoint d'upload (ex: POST /user/avatar) qui retourne une URL, │
  // │ puis stocker cette URL dans `pfp`. Voir avatar_picker_page.dart.   │
  // └──────────────────────────────────────────────────────────────────┘
  Future<UserProfile> updateMe({
    String? firstName,
    String? lastName,
    int? age,
    String? pfp,
    String? bio,
    String? gender,
    String? pronouns,
    String? wellnessGoal,
    String? timezone,
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (age != null) body['age'] = age;
    if (pfp != null) body['pfp'] = pfp;
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
