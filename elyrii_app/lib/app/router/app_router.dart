import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/chatbot/presentation/pages/chatbot_page.dart';
import '../../features/coach/presentation/pages/coach_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/gamification/presentation/pages/challenges_page.dart';
import '../../features/journal/presentation/pages/journal_page.dart';
import '../../features/mascot/presentation/pages/mascot_customization_page.dart';
import '../../features/meditation/presentation/pages/meditation_page.dart';
import '../../features/meditation/presentation/pages/meditation_session_page.dart';
import '../../features/profile_setup/presentation/pages/avatar_picker_page.dart';
import '../../features/profile_setup/presentation/pages/edit_profile_page.dart';
import '../../features/profile_setup/presentation/pages/profile_setup_page.dart';
import '../../features/reviews/presentation/pages/reviews_page.dart';
import '../../features/settings/pages/settings_page.dart';
import 'app_routes.dart';
import 'app_shell.dart';
import 'page_transitions.dart';

/// Listenable composite regroupant l'état d'authentification et le statut de profil.
class _CompositeListenable extends ChangeNotifier {
  final List<Listenable> _listenables;

  _CompositeListenable(this._listenables) {
    for (final l in _listenables) {
      l.addListener(notifyListeners);
    }
  }

  @override
  void dispose() {
    for (final l in _listenables) {
      l.removeListener(notifyListeners);
    }
    super.dispose();
  }
}

/// Créateur et configurateur du routeur déclaratif moderne [GoRouter].
abstract final class AppRouter {
  static GoRouter createRouter({
    required AuthProvider authProvider,
    required ValueNotifier<bool> profileSetupDone,
  }) {
    return GoRouter(
      initialLocation: AppRoutes.home,
      refreshListenable: _CompositeListenable([authProvider, profileSetupDone]),
      redirect: (BuildContext context, GoRouterState state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final location = state.matchedLocation;
        final isAuthRoute =
            location == AppRoutes.login || location == AppRoutes.register;
        final setupDone = profileSetupDone.value;

        // Utilisateur non connecté tentant d'accéder à l'application
        if (!isAuthenticated) {
          return isAuthRoute ? null : AppRoutes.login;
        }

        // Utilisateur connecté tentant d'accéder aux écrans d'authentification
        if (isAuthRoute) {
          return setupDone ? AppRoutes.home : AppRoutes.profileSetup;
        }

        // Onboarding profil obligatoire avant le reste de l'application
        if (!setupDone && location != AppRoutes.profileSetup) {
          return AppRoutes.profileSetup;
        }

        return null;
      },
      routes: [
        // Shell persistant pour les 5 onglets principaux + chatbot
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppShell(navigationShell: navigationShell);
          },
          branches: [
            // Onglet 0 : Accueil (Dashboard)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  builder: (context, state) => const DashboardPage(),
                ),
              ],
            ),
            // Onglet 1 : Jardin (Gamification / Défis)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.challenges,
                  builder: (context, state) => const ChallengesPage(),
                ),
              ],
            ),
            // Onglet 2 : Journal
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.journal,
                  builder: (context, state) => const JournalPage(),
                ),
              ],
            ),
            // Onglet 3 : Méditation & Cohérence cardiaque
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.meditation,
                  builder: (context, state) => const MeditationPage(),
                ),
              ],
            ),
            // Onglet 4 : Coach bien-être
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.coach,
                  builder: (context, state) => const CoachPage(),
                ),
              ],
            ),
            // Branche 5 : Chatbot (Bulle flottante)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.chatbot,
                  builder: (context, state) => const ChatbotPage(),
                ),
              ],
            ),
          ],
        ),

        // Routes d'authentification
        GoRoute(
          path: AppRoutes.login,
          pageBuilder: (context, state) => ElyriiPageTransitions.slideFromRight(
            key: state.pageKey,
            name: state.name,
            child: const LoginPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.register,
          pageBuilder: (context, state) => ElyriiPageTransitions.slideFromRight(
            key: state.pageKey,
            name: state.name,
            child: const RegisterPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.profileSetup,
          pageBuilder: (context, state) => ElyriiPageTransitions.slideFromRight(
            key: state.pageKey,
            name: state.name,
            child: const ProfileSetupPage(),
          ),
        ),

        // Routes secondaires plein écran (hors shell onglets)
        GoRoute(
          path: AppRoutes.reviews,
          pageBuilder: (context, state) => ElyriiPageTransitions.slideFromRight(
            key: state.pageKey,
            name: state.name,
            child: const ReviewsPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.mascotCustomization,
          pageBuilder: (context, state) => ElyriiPageTransitions.slideFromRight(
            key: state.pageKey,
            name: state.name,
            child: const MascotCustomizationPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) => ElyriiPageTransitions.slideFromRight(
            key: state.pageKey,
            name: state.name,
            child: const SettingsPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.editProfile,
          pageBuilder: (context, state) => ElyriiPageTransitions.slideFromRight(
            key: state.pageKey,
            name: state.name,
            child: const EditProfilePage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.avatarPicker,
          pageBuilder: (context, state) => ElyriiPageTransitions.slideFromRight(
            key: state.pageKey,
            name: state.name,
            child: const AvatarPickerPage(),
          ),
        ),

        // Session de méditation immersive (hors shell : aucun dock)
        GoRoute(
          path: AppRoutes.meditationSession,
          pageBuilder: (context, state) => ElyriiPageTransitions.slideFromRight(
            key: state.pageKey,
            name: state.name,
            child: MeditationSessionPage(
              controller: state.extra! as MeditationController,
            ),
          ),
        ),
      ],
    );
  }
}
