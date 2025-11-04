import 'package:flutter/material.dart';
import '../../../../routes/app_routes.dart';

class ChatbotPage extends StatelessWidget {
  const ChatbotPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbot'),
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
          'Chatbot',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
