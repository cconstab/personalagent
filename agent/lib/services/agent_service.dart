import 'package:logging/logging.dart';
import '../models/message.dart';
import 'at_platform_service.dart';
import 'ollama_service.dart';
import 'claude_service.dart';

/// Main agent orchestration service
class AgentService {
  final Logger _logger = Logger('AgentService');
  final AtPlatformService atPlatform;
  final OllamaService ollama;
  final ClaudeService? claude;
  final double privacyThreshold;

  AgentService({
    required this.atPlatform,
    required this.ollama,
    this.claude,
    this.privacyThreshold = 0.7,
  });

  /// Initialize all services
  Future<void> initialize() async {
    _logger.info('Initializing agent services');

    // Initialize atPlatform
    await atPlatform.initialize();

    // Check Ollama availability
    final ollamaAvailable = await ollama.isAvailable();
    if (!ollamaAvailable) {
      throw Exception('Ollama is not available. Please start Ollama service.');
    }

    // Check Claude availability (optional)
    if (claude != null) {
      final claudeAvailable = await claude!.verifyApiKey();
      if (claudeAvailable) {
        _logger.info('Claude API is available');
      } else {
        _logger.warning('Claude API key is invalid or service unavailable');
      }
    }

    _logger.info('Agent services initialized successfully');
  }

  /// Start listening for incoming queries
  Future<void> startListening() async {
    _logger.info('Starting to listen for queries');
    await atPlatform.subscribeToMessages(_handleIncomingQuery);
    _logger.info('Now listening for queries');
  }

  /// Handle incoming query from user
  Future<void> _handleIncomingQuery(QueryMessage query) async {
    try {
      _logger.info('⚡ Handling query from ${query.userId}');

      // Process the query
      final response = await processQuery(query);

      // Send response back to user
      await atPlatform.sendResponse(query.userId, response);

      _logger.info('✅ Sent response to ${query.userId}');
    } catch (e, stackTrace) {
      _logger.severe('Failed to handle query', e, stackTrace);

      // Send error response
      try {
        final errorResponse = ResponseMessage(
          id: query.id,
          content: 'Sorry, I encountered an error processing your request.',
          source: ResponseSource.ollama,
          timestamp: DateTime.now(),
          wasPrivacyFiltered: false,
        );
        await atPlatform.sendResponse(query.userId, errorResponse);
      } catch (sendError) {
        _logger.severe('Failed to send error response', sendError);
      }
    }
  }

  /// Process a user query with privacy-preserving logic
  Future<ResponseMessage> processQuery(QueryMessage query) async {
    try {
      _logger.info('Processing query: ${query.id}');

      // Check if user requested Ollama-only mode
      if (query.useOllamaOnly) {
        _logger.info(
            '🔒 User requested Ollama-only mode - 100% private processing');
        final context = await _retrieveContext(query);
        return await _processWithOllama(query, context);
      }

      // Step 1: Retrieve relevant context from atPlatform
      final context = await _retrieveContext(query);

      // Step 2: Analyze if we can answer locally with Ollama
      final analysis = await ollama.analyzeQuery(
        query: query.content,
        userContext: context,
      );

      _logger.info(
        'Analysis: canAnswerLocally=${analysis.canAnswerLocally}, '
        'confidence=${analysis.confidence.toStringAsFixed(2)}',
      );

      // Step 3: Decide processing strategy
      if (analysis.canAnswerLocally &&
          analysis.confidence >= privacyThreshold) {
        // Process locally with Ollama (95% of queries)
        return await _processWithOllama(query, context);
      } else {
        // Need external knowledge (5% of queries)
        return await _processWithHybrid(query, context, analysis);
      }
    } catch (e, stackTrace) {
      _logger.severe('Failed to process query', e, stackTrace);
      return ResponseMessage(
        id: query.id,
        content:
            'An error occurred while processing your query. Please try again.',
        source: ResponseSource.ollama,
        confidenceScore: 0.0,
      );
    }
  }

  /// Retrieve relevant context for the query
  Future<String> _retrieveContext(QueryMessage query) async {
    final contextKeys = query.contextKeys ?? await atPlatform.listContextKeys();
    final contextParts = <String>[];

    for (final key in contextKeys) {
      final data = await atPlatform.getContext(key);
      if (data != null) {
        contextParts.add('${data.key}: ${data.value}');
      }
    }

    return contextParts.join('\n\n');
  }

  /// Process query using only Ollama (fully private)
  Future<ResponseMessage> _processWithOllama(
    QueryMessage query,
    String context,
  ) async {
    _logger.info('Processing with Ollama only (fully private)');

    // Build conversation history string
    String conversationContext = '';
    if (query.conversationHistory != null &&
        query.conversationHistory!.isNotEmpty) {
      _logger.info(
          'Including ${query.conversationHistory!.length} previous messages for context');
      for (final msg in query.conversationHistory!) {
        final role = msg['role'] == 'user' ? 'User' : 'You';
        conversationContext += '$role: ${msg['content']}\n';
      }
    }

    final prompt = '''
You are a helpful personal AI assistant having a natural conversation with the user.

${context.isNotEmpty ? 'User\'s Personal Information:\n$context\n' : ''}${conversationContext.isNotEmpty ? 'Previous messages in this conversation:\n$conversationContext\n' : ''}User: ${query.content}

Respond naturally and conversationally. If the user is referring to something mentioned earlier in the chat, just understand and respond to it naturally without explicitly mentioning "our previous conversation" or "as we discussed". Just chat like a helpful assistant would.
''';

    final response = await ollama.generate(prompt: prompt);

    return ResponseMessage(
      id: query.id,
      content: response.response,
      source: ResponseSource.ollama,
      wasPrivacyFiltered: false,
      confidenceScore: 1.0,
    );
  }

  /// Process query using hybrid approach (Ollama + Claude)
  Future<ResponseMessage> _processWithHybrid(
    QueryMessage query,
    String context,
    AnalysisResult analysis,
  ) async {
    if (claude == null) {
      _logger.warning('Claude not available, falling back to Ollama only');
      return await _processWithOllama(query, context);
    }

    _logger.info('Processing with hybrid approach (Ollama + Claude)');

    // Build conversation history string
    String conversationContext = '';
    if (query.conversationHistory != null &&
        query.conversationHistory!.isNotEmpty) {
      _logger.info(
          'Including ${query.conversationHistory!.length} previous messages for context');
      for (final msg in query.conversationHistory!) {
        final role = msg['role'] == 'user' ? 'User' : 'You';
        conversationContext += '$role: ${msg['content']}\n';
      }
    }

    // Step 1: Sanitize the query (remove personal information)
    final sanitizedQuery = await ollama.sanitizeQuery(query.content, context);
    _logger.info('Sanitized query: $sanitizedQuery');

    // Step 2: Get general knowledge from Claude (include conversation context for better understanding)
    final claudePrompt = conversationContext.isNotEmpty
        ? 'Previous conversation:\n$conversationContext\nUser: $sanitizedQuery'
        : sanitizedQuery;

    final claudeResponse = await claude!.query(
      sanitizedQuery: claudePrompt,
    );
    _logger.info(
        'Received response from Claude (${claudeResponse.usage.totalTokens} tokens)');

    // Step 3: Combine Claude's knowledge with user context using Ollama
    final combinationPrompt = '''
You are a helpful personal AI assistant having a natural conversation with the user.

${context.isNotEmpty ? 'User\'s Personal Information:\n$context\n' : ''}${conversationContext.isNotEmpty ? 'Previous messages in this conversation:\n$conversationContext\n' : ''}General knowledge to help answer:
${claudeResponse.content}

User: ${query.content}

Respond naturally using the general knowledge above combined with what you know about the user. If they're referring to something mentioned earlier, just understand and respond naturally without saying things like "as we discussed" or "in our previous conversation". Just chat naturally like a helpful assistant.
''';

    final finalResponse = await ollama.generate(prompt: combinationPrompt);

    return ResponseMessage(
      id: query.id,
      content: finalResponse.response,
      source: ResponseSource.hybrid,
      wasPrivacyFiltered: true,
      confidenceScore: analysis.confidence,
    );
  }

  /// Store new context data
  Future<void> storeContext(ContextData context) async {
    await atPlatform.storeContext(context);
  }

  /// List all stored context
  Future<List<String>> listContext() async {
    return await atPlatform.listContextKeys();
  }

  /// Delete context
  Future<bool> deleteContext(String key) async {
    return await atPlatform.deleteContext(key);
  }

  /// Cleanup resources
  Future<void> dispose() async {
    await atPlatform.dispose();
    ollama.dispose();
    claude?.dispose();
  }
}
