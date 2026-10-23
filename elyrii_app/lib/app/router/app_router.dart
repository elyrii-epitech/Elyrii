import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/password_reset_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/chatbot/presentation/pages/chatbot_page.dart';
import '../../features/parcours/presentation/pages/parcours_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/gamification/presentation/pages/challenges_page.dart';
import '../../features/journal/presentation/pages/journal_page.dart';
import '../../features/meditation/presentation/pages/meditation_page.dart';
import '../../features/meditation/presentation/pages/meditation_session_page.dart';
import '../../features/profile_setup/presentation/pages/avatar_picker_page.dart';
import '../../features/profile_setup/presentation/pages/edit_profile_page.dart';
import '../../features/profile_setup/presentation/pages/profile_setup_page.dart';
import '../../features/profile_setup/presentation/pages/profile_page.dart';
import '../../features/reviews/presentation/pages/reviews_page.dart';
import '../../features/settings/pages/settings_page.dart';
import 'app_routes.dart';
import 'app_shell.dart';
import 'page_transitions.dart';

/// The router releases its subscriptions when disposed; no permanent wrapper
/// subscriptions are installed on the source notifiers.
class _CompositeListenable extends ChangeNotifier {
  final List<Listenable> _listenables;

  _CompositeListenable(this._listenables);
  @override
  void addListener(VoidCallback listener) {
    for (final source in _listenables) {
      source.addListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    for (final source in _listenables) {
      source.removeListener(listener);
    }
  }
}

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
            location == AppRoutes.login ||
            location == AppRoutes.register ||
            location == AppRoutes.passwordReset;
        final setupDone = profileSetupDone.value;

        if (!isAuthenticated) {
          return isAuthRoute ? null : AppRoutes.login;
        }

        if (isAuthRoute) {
          return setupDone ? AppRoutes.home : AppRoutes.profileSetup;
        }

        if (!setupDone &&
            location != AppRoutes.profileSetup &&
            location != AppRoutes.avatarPicker) {
          return AppRoutes.profileSetup;
        }

        return null;
      },
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  builder: (context, state) => const DashboardPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.challenges,
                  builder: (context, state) => const ChallengesPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.journal,
                  builder: (context, state) => const JournalPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.meditation,
                  builder: (context, state) => const MeditationPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.parcours,
                  builder: (context, state) => const ParcoursPage(),
                ),
              ],
            ),
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

        GoRoute(
          path: AppRoutes.passwordReset,
          pageBuilder: (context, state) => ElyriiPageTransitions.slideFromRight(
            key: state.pageKey,
            name: state.name,
            child: const PasswordResetPage(),
          ),
        ),
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

        GoRoute(
          path: AppRoutes.profile,
          pageBuilder: (context, state) => ElyriiPageTransitions.slideFromLeft(
            key: state.pageKey,
            name: state.name,
            reduced: MediaQuery.disableAnimationsOf(context),
            child: const ProfilePage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.reviews,
          pageBuilder: (context, state) => ElyriiPageTransitions.slideFromRight(
            key: state.pageKey,
            name: state.name,
            child: const ReviewsPage(),
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
            child: AvatarPickerPage(
              currentPfp: state.extra is String ? state.extra as String : null,
            ),
          ),
        ),

        GoRoute(
          path: AppRoutes.meditationSession,
          redirect: (context, state) =>
              state.extra is MeditationController ? null : AppRoutes.meditation,
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
