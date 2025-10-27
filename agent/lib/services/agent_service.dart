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
  final String? agentName;

  // Note: Agents are now stateless - conversation history comes from the app
  // This enables perfect load balancing across multiple agent instances

  AgentService({
    required this.atPlatform,
    required this.ollama,
    this.claude,
    this.privacyThreshold = 0.7,
    this.agentName,
  });

  /// Initialize all services
  Future<void> initialize() async {
    _logger.fine('Initializing agent services');

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
        _logger.fine('Claude API is available');
      } else {
        _logger.warning('Claude API key is invalid or service unavailable');
      }
    }

    _logger.fine('Agent services initialized successfully');
  }

  /// Start listening for incoming queries
  Future<void> startListening() async {
    _logger.fine('Starting to listen for queries');

    // Start the at_stream response channel listener
    _logger.fine('Starting at_stream response channel listener');
    atPlatform.startResponseStreamListener();

    // Start listening for query notifications
    await atPlatform.subscribeToMessages(_handleIncomingQuery);
    _logger.fine('Now listening for queries');
  }

  /// Handle incoming query from user
  Future<void> _handleIncomingQuery(QueryMessage query) async {
    try {
      _logger.shout('📨 Query from ${query.userId}');

      // Warn if conversationId is missing - this should NEVER happen
      if (query.conversationId == null || query.conversationId!.isEmpty) {
        _logger.warning(
          '⚠️ Query ${query.id} has NO conversationId! Response will be dropped by app!',
        );
      } else {
        _logger.fine(
          '🔗 Query ${query.id} → conversation ${query.conversationId}',
        );
      }

      // Try to acquire mutex for this query (only one agent responds)
      final acquired = await _tryAcquireMutexWrapper(query.id);

      if (!acquired) {
        _logger.fine(
          '🤷‍♂️ Another agent acquired the mutex for query ${query.id} - skipping',
        );
        return; // Another agent won the race
      }

      _logger.fine(
        '😎 Acquired mutex for query ${query.id} - this agent will respond',
      );

      // Process the query
      final response = await processQuery(query);

      // Connect to the query-specific response stream and send response
      await atPlatform.sendStreamResponseToQuery(
        query.userId,
        query.id,
        response,
      );

      _logger.shout('✅ Replied to ${query.userId}');
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
          agentName: agentName,
          model: ollama.model,
          conversationId: query.conversationId, // Echo back conversation ID
        );
        await atPlatform.sendStreamResponseToQuery(
          query.userId,
          query.id,
          errorResponse,
        );
      } catch (sendError) {
        _logger.severe('Failed to send error response', sendError);
      }
    }
  }

  /// Process a user query with privacy-preserving logic
  Future<ResponseMessage> processQuery(QueryMessage query) async {
    try {
      _logger.fine('Processing query: ${query.id}');

      // Check if user requested Ollama-only mode
      if (query.useOllamaOnly) {
        _logger.fine(
          '🔒 User requested Ollama-only mode - 100% private processing',
        );
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

      _logger.fine(
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
        agentName: agentName,
        model: ollama.model,
        conversationId: query.conversationId, // Echo back conversation ID
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
    _logger.fine('Processing with Ollama only (fully private)');

    // Agents are now stateless - conversation history comes from the app
    final hasHistory =
        query.conversationHistory != null &&
        query.conversationHistory!.isNotEmpty;

    if (hasHistory) {
      _logger.fine(
        '📝 Using conversation history from app (${query.conversationHistory!.length} messages)',
      );
      _logger.fine('🔍 History contents:');
      for (var i = 0; i < query.conversationHistory!.length; i++) {
        final msg = query.conversationHistory![i];
        final role = msg['role'] ?? 'unknown';
        final content = msg['content'] ?? '';
        final preview = content.length > 50
            ? '${content.substring(0, 50)}...'
            : content;
        _logger.fine('   [$i] $role: $preview');
      }
    } else {
      _logger.fine('🆕 Starting new conversation for ${query.userId}');
    }

    // Build system message with user's personal context (only on first message)
    String systemContext = '';
    if (!hasHistory && context.isNotEmpty) {
      systemContext =
          '''You are a helpful personal AI assistant having a natural conversation with the user.

User's Personal Information:
$context

Respond naturally and conversationally.
''';
    }

    // Build the full conversation prompt from history
    final StringBuffer promptBuffer = StringBuffer();

    if (!hasHistory) {
      promptBuffer.write('$systemContext\n');
    } else {
      // Include conversation history
      for (var msg in query.conversationHistory!) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        promptBuffer.write(
          '${role == 'user' ? 'User' : 'Assistant'}: $content\n',
        );
      }
    }

    _logger.info('📤 Final prompt being sent to Ollama:');
    final promptPreview = promptBuffer.toString().length > 200
        ? '${promptBuffer.toString().substring(0, 200)}...'
        : promptBuffer.toString();
    _logger.info('   $promptPreview');

    promptBuffer.write('User: ${query.content}');

    _logger.info(
      '🤖 Sending prompt to Ollama (${hasHistory ? "with history" : "new conversation"}) with streaming',
    );

    // Stream the response and send incremental updates
    // Use batching to reduce atPlatform notification overhead
    final StringBuffer fullResponse = StringBuffer();
    int chunkIndex = 0;
    DateTime lastSendTime = DateTime.now();
    const sendIntervalMs = 500; // Send updates every 500ms max
    const minCharsBeforeSend = 50; // Or every 50 characters
    int charsSinceLastSend = 0;

    await for (final chunk in ollama.generateStream(
      prompt: promptBuffer.toString(),
      context:
          null, // Don't use stored context - regenerate from history each time
    )) {
      if (chunk.response.isNotEmpty) {
        fullResponse.write(chunk.response);
        charsSinceLastSend += chunk.response.length;

        final timeSinceLastSend = DateTime.now()
            .difference(lastSendTime)
            .inMilliseconds;
        final shouldSend =
            charsSinceLastSend >= minCharsBeforeSend ||
            timeSinceLastSend >= sendIntervalMs;

        // Only send partial chunks during streaming, not the final one
        // The final complete message will be sent after the loop
        if (shouldSend && !chunk.done) {
          // Send partial response update
          final partialMessage = ResponseMessage(
            id: query.id,
            content: fullResponse.toString(),
            source: ResponseSource.ollama,
            wasPrivacyFiltered: false,
            confidenceScore: 1.0,
            agentName: agentName,
            model: ollama.model,
            conversationId: query.conversationId, // Echo back conversation ID
            isPartial: true,
            chunkIndex: chunkIndex++,
          );

          _logger.info(
            '📤 Sending PARTIAL chunk #$chunkIndex (${fullResponse.length} chars)',
          );

          // Send chunk and await to ensure it completes
          // This maintains channel caching and prevents errors
          try {
            await atPlatform.sendStreamResponseToQuery(
              query.userId,
              query.id,
              partialMessage,
            );
          } catch (e) {
            _logger.warning('Failed to send streaming chunk: $e');
            // Continue processing even if one chunk fails
          }

          lastSendTime = DateTime.now();
          charsSinceLastSend = 0;
        }

        if (chunk.done) {
          _logger.info(
            '✅ Streaming complete. Sent ${chunkIndex} batched updates. Final message will be sent separately.',
          );
        }
      }
    }

    // Return final complete message
    return ResponseMessage(
      id: query.id,
      content: fullResponse.toString(),
      source: ResponseSource.ollama,
      wasPrivacyFiltered: false,
      confidenceScore: 1.0,
      agentName: agentName,
      model: ollama.model,
      conversationId: query.conversationId, // Echo back conversation ID
      isPartial: false,
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

    // Agents are now stateless - use conversation history from app
    final hasHistory =
        query.conversationHistory != null &&
        query.conversationHistory!.isNotEmpty;

    // Build brief conversation history for Claude (last 2-3 exchanges only to save tokens)
    String conversationContext = '';
    if (hasHistory) {
      final recentHistory = query.conversationHistory!.length > 6
          ? query.conversationHistory!.sublist(
              query.conversationHistory!.length - 6,
            )
          : query.conversationHistory!;

      _logger.info(
        'Including ${recentHistory.length} recent messages for Claude context',
      );
      for (final msg in recentHistory) {
        final role = msg['role'] == 'user' ? 'User' : 'Assistant';
        conversationContext += '$role: ${msg['content']}\n';
      }
    }

    // Step 1: Sanitize the query (remove personal information)
    final sanitizedQuery = await ollama.sanitizeQuery(query.content, context);
    _logger.info('Sanitized query: $sanitizedQuery');

    // Step 2: Get general knowledge from Claude with streaming (include recent conversation context)
    final claudePrompt = conversationContext.isNotEmpty
        ? 'Recent conversation:\n$conversationContext\nUser: $sanitizedQuery'
        : sanitizedQuery;

    _logger.info('🌐 Streaming response from Claude...');
    final StringBuffer claudeFullResponse = StringBuffer();
    await for (final chunk in claude!.queryStream(
      sanitizedQuery: claudePrompt,
    )) {
      claudeFullResponse.write(chunk.content);
      if (chunk.done) {
        _logger.info('✅ Claude streaming complete');
      }
    }

    final claudeResponseContent = claudeFullResponse.toString();
    _logger.info('Received complete response from Claude');

    // Step 3: Combine Claude's knowledge with user context using Ollama with streaming
    // Build full prompt including conversation history
    final StringBuffer promptBuffer = StringBuffer();

    if (!hasHistory) {
      promptBuffer.write('''You are a helpful personal AI assistant.

User's Personal Information:
$context

General knowledge to help answer:
$claudeResponseContent

''');
    } else {
      // Include conversation history
      for (var msg in query.conversationHistory!) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        promptBuffer.write(
          '${role == 'user' ? 'User' : 'Assistant'}: $content\n',
        );
      }
      promptBuffer.write(
        '\nGeneral knowledge to help answer:\n$claudeResponseContent\n\n',
      );
    }

    promptBuffer.write('User: ${query.content}');

    // Stream Ollama's final synthesis with batching
    _logger.info('🤖 Synthesizing final response with Ollama streaming...');
    final StringBuffer fullResponse = StringBuffer();
    int chunkIndex = 0;
    DateTime lastSendTime = DateTime.now();
    const sendIntervalMs = 500; // Send updates every 500ms max
    const minCharsBeforeSend = 50; // Or every 50 characters
    int charsSinceLastSend = 0;

    await for (final chunk in ollama.generateStream(
      prompt: promptBuffer.toString(),
      context: null, // Don't use stored context - regenerate from history
    )) {
      if (chunk.response.isNotEmpty) {
        fullResponse.write(chunk.response);
        charsSinceLastSend += chunk.response.length;

        final timeSinceLastSend = DateTime.now()
            .difference(lastSendTime)
            .inMilliseconds;
        final shouldSend =
            charsSinceLastSend >= minCharsBeforeSend ||
            timeSinceLastSend >= sendIntervalMs;

        // Only send partial chunks during streaming, not the final one
        // The final complete message will be sent after the loop
        if (shouldSend && !chunk.done) {
          // Send partial response update
          final partialMessage = ResponseMessage(
            id: query.id,
            content: fullResponse.toString(),
            source: ResponseSource.hybrid,
            wasPrivacyFiltered: true,
            confidenceScore: analysis.confidence,
            agentName: agentName,
            model: '${ollama.model} + ${claude!.model}',
            conversationId: query.conversationId, // Echo back conversation ID
            isPartial: true,
            chunkIndex: chunkIndex++,
          );

          // Send chunk and await to ensure it completes
          // This maintains channel caching and prevents errors
          try {
            await atPlatform.sendStreamResponseToQuery(
              query.userId,
              query.id,
              partialMessage,
            );
          } catch (e) {
            _logger.warning('Failed to send streaming chunk: $e');
            // Continue processing even if one chunk fails
          }

          lastSendTime = DateTime.now();
          charsSinceLastSend = 0;
        }

        if (chunk.done) {
          _logger.info(
            '✅ Hybrid streaming complete. Sent ${chunkIndex} batched updates. Final message will be sent separately.',
          );
        }
      }
    }

    // Return final complete message
    return ResponseMessage(
      id: query.id,
      content: fullResponse.toString(),
      source: ResponseSource.hybrid,
      wasPrivacyFiltered: true,
      confidenceScore: analysis.confidence,
      agentName: agentName,
      model: '${ollama.model} + ${claude!.model}',
      conversationId: query.conversationId, // Echo back conversation ID
      isPartial: false,
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

  /// Wrapper to work around type inference issues
  Future<bool> _tryAcquireMutexWrapper(dynamic queryId) async {
    return await atPlatform.acquireQueryMutex(queryId, agentName!);
  }
}
