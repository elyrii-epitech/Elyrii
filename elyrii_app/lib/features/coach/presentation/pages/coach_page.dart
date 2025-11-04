import 'package:flutter/material.dart';
import 'package:elyrii_app/routes/app_routes.dart';

class CoachPage extends StatelessWidget {
  const CoachPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach'),
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
          'Coach',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
