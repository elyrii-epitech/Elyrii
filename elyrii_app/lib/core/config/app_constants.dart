/// Global constants used throughout the Elyrii application.
class AppConstants {
  AppConstants._();

  // ==================== INFORMATIONS APP ====================

  static const String appName = 'Elyrii';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Votre compagnon bien-être personnel';

  // ==================== URLS & API ====================

  static const String baseUrl =
      'http://localhost:3000'; // À remplacer plus tard
  static const String apiVersion = 'v1';
  static const String apiBaseUrl = baseUrl;

  // ==================== STORAGE KEYS ====================

  /// Authentication token key.
  static const String storageKeyAuthToken = 'auth_token';

  /// User information key.
  static const String storageKeyUser = 'user_data';

  /// Theme preference key.
  static const String storageKeyThemeMode = 'theme_mode';

  /// Journal entry key for the local cache.
  static const String storageKeyJournalEntries = 'journal_entries';

  /// Goals key.
  static const String storageKeyObjectives = 'objectives';

  /// Chatbot history key.
  static const String storageKeyChatHistory = 'chat_history';

  /// Notification preferences key.
  static const String storageKeyNotificationPrefs = 'notification_prefs';

  /// Onboarding key.
  static const String storageKeyOnboardingCompleted = 'onboarding_completed';

  /// Language key.
  static const String storageKeyLanguage = 'language';

  // ==================== TIMEOUTS ====================

  /// Network request timeout in seconds.
  static const int networkTimeout = 30;

  /// Connection timeout in seconds.
  static const int connectionTimeout = 15;

  /// Splash screen duration in seconds.
  static const int splashDuration = 3;

  // ==================== LIMITES ====================

  /// Maximum journal title length in characters.
  static const int maxJournalTitleLength = 100;

  /// Maximum journal content length in characters.
  static const int maxJournalContentLength = 5000;

  /// Maximum goal length in characters.
  static const int maxObjectiveTitleLength = 150;

  /// Maximum number of messages in chatbot history.
  static const int maxChatHistoryLength = 100;

  /// Maximum number of photos per journal entry.
  static const int maxPhotosPerJournalEntry = 5;

  // ==================== PAGINATION ====================

  /// Default number of items per page.
  static const int defaultPageSize = 20;

  /// Number of journal entries to load per page.
  static const int journalEntriesPageSize = 15;

  /// Number of goals to load per page.
  static const int objectivesPageSize = 10;

  // ==================== MÉDITATION ====================

  /// Preset meditation durations in minutes.
  static const List<int> meditationDurations = [5, 10, 15, 20, 30];

  /// Meditation types.
  static const List<String> meditationTypes = [
    'Respiration',
    'Body Scan',
    'Visualisation',
    'Pleine Conscience',
    'Sons Apaisants',
  ];

  // ==================== OBJECTIFS ====================

  /// Goal types.
  static const List<String> objectiveTypes = [
    'Quotidien',
    'Hebdomadaire',
    'Mensuel',
    'Personnel',
  ];

  /// Goal categories.
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

  /// XP points per action.
  static const int xpPerJournalEntry = 10;
  static const int xpPerObjectiveCompleted = 25;
  static const int xpPerMeditationSession = 15;
  static const int xpPerChatbotInteraction = 5;
  static const int xpPerDailyLogin = 5;

  /// XP required to level up.
  static const int xpPerLevel = 100;

  /// Number of days in a streak.
  static const int minStreakDays = 3;

  // ==================== NOTIFICATIONS ====================

  /// Notification types.
  static const String notifTypeReminder = 'reminder';
  static const String notifTypeObjective = 'objective';
  static const String notifTypeMeditation = 'meditation';
  static const String notifTypeDaily = 'daily';

  /// Default times for daily notifications.
  static const int defaultNotificationHour = 20; // 20h
  static const int defaultNotificationMinute = 0;

  // ==================== FORMATS ====================

  /// Display date format.
  static const String dateFormatDisplay = 'dd MMM yyyy';

  /// Date and time format.
  static const String dateTimeFormatDisplay = 'dd MMM yyyy à HH:mm';

  /// Short date format.
  static const String dateFormatShort = 'dd/MM/yyyy';

  /// Time format.
  static const String timeFormat = 'HH:mm';

  // ==================== REGEX ====================

  /// Regular expression for email validation.
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Regular expression for password validation: at least eight characters, one
  /// uppercase letter, one lowercase letter, and one digit.
  static final RegExp passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{8,}$',
  );

  // ==================== MESSAGES ====================

  /// Generic error messages.
  static const String errorGeneric =
      'Une erreur est survenue. Veuillez réessayer.';
  static const String errorNetwork =
      'Erreur de connexion. Vérifiez votre connexion internet.';
  static const String errorTimeout =
      'Délai d\'attente dépassé. Veuillez réessayer.';
  static const String errorUnauthorized =
      'Session expirée. Veuillez vous reconnecter.';

  /// Generic success messages.
  static const String successSaved = 'Enregistré avec succès !';
  static const String successDeleted = 'Supprimé avec succès !';
  static const String successUpdated = 'Mis à jour avec succès !';

  // ==================== MASCOTTE ====================

  /// Mascot states.
  static const String mascotStateHappy = 'happy';
  static const String mascotStateSad = 'sad';
  static const String mascotStateExcited = 'excited';
  static const String mascotStateCalm = 'calm';
  static const String mascotStateSleeping = 'sleeping';

  /// Mascot welcome messages.
  static const List<String> mascotWelcomeMessages = [
    'Bonjour ! Comment te sens-tu aujourd\'hui ?',
    'Content de te revoir ! 😊',
    'Prêt à passer une belle journée ?',
    'Je suis là pour toi ! 💜',
  ];

  // ==================== ROUTES ====================

  /// Navigation routes, unless defined elsewhere.
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
}
