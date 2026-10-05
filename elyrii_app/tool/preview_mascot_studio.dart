// Local visual review of the production studio with deterministic challenge
// progress. Run: flutter run -d chrome -t tool/preview_mascot_studio.dart
// Optional: --dart-define=PREVIEW_CHALLENGES=36 --dart-define=PREVIEW_DARK=true
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/gamification/data/models/gamification_models.dart';
import 'package:elyrii_app/features/gamification/data/repositories/gamification_repository.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/mascot/data/models/mascot_accessory.dart';
import 'package:elyrii_app/features/mascot/presentation/pages/mascot_customization_page.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';

class _PreviewChallenges extends GamificationRepository {
  _PreviewChallenges()
    : super(client: ApiClient(storage: SecureStorageService()));

  @override
  Future<List<ChallengeTemplate>> getAvailableChallenges() async => [];
  @override
  Future<List<UserChallenge>> getActiveChallenges() async => [];
  @override
  Future<List<UserChallenge>> getProposals() async => [];
  @override
  Future<List<UserChallenge>> getCompletedChallenges() async => List.generate(
    const int.fromEnvironment('PREVIEW_CHALLENGES', defaultValue: 12),
    (i) => UserChallenge(
      id: 'preview-$i',
      userId: 'preview',
      challengeId: 'preview-$i',
      status: 'COMPLETED',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(
    'elyrii_seen_cosmetic_unlocks_guest',
    MascotAccessories.all.map((piece) => piece.id).toList(),
  );
  runApp(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      adaptiveQuality: true,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MascotProvider()),
          ChangeNotifierProvider(
            create: (_) =>
                GamificationProvider(repository: _PreviewChallenges()),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: const bool.fromEnvironment('PREVIEW_DARK')
              ? ThemeMode.dark
              : ThemeMode.system,
          home: const MascotCustomizationPage(),
        ),
      ),
    ),
  );
}
