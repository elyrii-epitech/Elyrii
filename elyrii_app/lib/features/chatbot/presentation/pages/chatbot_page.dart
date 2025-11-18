import 'package:flutter/material.dart';
import '../../../../routes/app_routes.dart';

class ChatbotPage extends StatelessWidget {
  const ChatbotPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF171719) : const Color(0xFFE8E8EB),
      body: const Center(
        child: Text(
          'Chatbot',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
