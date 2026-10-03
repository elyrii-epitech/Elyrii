import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../controllers/meditation_controller.dart';

class MeditationDurationSheet extends StatefulWidget {
  const MeditationDurationSheet({super.key, required this.initialMinutes});
  final int initialMinutes;
  @override
  State<MeditationDurationSheet> createState() =>
      _MeditationDurationSheetState();
}

class _MeditationDurationSheetState extends State<MeditationDurationSheet> {
  final _form = GlobalKey<FormState>();
  late final _minutes = TextEditingController(text: '${widget.initialMinutes}');
  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ta durée',
                        style: AppTextStyles.titleLarge(color: color),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choisis entre 1 et 180 minutes, selon le temps que tu veux prendre.',
                  style: AppTextStyles.bodyMedium(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('meditation-custom-minutes'),
                  controller: _minutes,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: const InputDecoration(labelText: 'Minutes'),
                  validator: (value) {
                    final n = int.tryParse(value ?? '');
                    if (n == null ||
                        n < MeditationController.minDurationMinutes ||
                        n > MeditationController.maxDurationMinutes) {
                      return 'Entre un nombre de 1 à 180.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _choose(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: LiquidGlassButton(
                    label: 'Choisir cette durée',
                    onPressed: _choose,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _choose() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, int.parse(_minutes.text));
    }
  }
}
