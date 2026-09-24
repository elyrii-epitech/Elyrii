/// Playground local du bouton « Mode Dev (Passer la connexion) ».
///
/// Donne assez de défis complétés pour débloquer toute la garde-robe
/// (le plus haut palier cosmétique est 5 défis) et un niveau Jardin
/// avancé : `1 + count ~/ 3` → niveau 5 (Lumière intérieure).
abstract final class DevSession {
  static const String userId = 'demo-user';
  static const String email = 'demo@elyrii.local';
  static const String firstName = 'Dorian';

  static const int completedChallengeCount = 12;
  static const int jardinLevel = 1 + completedChallengeCount ~/ 3;
  static const int totalPoints = completedChallengeCount * 50;
  static const int streakDays = 7;
}
