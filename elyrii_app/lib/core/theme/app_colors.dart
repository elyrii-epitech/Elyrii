import 'package:flutter/material.dart';

class TempPage extends StatelessWidget {
  const TempPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Page Temporaire',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
