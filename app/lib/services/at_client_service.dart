import 'dart:async';
import 'dart:convert';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_commons/at_commons.dart';
import 'package:at_stream/at_stream.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import '../models/message.dart';
import 'stream_transformers.dart';

/// Service for communicating with the agent via atPlatform
class AtClientService {
  static final AtClientService _instance = AtClientService._internal();
  factory AtClientService() => _instance;
  AtClientService._internal();

  final _logger = Logger('AtClientService');

  AtClientManager? _atClientManager;
  AtClient? _atClient;
  String? _currentAtSign;
  String? _agentAtSign;
  AtNotificationStreamChannel<String, String>? _responseStreamChannel;

  final _messageController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get messageStream => _messageController.stream;

  // Auto-reconnect state
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  // Query-specific stream subscriptions tracking
  final Map<String, StreamSubscription> _querySubscriptions = {};

  bool get isInitialized => _atClient != null;
  String? get currentAtSign => _currentAtSign;
  String? get agentAtSign => _agentAtSign;

  /// Initialize atClient for the current user
  Future<void> initialize(String atSign) async {
    try {
      // Get the AtClientManager instance (set by at_onboarding_flutter)
      _atClientManager = AtClientManager.getInstance();

      // The AtClient should now be initialized by at_onboarding_flutter
      final manager = _atClientManager;
      if (manager == null) {
        throw Exception('AtClientManager not initialized');
      }

      final currentAtSign = manager.atClient.getCurrentAtSign();

      // Check if SDK is using wrong @sign
      if (currentAtSign != null && currentAtSign != atSign) {
        throw Exception(
            'SDK initialized with wrong @sign: $currentAtSign (expected $atSign)');
      }

      if (currentAtSign != null) {
        _currentAtSign = atSign;
        _atClient = manager.atClient;
      } else {
        // This shouldn't happen after successful onboarding
        throw Exception(
            'AtClient not initialized. Onboarding may not have completed successfully.');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize AtClientService: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow; // Rethrow so caller knows initialization failed
    }
  }

  /// Set the agent's atSign
  void setAgentAtSign(String agentAtSign) {
    _agentAtSign = agentAtSign;
  }

  /// Send a query message to the agent with conversation context
  Future<void> sendMessage(
    ChatMessage message, {
    bool useOllamaOnly = false,
    List<ChatMessage>? conversationHistory,
    required String
        conversationId, // NOW REQUIRED - messages must belong to a conversation
  }) async {
    if (_atClient == null) {
      throw Exception('AtClient not initialized. Call initialize() first.');
    }

    if (_agentAtSign == null || _agentAtSign!.isEmpty) {
      throw Exception('Agent atSign not set. Call setAgentAtSign() first.');
    }

    try {
      // Create a unique response channel for THIS query only
      // This ensures we only get responses for this specific query
      final queryId = message.id;

      // Cancel any existing subscription for this query (shouldn't happen, but be safe)
      _querySubscriptions[queryId]?.cancel();

      debugPrint('📡 Setting up response stream listener for query $queryId');

      // Start listening for agent connections on this query-specific namespace
      final bindStream = AtNotificationStreamChannel.bind<String, String>(
        _atClient!,
        baseNamespace: 'personalagent',
        domainNamespace: 'response.$queryId', // Unique namespace per query
        sendTransformer: QuerySendTransformer(),
        recvTransformer: MessageReceiveTransformer(),
      );

      // Track the subscription so we can cancel it later
      _querySubscriptions[queryId] = bindStream.listen((responseChannel) {
        debugPrint('🔗 Agent connected to response stream for query $queryId');

        // Listen for agent's responses on this channel
        responseChannel.stream.listen(
          (String responseJson) {
            try {
              final responseData =
                  json.decode(responseJson) as Map<String, dynamic>;

              // Check for control messages (disconnect, etc.) and ignore them
              if (responseData.containsKey('control')) {
                final controlType = responseData['control'];
                debugPrint('📡 Received control message: $controlType');

                if (controlType == 'disconnect') {
                  debugPrint('🔌 Agent signaled disconnect for query $queryId');
                  // Clean up subscription
                  _querySubscriptions[queryId]?.cancel();
                  _querySubscriptions.remove(queryId);
                }
                return; // Don't process control messages as regular messages
              }

              final responseMessage = ChatMessage(
                id: responseData['id'] ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                content: responseData['content'] ?? '',
                isUser: false,
                timestamp: DateTime.parse(
                  responseData['timestamp'] ?? DateTime.now().toIso8601String(),
                ),
                source: _parseSource(responseData['source']),
                wasPrivacyFiltered: responseData['wasPrivacyFiltered'] ?? false,
                agentName: responseData['agentName'] as String?,
                model: responseData['model'] as String?,
                isPartial: responseData['isPartial'] ?? false,
                chunkIndex: responseData['chunkIndex'] as int?,
                conversationId: responseData['conversationId'] as String?,
              );

              // Log when we receive the final response
              if (responseMessage.isPartial == false) {
                _logger.info(
                    '✅ Received complete response from ${responseMessage.agentName ?? "agent"}');

                // Clean up subscription when final message received
                _querySubscriptions[queryId]?.cancel();
                _querySubscriptions.remove(queryId);
                debugPrint('🧹 Cleaned up subscription for query $queryId');
              }

              _messageController.add(responseMessage);
            } catch (e, stackTrace) {
              debugPrint('❌ Failed to parse response: $e');
              debugPrint('StackTrace: $stackTrace');
            }
          },
          onDone: () {
            debugPrint('✅ Response stream closed for query $queryId');
            _querySubscriptions.remove(queryId);
          },
          onError: (error) {
            debugPrint('❌ Response stream error for query $queryId: $error');
            _querySubscriptions[queryId]?.cancel();
            _querySubscriptions.remove(queryId);
          },
        );
      });

      debugPrint(
          '✅ Response channel bound for query $queryId, ready for agent connection');

      // Build conversation context from history
      final List<Map<String, dynamic>> context = [];
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        for (final msg in conversationHistory) {
          context.add({
            'role': msg.isUser ? 'user' : 'assistant',
            'content': msg.content,
            'timestamp': msg.timestamp.toIso8601String(),
          });
        }
      }

      // Create the query data with conversation context
      final queryData = {
        'id': message.id,
        'type': 'query',
        'content': message.content,
        'userId': _currentAtSign,
        'timestamp': message.timestamp.toIso8601String(),
        'useOllamaOnly': useOllamaOnly,
        'conversationHistory': context, // Include conversation context
        'conversationId':
            conversationId, // Include conversation ID for response routing (ALWAYS required)
      };

      // Send as notification with same pattern as at_talk
      final metadata = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true
        ..ttl =
            300000; // 5 minutes (300 seconds) - queries expire if agent offline

      final atKey = AtKey()
        ..key = 'query'
        ..namespace = 'personalagent'
        ..sharedWith = _agentAtSign
        ..sharedBy = _currentAtSign
        ..metadata = metadata;

      final jsonData = json.encode(queryData);

      // Send encrypted notification - SDK handles encryption automatically
      await _atClient!.notificationService.notify(
        NotificationParams.forUpdate(atKey, value: jsonData),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

      _logger.info('📤 Sent query to $_agentAtSign');
      debugPrint(
          '📤 Query notification sent, agent will connect to response.$queryId stream');
    } catch (e, stackTrace) {
      debugPrint('Failed to send query: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Start listening for streaming responses from agent using at_stream
  Future<void> startResponseStreamConnection() async {
    if (_atClient == null) {
      throw Exception('AtClient not initialized. Call initialize() first.');
    }

    if (_agentAtSign == null || _agentAtSign!.isEmpty) {
      throw Exception('Agent atSign not set. Call setAgentAtSign() first.');
    }

    _shouldReconnect = true;
    _reconnectAttempts = 0;
    await _connectToStreamWithRetry();
  }

  Future<void> _connectToStreamWithRetry() async {
    if (!_shouldReconnect) return;

    try {
      // Close existing stream if present
      if (_responseStreamChannel != null) {
        try {
          _responseStreamChannel!.sink.close();
        } catch (e) {
          // Ignore errors closing old stream
        }
        _responseStreamChannel = null;
      }

      // Connect to agent's stream channel
      _responseStreamChannel =
          await AtNotificationStreamChannel.connect<String, String>(
        _atClient!,
        otherAtsign: _agentAtSign!,
        baseNamespace: 'personalagent',
        domainNamespace: 'response',
        sendTransformer: QuerySendTransformer(),
        recvTransformer: MessageReceiveTransformer(),
      );

      // Reset reconnect attempts on successful connection
      _reconnectAttempts = 0;
      debugPrint('✅ Stream connection established to $_agentAtSign');

      // Listen for incoming messages from agent
      _responseStreamChannel!.stream.listen(
        (String responseJson) {
          try {
            // Parse JSON response
            final responseData =
                json.decode(responseJson) as Map<String, dynamic>;

            // Ignore ping/pong messages (no longer used for heartbeat)
            if (responseData['type'] == 'ping' ||
                responseData['type'] == 'pong') {
              return;
            }

            // Convert response data to ChatMessage
            final message = ChatMessage(
              id: responseData['id'] ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              content: responseData['content'] ?? '',
              isUser: false,
              timestamp: DateTime.parse(
                responseData['timestamp'] ?? DateTime.now().toIso8601String(),
              ),
              source: _parseSource(responseData['source']),
              wasPrivacyFiltered: responseData['wasPrivacyFiltered'] ?? false,
              agentName: responseData['agentName'] as String?,
              model: responseData['model'] as String?,
              isPartial: responseData['isPartial'] ?? false,
              chunkIndex: responseData['chunkIndex'] as int?,
              conversationId: responseData['conversationId'] as String?,
            );

            // Emit the message to listeners
            _messageController.add(message);
          } catch (e, stackTrace) {
            debugPrint('❌ Failed to handle streamed response: $e');
            debugPrint('StackTrace: $stackTrace');

            // Send error message
            _messageController.add(
              ChatMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                content: 'Failed to parse agent response: $e',
                isUser: false,
                timestamp: DateTime.now(),
                isError: true,
              ),
            );
          }
        },
        onError: (error) {
          debugPrint('❌ General stream error: $error');
          debugPrint('   (This does not affect query-specific streams)');

          // Attempt to reconnect on error
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('🔌 General stream connection closed');
          debugPrint('   (Query-specific streams continue working)');

          // Attempt to reconnect when stream closes
          _scheduleReconnect();
        },
      );

      // Note: We don't close the channel here - it stays open for the session
      // The channel will be closed when the app resets or disposes
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to establish stream connection: $e');
      debugPrint('StackTrace: $stackTrace');

      // Schedule reconnect on connection failure
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;

    // Cancel existing timer if any
    _reconnectTimer?.cancel();

    _reconnectAttempts++;

    // Exponential backoff: 2s, 4s, 8s, 16s, 32s, max 60s
    // Longer delays since query-specific streams handle actual queries
    final delay = Duration(
      seconds: (_reconnectAttempts < 6)
          ? (1 << _reconnectAttempts) // 2^n: 2, 4, 8, 16, 32, 64
          : 60, // Cap at 60 seconds
    );

    debugPrint(
        '🔄 Scheduling general stream reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s...');

    _reconnectTimer = Timer(delay, () {
      _connectToStreamWithRetry();
    });
  }

  /// Stop auto-reconnect (call when user logs out or app closes)
  void stopReconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Save a short-lived mapping from queryId -> conversationId to atPlatform
  /// This helps recover routing after app restarts or provider re-creation
  Future<void> saveQueryMapping(String queryId, String conversationId,
      {int ttlMilliseconds = 3600000}) async {
    if (_atClient == null) {
      // Can't save yet
      return;
    }

    try {
      final key = AtKey()
        ..key = 'mapping.$queryId'
        ..namespace = 'personalagent'
        ..sharedWith = null
        ..metadata = (Metadata()
          ..ttl = ttlMilliseconds
          ..ttr = -1
          ..ccd = false);

      await _atClient!.put(
        key,
        conversationId,
        putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
      );
    } catch (e) {
      // Silently fail - not critical
    }
  }

  /// Retrieve a previously saved query->conversation mapping, or null
  Future<String?> getQueryMapping(String queryId) async {
    if (_atClient == null) {
      return null;
    }

    try {
      final key = AtKey()
        ..key = 'mapping.$queryId'
        ..namespace = 'personalagent'
        ..sharedWith = null;

      final result = await _atClient!.get(key);
      if (result.value != null) {
        return result.value as String;
      }
    } catch (e) {
      // Silently fail - not critical
    }

    return null;
  }

  /// Parse response source from string
  ResponseSource _parseSource(dynamic source) {
    if (source == null) return ResponseSource.ollama;

    final sourceStr = source.toString().toLowerCase();
    if (sourceStr.contains('claude')) return ResponseSource.claude;
    if (sourceStr.contains('hybrid')) return ResponseSource.hybrid;
    return ResponseSource.ollama;
  }

  /// Retrieve stored context from atServer
  Future<List<String>> getContextKeys() async {
    if (_atClient == null) {
      throw Exception('AtClient not initialized');
    }

    try {
      final keys = await _atClient!.getAtKeys(regex: 'context.*');
      return keys.map((key) => key.key.replaceFirst('context.', '')).toList();
    } catch (e, stackTrace) {
      debugPrint('Failed to get context keys: $e');
      debugPrint('StackTrace: $stackTrace');
      return [];
    }
  }

  /// Store context data on atServer
  Future<void> storeContext(String key, String value) async {
    if (_atClient == null) {
      throw Exception('AtClient not initialized');
    }

    try {
      final atKey = AtKey()
        ..key = 'context.$key'
        ..namespace = 'personalagent'
        ..sharedWith = _agentAtSign;

      final contextData = {
        'key': key,
        'value': value,
        'createdAt': DateTime.now().toIso8601String(),
        'tags': <String>[],
      };

      await _atClient!.put(atKey, json.encode(contextData));
    } catch (e, stackTrace) {
      debugPrint('Failed to store context: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Delete context from atServer
  Future<bool> deleteContext(String key) async {
    if (_atClient == null) {
      throw Exception('AtClient not initialized');
    }

    try {
      final atKey = AtKey()
        ..key = 'context.$key'
        ..namespace = 'personalagent'
        ..sharedWith = _agentAtSign;

      await _atClient!.delete(atKey);
      return true;
    } catch (e, stackTrace) {
      debugPrint('Failed to delete context: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }

  /// Reset the service (for switching @signs or signing out)
  Future<void> reset() async {
    // Stop notification listener if active
    try {
      if (_atClient != null) {
        _atClient!.notificationService.stopAllSubscriptions();
      }
    } catch (e) {
      // Ignore errors
    }

    // Clear references
    _atClient = null;
    _atClientManager = null;
    _currentAtSign = null;

    debugPrint('✅ AtClientService reset complete');
  }

  /// Cleanup resources
  void dispose() {
    stopReconnect();

    // Cancel all query-specific subscriptions
    for (final subscription in _querySubscriptions.values) {
      subscription.cancel();
    }
    _querySubscriptions.clear();
    debugPrint(
        '🧹 Cleaned up ${_querySubscriptions.length} query subscriptions');

    _messageController.close();
  }
}
