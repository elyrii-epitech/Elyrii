import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      body: const Center(
        child: Text(
          'Challenges',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
