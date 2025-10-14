import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

/// Service for interacting with local Ollama LLM
class OllamaService {
  final Logger _logger = Logger('OllamaService');
  final String host;
  final String model;
  final http.Client _httpClient;

  OllamaService({
    required this.host,
    required this.model,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Generate a response from Ollama
  Future<OllamaResponse> generate({
    required String prompt,
    List<Map<String, String>>? context,
    double temperature = 0.7,
  }) async {
    try {
      _logger.info('Generating response with Ollama ($model)');

      final response = await _httpClient.post(
        Uri.parse('$host/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': model,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': temperature,
          },
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Ollama API error: ${response.statusCode} - ${response.body}');
      }

      final jsonData = json.decode(response.body);
      return OllamaResponse(
        response: jsonData['response'] ?? '',
        context: (jsonData['context'] as List<dynamic>?)?.cast<int>() ?? [],
        totalDuration: jsonData['total_duration'] ?? 0,
        loadDuration: jsonData['load_duration'] ?? 0,
        promptEvalCount: jsonData['prompt_eval_count'] ?? 0,
        evalCount: jsonData['eval_count'] ?? 0,
      );
    } catch (e, stackTrace) {
      _logger.severe('Failed to generate Ollama response', e, stackTrace);
      rethrow;
    }
  }

  /// Analyze if the query needs external knowledge
  Future<AnalysisResult> analyzeQuery({
    required String query,
    required String userContext,
  }) async {
    final analysisPrompt = '''
Analyze this query and determine if it can be answered with the provided context alone, 
or if external knowledge is needed.

Query: $query

Available Context:
$userContext

Respond in JSON format:
{
  "canAnswerLocally": true/false,
  "confidence": 0.0-1.0,
  "reasoningRequired": "brief explanation",
  "externalKnowledgeNeeded": "what type of knowledge is needed, if any"
}
''';

    try {
      final response = await generate(
        prompt: analysisPrompt,
        temperature: 0.3, // Lower temperature for more deterministic analysis
      );

      // Parse JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response.response);
      if (jsonMatch == null) {
        throw Exception('Could not parse analysis response');
      }

      final analysisData = json.decode(jsonMatch.group(0)!);
      return AnalysisResult(
        canAnswerLocally: analysisData['canAnswerLocally'] ?? false,
        confidence: (analysisData['confidence'] ?? 0.5).toDouble(),
        reasoning: analysisData['reasoningRequired'] ?? '',
        externalKnowledgeNeeded: analysisData['externalKnowledgeNeeded'],
      );
    } catch (e, stackTrace) {
      _logger.warning(
          'Failed to analyze query, defaulting to local', e, stackTrace);
      // Default to local processing if analysis fails
      return AnalysisResult(
        canAnswerLocally: true,
        confidence: 0.5,
        reasoning: 'Analysis failed, defaulting to local processing',
      );
    }
  }

  /// Sanitize a query by removing personal information
  Future<String> sanitizeQuery(String query, String userContext) async {
    final sanitizePrompt = '''
Remove all personal information from this query while preserving the core question.
Replace specific names, dates, places, and personal details with generic placeholders.

Original Query: $query

Context (DO NOT include this in output): $userContext

Respond with ONLY the sanitized query, no explanation.
''';

    try {
      final response = await generate(
        prompt: sanitizePrompt,
        temperature: 0.2,
      );

      return response.response.trim();
    } catch (e, stackTrace) {
      _logger.severe('Failed to sanitize query', e, stackTrace);
      rethrow;
    }
  }

  /// Check if Ollama is available
  Future<bool> isAvailable() async {
    try {
      final response = await _httpClient.get(Uri.parse('$host/api/tags'));
      return response.statusCode == 200;
    } catch (e) {
      _logger.warning('Ollama is not available at $host');
      return false;
    }
  }

  void dispose() {
    _httpClient.close();
  }
}

class OllamaResponse {
  final String response;
  final List<int> context;
  final int totalDuration;
  final int loadDuration;
  final int promptEvalCount;
  final int evalCount;

  OllamaResponse({
    required this.response,
    required this.context,
    required this.totalDuration,
    required this.loadDuration,
    required this.promptEvalCount,
    required this.evalCount,
  });

  double get tokensPerSecond => evalCount / (totalDuration / 1000000000.0);
}

class AnalysisResult {
  final bool canAnswerLocally;
  final double confidence;
  final String reasoning;
  final String? externalKnowledgeNeeded;

  AnalysisResult({
    required this.canAnswerLocally,
    required this.confidence,
    required this.reasoning,
    this.externalKnowledgeNeeded,
  });
}
