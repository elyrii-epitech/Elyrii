import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/meditation_exercise.dart';
import '../../domain/models/meditation_exercises.dart';

class MeditationSourcesSheet extends StatelessWidget {
  const MeditationSourcesSheet({super.key, this.exercise});
  final MeditationExercise? exercise;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final references =
        exercise?.sources ??
        [
          MeditationExercises.nhsBreathing,
          MeditationExercises.mindfulBreathing,
          MeditationExercises.bodyScan,
          MeditationExercises.lovingKindness,
          MeditationExercises.selfCompassion,
          MeditationExercises.nccih,
        ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Guide et références',
                    style: AppTextStyles.titleLarge(color: text),
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (exercise != null) ...[
              Text(
                exercise!.title,
                style: AppTextStyles.titleMedium(color: text),
              ),
              const SizedBox(height: 8),
              Text(
                exercise!.practiceTip,
                style: AppTextStyles.bodyMedium(color: secondary),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Les consignes écrites et les rythmes proposés sont des adaptations d’Elyrii inspirées de ces ressources.',
              style: AppTextStyles.bodyMedium(color: secondary),
            ),
            const SizedBox(height: 16),
            for (final source in references)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  source.title,
                  style: AppTextStyles.bodyMedium(color: text),
                ),
                subtitle: Text(
                  Uri.parse(source.url).host,
                  style: AppTextStyles.bodySmall(color: secondary),
                ),
                trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                onTap: () => _open(context, source),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, MeditationSource source) async {
    try {
      final opened = await launchUrl(
        Uri.parse(source.url),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impossible d’ouvrir cette référence pour le moment.'),
      ),
    );
  }
}
