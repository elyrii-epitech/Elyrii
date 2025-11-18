import 'package:flutter/material.dart';

class CoachPage extends StatelessWidget {
  const CoachPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF171719) : const Color(0xFFE8E8EB),
      body: const Center(
        child: Text(
          'Coach',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
