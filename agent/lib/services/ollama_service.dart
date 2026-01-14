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

  /// Check if Ollama is running and the model is available
  Future<bool> healthCheck() async {
    try {
      // Check if Ollama server is running
      final response = await _httpClient.get(Uri.parse('$host/api/tags'));
      
      if (response.statusCode != 200) {
        _logger.warning('Ollama server not accessible at $host');
        return false;
      }

      // Check if the model exists
      final data = json.decode(response.body);
      final models = data['models'] as List<dynamic>?;
      
      if (models == null) {
        _logger.warning('Unable to get model list from Ollama');
        return false;
      }

      final modelExists = models.any((m) => m['name']?.toString().startsWith(model) ?? false);
      
      if (!modelExists) {
        _logger.warning('Model "$model" not found in Ollama. Available models: ${models.map((m) => m['name']).join(', ')}');
        _logger.warning('Run: ollama pull $model');
        return false;
      }

      _logger.info('✅ Ollama health check passed - model "$model" is available');
      return true;
    } catch (e) {
      _logger.warning('Ollama health check failed: $e');
      return false;
    }
  }

  /// Generate a response from Ollama (non-streaming)
  Future<OllamaResponse> generate({
    required String prompt,
    List<int>? context,
    double temperature = 0.7,
  }) async {
    try {
      _logger.info('Generating response with Ollama ($model)');

      final body = {
        'model': model,
        'prompt': prompt,
        'stream': false,
        'options': {
          'temperature': temperature,
        },
      };

      // Include context if provided (for conversation continuity)
      if (context != null && context.isNotEmpty) {
        body['context'] = context;
      }

      final response = await _httpClient.post(
        Uri.parse('$host/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
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

  /// Generate a streaming response from Ollama
  /// Yields partial responses as they arrive from the LLM
  Stream<OllamaStreamChunk> generateStream({
    required String prompt,
    List<int>? context,
    double temperature = 0.7,
  }) async* {
    try {
      _logger.info('Generating streaming response with Ollama ($model)');

      final body = {
        'model': model,
        'prompt': prompt,
        'stream': true, // Enable streaming
        'options': {
          'temperature': temperature,
        },
      };

      // Include context if provided (for conversation continuity)
      if (context != null && context.isNotEmpty) {
        body['context'] = context;
      }

      final request = http.Request('POST', Uri.parse('$host/api/generate'));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode(body);

      final streamedResponse = await _httpClient.send(request);

      if (streamedResponse.statusCode != 200) {
        String errorMsg = 'Ollama API error: ${streamedResponse.statusCode}';
        
        // Provide helpful error messages
        if (streamedResponse.statusCode == 404) {
          errorMsg += '\n   Model "$model" not found. Please pull it first with: ollama pull $model';
          errorMsg += '\n   Or check if Ollama is running at: $host';
        } else if (streamedResponse.statusCode >= 500) {
          errorMsg += '\n   Ollama server error. Check if Ollama is running properly.';
        }
        
        // Try to read error body for more details
        try {
          final errorBody = await streamedResponse.stream.bytesToString();
          if (errorBody.isNotEmpty) {
            errorMsg += '\n   Details: $errorBody';
          }
        } catch (_) {
          // Ignore if we can't read the error body
        }
        
        throw Exception(errorMsg);
      }

      // Ollama streaming returns newline-delimited JSON objects
      String buffer = '';
      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // Process complete JSON lines
        while (buffer.contains('\n')) {
          final newlineIndex = buffer.indexOf('\n');
          final line = buffer.substring(0, newlineIndex).trim();
          buffer = buffer.substring(newlineIndex + 1);

          if (line.isEmpty) continue;

          try {
            final jsonData = json.decode(line);
            yield OllamaStreamChunk(
              response: jsonData['response'] ?? '',
              done: jsonData['done'] ?? false,
              context: jsonData['done'] == true
                  ? (jsonData['context'] as List<dynamic>?)?.cast<int>() ?? []
                  : null,
              totalDuration: jsonData['total_duration'],
              loadDuration: jsonData['load_duration'],
              promptEvalCount: jsonData['prompt_eval_count'],
              evalCount: jsonData['eval_count'],
            );
          } catch (e) {
            _logger.warning('Failed to parse streaming chunk: $line', e);
          }
        }
      }
    } catch (e, stackTrace) {
      _logger.severe(
          'Failed to generate streaming Ollama response', e, stackTrace);
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
        _logger.warning('⚠️ No JSON found in Ollama analysis response: ${response.response}');
        throw Exception('Could not parse analysis response');
      }

      final jsonText = jsonMatch.group(0)!;
      _logger.info('📊 Ollama analysis JSON: $jsonText');
      
      final analysisData = json.decode(jsonText);
      
      final result = AnalysisResult(
        canAnswerLocally: analysisData['canAnswerLocally'] ?? false,
        confidence: (analysisData['confidence'] ?? 0.5).toDouble(),
        reasoning: analysisData['reasoningRequired'] ?? '',
        externalKnowledgeNeeded: analysisData['externalKnowledgeNeeded'],
      );
      
      _logger.info('📊 Analysis result: canAnswer=${result.canAnswerLocally}, confidence=${result.confidence.toStringAsFixed(2)}, reason=${result.reasoning}');
      
      return result;
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

/// Streaming chunk from Ollama
class OllamaStreamChunk {
  final String response; // Partial response text
  final bool done; // True on final chunk
  final List<int>? context; // Only available on final chunk
  final int? totalDuration;
  final int? loadDuration;
  final int? promptEvalCount;
  final int? evalCount;

  OllamaStreamChunk({
    required this.response,
    required this.done,
    this.context,
    this.totalDuration,
    this.loadDuration,
    this.promptEvalCount,
    this.evalCount,
  });
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
