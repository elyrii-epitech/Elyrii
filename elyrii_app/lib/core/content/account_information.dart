/// Shared account information shown before signup and from settings.
/// These descriptions do not substitute for unpublished legal documents.
abstract final class AccountInformation {
  static const serviceTitle = 'À propos d’Elyrii';
  static const service =
      'Elyrii propose un journal, des exercices et une conversation avec une IA. '
      'Les réponses de l’IA peuvent être inexactes et ne remplacent pas un professionnel de santé. '
      'Les conditions d’utilisation de cette version ne sont pas encore publiées.';

  static const dataTitle = 'Utilisation des données';
  static const data =
      'Ton profil et tes notes sont envoyés au serveur. Une copie protégée du journal est conservée sur cet appareil. '
      'Les messages envoyés à Elyrii sont transmis au serveur et à l’IA pour préparer une réponse. '
      'L’historique affiché et la progression des programmes sont conservés sur cet appareil. '
      'Les réglages donnent accès à l’export et à la suppression du compte. '
      'La politique de confidentialité complète de cette version n’est pas encore publiée.';
}
