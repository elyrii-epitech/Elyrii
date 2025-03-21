import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://localhost:5000';

Future<List<String>> fetchJournalEntries() async {
  final url = Uri.parse('$baseUrl/journal');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return List<String>.from(data['journal']);
  } else {
    throw Exception('Erreur lors de la récupération du journal');
  }
}

Future<bool> addJournalEntry(String content) async {
  final url = Uri.parse('$baseUrl/journal');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'content': content}),
  );
  return response.statusCode == 201; 
}
