/// Constantes globales de l'application Elyrii
/// Définit toutes les valeurs constantes utilisées dans l'application
class AppConstants {
  AppConstants._();

  // ==================== INFORMATIONS APP ====================
  
  static const String appName = 'Elyrii';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Votre compagnon bien-être personnel';
  
  // ==================== URLS & API ====================
  
  static const String baseUrl = 'https://api.elyrii.com'; // À remplacer plus tard
  static const String apiVersion = 'v1';
  static const String apiBaseUrl = '$baseUrl/api/$apiVersion';
  
  // ==================== STORAGE KEYS ====================
  
  /// Clé pour le token d'authentification
  static const String storageKeyAuthToken = 'auth_token';
  
  /// Clé pour les informations utilisateur
  static const String storageKeyUser = 'user_data';
  
  /// Clé pour la préférence de thème
  static const String storageKeyThemeMode = 'theme_mode';
  
  /// Clé pour les entrées de journal (cache local)
  static const String storageKeyJournalEntries = 'journal_entries';
  
  /// Clé pour les objectifs
  static const String storageKeyObjectives = 'objectives';
  
  /// Clé pour l'historique du chatbot
  static const String storageKeyChatHistory = 'chat_history';
  
  /// Clé pour les préférences de notifications
  static const String storageKeyNotificationPrefs = 'notification_prefs';
  
  /// Clé pour le onboarding
  static const String storageKeyOnboardingCompleted = 'onboarding_completed';
  
  /// Clé pour la langue
  static const String storageKeyLanguage = 'language';

  // ==================== TIMEOUTS ====================
  
  /// Timeout pour les requêtes réseau (en secondes)
  static const int networkTimeout = 30;
  
  /// Timeout pour la connexion (en secondes)
  static const int connectionTimeout = 15;
  
  /// Durée du splash screen (en secondes)
  static const int splashDuration = 3;

  // ==================== LIMITES ====================
  
  /// Nombre maximum de caractères pour le titre du journal
  static const int maxJournalTitleLength = 100;
  
  /// Nombre maximum de caractères pour le contenu du journal
  static const int maxJournalContentLength = 5000;
  
  /// Nombre maximum de caractères pour un objectif
  static const int maxObjectiveTitleLength = 150;
  
  /// Nombre maximum de messages dans l'historique du chatbot
  static const int maxChatHistoryLength = 100;
  
  /// Nombre maximum de photos par entrée de journal
  static const int maxPhotosPerJournalEntry = 5;

  // ==================== PAGINATION ====================
  
  /// Nombre d'éléments par page par défaut
  static const int defaultPageSize = 20;
  
  /// Nombre d'entrées de journal à charger par page
  static const int journalEntriesPageSize = 15;
  
  /// Nombre d'objectifs à charger par page
  static const int objectivesPageSize = 10;

  // ==================== ÉMOTIONS ====================
  
  /// Liste des émotions disponibles
  static const List<String> emotions = [
    'Joyeux',
    'Triste',
    'Anxieux',
    'Calme',
    'Énervé',
    'Excité',
    'Fatigué',
    'Neutre',
  ];
  
  /// Emojis correspondant aux émotions
  static const Map<String, String> emotionEmojis = {
    'Joyeux': '😊',
    'Triste': '😢',
    'Anxieux': '😰',
    'Calme': '😌',
    'Énervé': '😠',
    'Excité': '🤩',
    'Fatigué': '😴',
    'Neutre': '😐',
  };

  // ==================== MÉDITATION ====================
  
  /// Durées de méditation prédéfinies (en minutes)
  static const List<int> meditationDurations = [5, 10, 15, 20, 30];
  
  /// Types de méditation
  static const List<String> meditationTypes = [
    'Respiration',
    'Body Scan',
    'Visualisation',
    'Pleine Conscience',
    'Sons Apaisants',
  ];

  // ==================== OBJECTIFS ====================
  
  /// Types d'objectifs
  static const List<String> objectiveTypes = [
    'Quotidien',
    'Hebdomadaire',
    'Mensuel',
    'Personnel',
  ];
  
  /// Catégories d'objectifs
  static const List<String> objectiveCategories = [
    'Bien-être',
    'Sport',
    'Sommeil',
    'Alimentation',
    'Social',
    'Créatif',
    'Professionnel',
    'Autre',
  ];

  // ==================== GAMIFICATION ====================
  
  /// Points XP par action
  static const int xpPerJournalEntry = 10;
  static const int xpPerObjectiveCompleted = 25;
  static const int xpPerMeditationSession = 15;
  static const int xpPerChatbotInteraction = 5;
  static const int xpPerDailyLogin = 5;
  
  /// XP requis pour monter de niveau
  static const int xpPerLevel = 100;
  
  /// Nombre de jours pour un streak
  static const int minStreakDays = 3;

  // ==================== NOTIFICATIONS ====================
  
  /// Types de notifications
  static const String notifTypeReminder = 'reminder';
  static const String notifTypeObjective = 'objective';
  static const String notifTypeMeditation = 'meditation';
  static const String notifTypeDaily = 'daily';
  
  /// Heures par défaut pour les notifications quotidiennes
  static const int defaultNotificationHour = 20; // 20h
  static const int defaultNotificationMinute = 0;

  // ==================== FORMATS ====================
  
  /// Format de date pour l'affichage
  static const String dateFormatDisplay = 'dd MMM yyyy';
  
  /// Format de date avec heure
  static const String dateTimeFormatDisplay = 'dd MMM yyyy à HH:mm';
  
  /// Format de date court
  static const String dateFormatShort = 'dd/MM/yyyy';
  
  /// Format d'heure
  static const String timeFormat = 'HH:mm';

  // ==================== REGEX ====================
  
  /// Expression régulière pour valider un email
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  
  /// Expression régulière pour valider un mot de passe
  /// (min 8 caractères, 1 majuscule, 1 minuscule, 1 chiffre)
  static final RegExp passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{8,}$',
  );

  // ==================== MESSAGES ====================
  
  /// Messages d'erreur génériques
  static const String errorGeneric = 'Une erreur est survenue. Veuillez réessayer.';
  static const String errorNetwork = 'Erreur de connexion. Vérifiez votre connexion internet.';
  static const String errorTimeout = 'Délai d\'attente dépassé. Veuillez réessayer.';
  static const String errorUnauthorized = 'Session expirée. Veuillez vous reconnecter.';
  
  /// Messages de succès génériques
  static const String successSaved = 'Enregistré avec succès !';
  static const String successDeleted = 'Supprimé avec succès !';
  static const String successUpdated = 'Mis à jour avec succès !';

  // ==================== MASCOTTE ====================
  
  /// États de la mascotte
  static const String mascotStateHappy = 'happy';
  static const String mascotStateSad = 'sad';
  static const String mascotStateExcited = 'excited';
  static const String mascotStateCalm = 'calm';
  static const String mascotStateSleeping = 'sleeping';
  
  /// Messages de bienvenue de la mascotte
  static const List<String> mascotWelcomeMessages = [
    'Bonjour ! Comment te sens-tu aujourd\'hui ?',
    'Content de te revoir ! 😊',
    'Prêt à passer une belle journée ?',
    'Je suis là pour toi ! 💜',
  ];

  // ==================== ROUTES ====================
  
  /// Routes de navigation (si non définies ailleurs)
  static const String routeSplash = '/splash';
  static const String routeOnboarding = '/onboarding';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeHome = '/home';
  static const String routeJournal = '/journal';
  static const String routeJournalCreate = '/journal/create';
  static const String routeObjectives = '/objectives';
  static const String routeMeditation = '/meditation';
  static const String routeChatbot = '/chatbot';
  static const String routeProfile = '/profile';
  static const String routeSettings = '/settings';

  // ==================== ASSETS ====================
  
  /// Chemins des assets (backup si asset_paths.dart n'existe pas)
  static const String assetMascot = 'assets/mascotte.png';
  static const String assetMascotEyesClosed = 'assets/mascotte_eyes_closed.png';
}
