import 'package:flutter/material.dart';
import '../../../../routes/app_routes.dart';

class MeditationPage extends StatelessWidget {
  const MeditationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meditation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.settings);
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Meditation',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
