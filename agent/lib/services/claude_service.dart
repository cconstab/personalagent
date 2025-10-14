import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

/// Service for interacting with Claude API (for sanitized queries only)
class ClaudeService {
  final Logger _logger = Logger('ClaudeService');
  final String apiKey;
  final String model;
  final http.Client _httpClient;

  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';

  ClaudeService({
    required this.apiKey,
    this.model = 'claude-3-5-sonnet-20241022',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Query Claude with sanitized input (no personal information)
  Future<ClaudeResponse> query({
    required String sanitizedQuery,
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async {
    try {
      _logger.info('Querying Claude with sanitized input');
      _logger.fine('Sanitized query: $sanitizedQuery');

      final response = await _httpClient.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': _apiVersion,
        },
        body: json.encode({
          'model': model,
          'max_tokens': maxTokens,
          'temperature': temperature,
          'messages': [
            {
              'role': 'user',
              'content': sanitizedQuery,
            }
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Claude API error: ${response.statusCode} - ${response.body}');
      }

      final jsonData = json.decode(response.body);
      final content = jsonData['content'][0]['text'] as String;

      return ClaudeResponse(
        content: content,
        stopReason: jsonData['stop_reason'] ?? '',
        usage: ClaudeUsage(
          inputTokens: jsonData['usage']['input_tokens'] ?? 0,
          outputTokens: jsonData['usage']['output_tokens'] ?? 0,
        ),
      );
    } catch (e, stackTrace) {
      _logger.severe('Failed to query Claude', e, stackTrace);
      rethrow;
    }
  }

  /// Verify API key is valid
  Future<bool> verifyApiKey() async {
    try {
      final response = await query(
        sanitizedQuery: 'Respond with "OK" if you can read this.',
        maxTokens: 10,
      );
      return response.content.isNotEmpty;
    } catch (e) {
      _logger.warning('Claude API key verification failed');
      return false;
    }
  }

  void dispose() {
    _httpClient.close();
  }
}

class ClaudeResponse {
  final String content;
  final String stopReason;
  final ClaudeUsage usage;

  ClaudeResponse({
    required this.content,
    required this.stopReason,
    required this.usage,
  });
}

class ClaudeUsage {
  final int inputTokens;
  final int outputTokens;

  ClaudeUsage({
    required this.inputTokens,
    required this.outputTokens,
  });

  int get totalTokens => inputTokens + outputTokens;
}
