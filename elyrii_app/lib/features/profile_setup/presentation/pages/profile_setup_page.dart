import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/mascot_themes.dart';
import '../../../../core/constants/profile_option_labels.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/accueil_scene.dart';
import '../../../../routes/app_routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/arrival_widgets.dart';
import '../../../dashboard/data/accueil_activities.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../mascot/data/models/mascot_appearance.dart';
import '../../../mascot/data/models/mascot_model.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../widgets/profile_controls.dart';

enum _Step {
  name('On fait connaissance', 'Ton prénom', Icons.waving_hand_outlined),
  goal('Ton objectif', 'Choisis un objectif', Icons.favorite_outline_rounded),
  mood('Ton humeur du moment', 'Ton humeur', Icons.mood_rounded),
  look('L’apparence d’Elyrii', 'Décor et tenue', Icons.checkroom_rounded);

  final String title;
  final String detail;
  final IconData icon;
  const _Step(this.title, this.detail, this.icon);
}

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});
  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  _Step _step = _Step.name;
  final _name = TextEditingController();
  String? _goal;
  MoodType? _mood;
  late MascotModel _draft;
  late MascotModel _original;
  late int _session;
  MascotDecor _decor = MascotDecor.arches;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().profile;
    _name.text = user?.firstName ?? '';
    _goal = user?.wellnessGoal;
    final mascot = context.read<MascotProvider>();
    _draft = _original = mascot.mascot;
    _session = mascot.sessionRevision;
    _decor = context.read<AccueilActivities>().snapshot.decor;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    if (_busy) return;
    if (_step.index > 0) {
      setState(() {
        _step = _Step.values[_step.index - 1];
        _error = null;
      });
    } else {
      await context.read<AuthProvider>().logout();
      if (mounted) context.go(AppRoutes.login);
    }
  }

  Future<void> _next({bool skip = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final user = context.read<UserProvider>();
    final dashboard = context.read<DashboardProvider>();
    try {
      if (!skip && (_step == _Step.name || _step == _Step.goal)) {
        final name = _name.text.trim();
        if ((_step == _Step.name && name.isNotEmpty) ||
            (_step == _Step.goal && _goal != null)) {
          final saved = await user.updateProfile(
            firstName: _step == _Step.name ? name : null,
            wellnessGoal: _step == _Step.goal ? _goal : null,
          );
          if (!saved) {
            if (mounted) {
              setState(
                () => _error =
                    user.error ??
                    'Ton profil n’a pas été enregistré. Réessaie.',
              );
            }
            return;
          }
        }
      }
      if (!skip && _step == _Step.mood && _mood != null) {
        if (dashboard.selectedMood != _mood &&
            !await dashboard.selectMood(_mood!)) {
          if (mounted) {
            setState(
              () => _error =
                  dashboard.error ??
                  'Ton humeur n’a pas été enregistrée. Réessaie.',
            );
          }
          return;
        }
      }
      if (!mounted) return;
      if (_step == _Step.look) {
        final mascot = context.read<MascotProvider>();
        final store = context.read<AccueilActivities>();
        final storage = context.read<SecureStorageService>();
        final saved = await mascot.saveCustomization(
          _draft,
          completedChallenges: 0,
          expectedSessionRevision: _session,
        );
        if (!mounted) return;
        if (!saved || !await store.setDecor(_decor, completedChallenges: 0)) {
          if (saved) {
            await mascot.saveCustomization(
              _original,
              completedChallenges: 0,
              expectedSessionRevision: _session,
            );
          }
          if (mounted) {
            setState(
              () => _error =
                  store.snapshot.error ??
                  mascot.error ??
                  'L’apparence n’a pas été enregistrée. Réessaie.',
            );
          }
          return;
        }
        await storage.setProfileSetupCompleted();
        if (!mounted) return;
        context.read<ValueNotifier<bool>>().value = true;
        context.go(AppRoutes.home);
      } else {
        setState(() => _step = _Step.values[_step.index + 1]);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'L’enregistrement n’a pas abouti. Réessaie.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppColors.primaryDark : AppColors.primary;
    final name = _name.text.trim();
    final question = switch (_step) {
      _Step.name => 'Salut, moi c’est Elyrii.\nComment je peux t’appeler ?',
      _Step.goal =>
        '${name.isEmpty ? 'Enchanté.' : 'Enchanté, $name.'}\nQu’est-ce qui t’amène ici ?',
      _Step.mood => 'Comment tu te sens,\nlà, maintenant ?',
      _Step.look =>
        'Choisis l’apparence d’Elyrii.\nTu pourras la modifier plus tard.',
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: ArrivalFrame(
        key: ValueKey(_step),
        title: _step == _Step.name
            ? 'Bienvenue sur Elyrii'
            : '${_step.index + 1} sur 4',
        onBack: _back,
        onInfo: () => showArrivalSteps(context),
        mascot: _draft,
        decor: _decor,
        scrollThreshold: _step == _Step.goal
            ? AppDimensions.arrivalGoalThreshold
            : AppDimensions.arrivalStepThreshold,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: TextButton.icon(
                onPressed: () => showArrivalSteps(context),
                icon: Icon(_step.icon, size: AppDimensions.iconSm),
                label: Text(_step.title),
              ),
            ),
            const SizedBox(height: AppDimensions.spacing12),
            LinearProgressIndicator(
              value: (_step.index + 1) / _Step.values.length,
              minHeight: AppDimensions.arrivalProgressHeight,
              color: accent,
              backgroundColor: AppColors.track(dark),
              borderRadius: BorderRadius.circular(AppDimensions.radius4),
            ),
            const SizedBox(height: AppDimensions.spacing8),
            Text(
              '${_step.index + 1} sur 4 · ${_step.detail}',
              style: AppTextStyles.labelSmall(color: context.textTertiary),
            ),
            const SizedBox(height: AppDimensions.spacing16),
            ProfileCard(
              padding: const EdgeInsets.all(AppDimensions.spacing12),
              child: Row(
                children: [
                  Image.asset(
                    'assets/splash_icon.png',
                    width: AppDimensions.journalTool,
                    height: AppDimensions.journalTool,
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: Text(
                      question,
                      style: AppTextStyles.bodyLarge(
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacing16),
            switch (_step) {
              _Step.name => ArrivalField(
                controller: _name,
                label: 'Prénom',
                icon: Icons.person_outline_rounded,
                autofillHints: const [AutofillHints.givenName],
                textInputAction: TextInputAction.done,
                enabled: !_busy,
                onSubmitted: (_) => _next(),
              ),
              _Step.goal => _goals(dark),
              _Step.mood => _moods(dark),
              _Step.look => _look(dark),
            },
            ArrivalFeedback(_error),
            const SizedBox(height: AppDimensions.spacing16),
            ArrivalButton(
              label: _step == _Step.look ? 'Commencer' : 'Continuer',
              icon: Icons.arrow_forward_rounded,
              busy: _busy,
              onPressed: _next,
            ),
            if (_step != _Step.look)
              TextButton(
                onPressed: _busy ? null : () => _next(skip: true),
                child: const Text('Passer'),
              ),
            const SizedBox(height: AppDimensions.spacing12),
            if (_step != _Step.goal)
              Text(
                switch (_step) {
                  _Step.name => 'Utilise le prénom ou le nom de ton choix.',
                  _Step.mood => 'Tu pourras me le dire chaque jour.',
                  _Step.look =>
                    'Tu pourras modifier l’apparence depuis l’Accueil.',
                  _Step.goal => '',
                },
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall(color: context.textTertiary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _goals(bool dark) => ProfileCard(
    padding: EdgeInsets.zero,
    child: RadioGroup<String>(
      groupValue: _goal,
      onChanged: (value) => setState(() => _goal = value),
      child: Column(
        children: [
          for (final (index, goal) in wellnessGoals.indexed) ...[
            if (index > 0)
              const Divider(
                height: AppDimensions.borderWidthThin,
                indent: AppDimensions.spacing48,
              ),
            RadioListTile<String>(
              value: goal,
              enabled: !_busy,
              title: Text(
                profileOptionLabel(goal),
                style: AppTextStyles.bodyMedium(color: context.textPrimary),
              ),
              secondary: Icon(
                const [
                  Icons.air_rounded,
                  Icons.bedtime_rounded,
                  Icons.spa_rounded,
                  Icons.self_improvement_rounded,
                  Icons.favorite_rounded,
                  Icons.explore_rounded,
                ][index],
                color: [
                  AppColors.teal(dark),
                  AppColors.violet(dark),
                  AppColors.green(dark),
                  AppColors.orange(dark),
                  AppColors.pink(dark),
                  AppColors.yellow(dark),
                ][index],
              ),
              controlAffinity: ListTileControlAffinity.trailing,
            ),
          ],
        ],
      ),
    ),
  );

  Widget _moods(bool dark) => Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final mood in MoodType.values)
            Expanded(
              child: Semantics(
                selected: _mood == mood,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppDimensions.radius14),
                  onTap: _busy ? null : () => setState(() => _mood = mood),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.spacing8,
                    ),
                    child: Column(
                      children: [
                        AnimatedScale(
                          scale: _mood == mood
                              ? AppDimensions.accueilMoodFaceSelectedScale
                              : 1,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : AppMotion.moodFaceTap,
                          curve: AppMotion.accueilEase,
                          child: Container(
                            width: AppDimensions.accueilMoodFace,
                            height: AppDimensions.accueilMoodFace,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: mood
                                  .colorFor(Theme.of(context).brightness)
                                  .withValues(alpha: _mood == mood ? 1 : .18),
                            ),
                            child: Icon(
                              mood.icon,
                              size: AppDimensions.meditationIcon,
                              color: _mood == mood
                                  ? AppColors.onTint(dark)
                                  : mood.colorFor(Theme.of(context).brightness),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacing8),
                        Text(
                          mood.label,
                          style: AppTextStyles.labelSmall(
                            color: _mood == mood
                                ? context.textPrimary
                                : context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppDimensions.spacing12),
      Text(
        'Choisis une humeur ou passe cette étape.',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium(color: context.textSecondary),
      ),
      if (_mood == MoodType.verySad)
        TextButton(
          onPressed: () async {
            if (!await launchUrl(Uri(scheme: 'tel', path: '3114')) && mounted) {
              setState(
                () => _error = 'Appelle le 3114, gratuitement, à tout moment.',
              );
            }
          },
          child: Text(
            'Besoin d’aide maintenant ? 3114',
            style: AppTextStyles.bodyMedium(color: AppColors.helpInk(dark)),
          ),
        ),
    ],
  );

  Widget _look(bool dark) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Le décor',
        style: AppTextStyles.titleSmall(color: context.textPrimary),
      ),
      const SizedBox(height: AppDimensions.spacing8),
      Row(
        children: [
          for (final (index, decor) in const [
            MascotDecor.arches,
            MascotDecor.hills,
            MascotDecor.waves,
          ].indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing4),
                child: Semantics(
                  selected: _decor == decor,
                  child: InkWell(
                    onTap: _busy ? null : () => setState(() => _decor = decor),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: dark ? AppColors.cardDark : AppColors.cardLight,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radius14,
                        ),
                        border: Border.all(
                          width: AppDimensions.borderWidthMedium,
                          color: _decor == decor
                              ? (dark
                                    ? AppColors.primaryDark
                                    : AppColors.primary)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: AppDimensions.arrivalDecorHeight,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: AccueilScenePainter(
                                decor: decor,
                                dark: dark,
                                thumbnail: true,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(
                              AppDimensions.spacing8,
                            ),
                            child: Text(
                              const ['Arches', 'Collines', 'Vagues'][index],
                              style: AppTextStyles.labelSmall(
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppDimensions.spacing16),
      Text(
        'Ses couleurs',
        style: AppTextStyles.titleSmall(color: context.textPrimary),
      ),
      const SizedBox(height: AppDimensions.spacing12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final theme in const [
            MascotThemes.nature,
            MascotThemes.cosmic,
            MascotThemes.zen,
            MascotThemes.sakura,
          ])
            Expanded(
              child: Semantics(
                selected: _draft.themeId == theme.id,
                child: InkWell(
                  onTap: _busy
                      ? null
                      : () => setState(
                          () => _draft = _draft.copyWith(
                            themeId: theme.id,
                            appearance: MascotAppearance.defaults,
                          ),
                        ),
                  child: Column(
                    children: [
                      Container(
                        width: AppDimensions.arrivalPalette,
                        height: AppDimensions.arrivalPalette,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: AppDimensions.borderWidthMedium,
                            color: _draft.themeId == theme.id
                                ? (dark
                                      ? AppColors.primaryDark
                                      : AppColors.primary)
                                : Colors.transparent,
                          ),
                        ),
                        child: ClipOval(
                          child: Row(
                            children: [
                              for (final color in theme.paletteColors)
                                Expanded(
                                  child: ColoredBox(
                                    color: color,
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing8),
                      Text(
                        theme.name,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelSmall(
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}
