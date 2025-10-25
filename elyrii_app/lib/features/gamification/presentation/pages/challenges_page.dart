import 'package:flutter/material.dart';
import '../../../../routes/app_routes.dart';

class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
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
          'Challenges',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
