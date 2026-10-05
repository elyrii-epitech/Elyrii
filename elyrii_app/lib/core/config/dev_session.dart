import '../../features/mascot/data/models/mascot_accessory.dart';

/// Local development session adapted from Lucas's studio. Its data never
/// reaches the backend or another account's preferences.
abstract final class DevSession {
  static const userId = 'demo-user';
  static const email = 'demo@elyrii.local';
  static const firstName = 'Dorian';
  static int get completedChallengeCount =>
      MascotAccessories.maxRequiredChallenges;
  static int get jardinLevel => 1 + completedChallengeCount ~/ 3;
  static int get totalPoints => completedChallengeCount * 50;
  static const streakDays = 7;
}
