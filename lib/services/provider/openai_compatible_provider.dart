import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_provider.dart';

/// Generic OpenAI-compatible provider (covers most OpenAI-like APIs)
class OpenAICompatibleProvider implements AIProvider {
  @override
  final String name;
  @override
  final String baseUrl;
  @override
  final String apiKey;
  @override
  String model;

  OpenAICompatibleProvider({
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  @override
  Future<bool> testConnection() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': 'Hi'}
              ],
              'max_tokens': 10,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> sendMessage(String message, {bool isAgentMode = false}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': message}
          ],
          'max_tokens': 2048,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? '';
      }
      return 'Error: ${response.statusCode}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  @override
  Future<Stream<String>> streamMessage(String message,
      {bool isAgentMode = false}) async {
    return Stream.value('Streaming not implemented for this provider');
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/models'),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['data'] as List)
            .map<String>((m) => m['id'].toString())
            .toList();
        return models;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  bool supportsVision() => false;

  @override
  bool supportsTools() => false;

  @override
  bool supportsStructuredOutput() => false;

  @override
  Future<Map<String, dynamic>> validateConfiguration() async {
    return {
      'valid': await testConnection(),
      'provider': name,
      'model': model,
    };
  }
}
