/// User profile model matching the backend user service response.
class UserProfile {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final int? age;
  final String? pfp;
  final String? bio;
  final String? gender;
  final String? pronouns;
  final String? wellnessGoal;
  final String? timezone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.age,
    this.pfp,
    this.bio,
    this.gender,
    this.pronouns,
    this.wellnessGoal,
    this.timezone,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      age: json['age'] as int?,
      pfp: json['pfp'] as String?,
      bio: json['bio'] as String?,
      gender: json['gender'] as String?,
      pronouns: json['pronouns'] as String?,
      wellnessGoal: json['wellnessGoal'] as String?,
      timezone: json['timezone'] as String?,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'age': age,
    'pfp': pfp,
    'bio': bio,
    'gender': gender,
    'pronouns': pronouns,
    'wellnessGoal': wellnessGoal,
    'timezone': timezone,
  };

  String get displayName {
    if (firstName != null && firstName!.isNotEmpty) {
      final last = (lastName != null && lastName!.isNotEmpty)
          ? ' $lastName'
          : '';
      return '$firstName$last';
    }
    return email.split('@').first;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
