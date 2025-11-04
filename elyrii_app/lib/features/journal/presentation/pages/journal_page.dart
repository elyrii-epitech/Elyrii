import 'package:flutter/material.dart';
import '../../../../routes/app_routes.dart';

class JournalPage extends StatelessWidget {
  const JournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
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
          'Journal',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
