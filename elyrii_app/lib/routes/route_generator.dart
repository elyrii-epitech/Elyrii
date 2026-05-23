import 'package:flutter/material.dart';
import 'app_routes.dart';
import 'home_navigation.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/gamification/presentation/pages/challenges_page.dart';
import '../features/journal/presentation/pages/journal_page.dart';
import '../features/coach/presentation/pages/coach_page.dart';
import '../features/meditation/presentation/pages/meditation_page.dart';
import '../features/chatbot/presentation/pages/chatbot_page.dart';
import '../features/settings/pages/settings_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/mascot/presentation/pages/mascot_customization_page.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomeNavigation());

      case AppRoutes.dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardPage());

      case AppRoutes.challenges:
        return MaterialPageRoute(builder: (_) => const ChallengesPage());

      case AppRoutes.journal:
        return MaterialPageRoute(builder: (_) => const JournalPage());

      case AppRoutes.coach:
        return MaterialPageRoute(builder: (_) => const CoachPage());

      case AppRoutes.meditation:
        return MaterialPageRoute(builder: (_) => const MeditationPage());

      case AppRoutes.chatbot:
        return MaterialPageRoute(builder: (_) => const ChatbotPage());

      case AppRoutes.settings:
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const SettingsPage(),
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            final tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            final offsetAnimation = animation.drive(tween);
            final fadeAnimation = animation.drive(
              Tween(
                begin: 0.0,
                end: 1.0,
              ).chain(CurveTween(curve: const Interval(0.0, 0.5))),
            );
            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(opacity: fadeAnimation, child: child),
            );
          },
        );

      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case AppRoutes.register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());

      case AppRoutes.mascotCustom:
        return MaterialPageRoute(builder: (_) => const MascotCustomizationPage());

      default:
        return _errorRoute(settings.name);
    }
  }

  static Route<dynamic> _errorRoute(String? routeName) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              const Text(
                'Route non trouvée',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                routeName ?? 'Unknown route',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
