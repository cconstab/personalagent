import 'dart:async';
import 'dart:convert';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_commons/at_commons.dart';
import 'package:at_stream/at_stream.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import 'stream_transformers.dart';

/// Service for communicating with the agent via atPlatform
class AtClientService {
  static final AtClientService _instance = AtClientService._internal();
  factory AtClientService() => _instance;
  AtClientService._internal();

  AtClientManager? _atClientManager;
  AtClient? _atClient;
  String? _currentAtSign;
  String? _agentAtSign;

  final _messageController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get messageStream => _messageController.stream;

  bool get isInitialized => _atClient != null;
  String? get currentAtSign => _currentAtSign;
  String? get agentAtSign => _agentAtSign;

  /// Initialize atClient for the current user
  Future<void> initialize(String atSign) async {
    try {
      debugPrint('🔄 Initializing AtClientService for $atSign');

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
        debugPrint('⚠️ SDK is using $currentAtSign but we want $atSign');
        debugPrint('   This indicates AtOnboarding.onboard() did not switch @signs properly');
        throw Exception('SDK initialized with wrong @sign: $currentAtSign (expected $atSign)');
      }

      if (currentAtSign != null) {
        _currentAtSign = atSign;
        _atClient = manager.atClient;
        debugPrint('✅ AtClient initialized for $currentAtSign');
      } else {
        // This shouldn't happen after successful onboarding
        throw Exception('AtClient not initialized. Onboarding may not have completed successfully.');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize AtClientService: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow; // Rethrow so caller knows initialization failed
    }
  }

  /// Set the agent's @sign
  void setAgentAtSign(String agentAtSign) {
    _agentAtSign = agentAtSign;
    debugPrint('Agent @sign set to: $agentAtSign');
  }

  /// Send a query message to the agent with conversation context
  Future<void> sendQuery(
    ChatMessage message, {
    bool useOllamaOnly = false,
    List<ChatMessage>? conversationHistory,
    String? conversationId,
  }) async {
    if (_atClient == null) {
      throw Exception('AtClient not initialized. Call initialize() first.');
    }

    if (_agentAtSign == null || _agentAtSign!.isEmpty) {
      throw Exception('Agent @sign not set. Call setAgentAtSign() first.');
    }

    try {
      debugPrint('📤 Sending query to $_agentAtSign');
      debugPrint('   From: $_currentAtSign');
      debugPrint('   Ollama Only: $useOllamaOnly');
      debugPrint('   With ${conversationHistory?.length ?? 0} previous messages');
      debugPrint(
          '   Message: ${message.content.substring(0, message.content.length > 50 ? 50 : message.content.length)}...');

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
        if (conversationId != null) 'conversationId': conversationId, // Include conversation ID for response routing
      };

      // Send as notification with same pattern as at_talk
      final metadata = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true
        ..ttl = 300000; // 5 minutes (300 seconds) - queries expire if agent offline

      final atKey = AtKey()
        ..key = 'query'
        ..namespace = 'personalagent'
        ..sharedWith = _agentAtSign
        ..sharedBy = _currentAtSign
        ..metadata = metadata;

      debugPrint('   Key: ${atKey.toString()}');

      final jsonData = json.encode(queryData);

      // Send encrypted notification - SDK handles encryption automatically
      final notificationResult = await _atClient!.notificationService.notify(
        NotificationParams.forUpdate(atKey, value: jsonData),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

      debugPrint('✅ Query sent successfully!');
      debugPrint('   Notification ID: ${notificationResult.notificationID}');
      debugPrint('   To: $_agentAtSign');
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
      throw Exception('Agent @sign not set. Call setAgentAtSign() first.');
    }

    try {
      debugPrint('🔌 Connecting to response stream from $_agentAtSign');

      // Connect to agent's stream channel
      final channel = await AtNotificationStreamChannel.connect<String, String>(
        _atClient!,
        otherAtsign: _agentAtSign!,
        baseNamespace: 'personalagent',
        domainNamespace: 'response',
        sendTransformer: QuerySendTransformer(),
        recvTransformer: MessageReceiveTransformer(),
      );

      debugPrint('✅ Connected to response stream channel');

      // Listen for incoming messages from agent
      channel.stream.listen(
        (String responseJson) {
          try {
            debugPrint('📨 Received streamed response chunk');

            // Parse JSON response
            final responseData = json.decode(responseJson) as Map<String, dynamic>;
            debugPrint('   Type: ${responseData['type']}');

            // Convert response data to ChatMessage
            final message = ChatMessage(
              id: responseData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              content: responseData['content'] ?? '',
              isUser: false,
              timestamp: DateTime.parse(
                responseData['timestamp'] ?? DateTime.now().toIso8601String(),
              ),
              source: _parseSource(responseData['source']),
              wasPrivacyFiltered: responseData['wasPrivacyFiltered'] ?? false,
              agentName: responseData['agentName'] as String?,
              model: responseData['model'] as String?,
              isPartial: responseData['metadata']?['isPartial'] ?? false,
              chunkIndex: responseData['metadata']?['chunkIndex'] as int?,
              conversationId: responseData['metadata']?['conversationId'] as String?,
            );

            // Emit the message to listeners
            _messageController.add(message);

            if (message.isPartial) {
              debugPrint('📦 Streaming chunk ${message.chunkIndex} received for ${message.id}');
              debugPrint('   ConversationId: ${message.conversationId}');
            } else {
              debugPrint('✅ Final message received for ${message.id}');
              debugPrint('   ConversationId: ${message.conversationId}');
            }
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
          debugPrint('❌ Response stream error: $error');
          _messageController.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              content: 'Stream connection error: $error',
              isUser: false,
              timestamp: DateTime.now(),
              isError: true,
            ),
          );
        },
        onDone: () {
          debugPrint('🔌 Response stream connection closed');
        },
      );

      // Note: We don't close the channel here - it stays open for the session
      // The channel will be closed when the app resets or disposes

      debugPrint('✅ Response stream listener active');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to connect to response stream: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Save a short-lived mapping from queryId -> conversationId to atPlatform
  /// This helps recover routing after app restarts or provider re-creation
  Future<void> saveQueryMapping(String queryId, String conversationId, {int ttlMilliseconds = 3600000}) async {
    if (_atClient == null) {
      debugPrint('⚠️ AtClient not initialized, cannot save query mapping');
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

      final putResult = await _atClient!.put(
        key,
        conversationId,
        putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
      );

      debugPrint('💾 Saved query mapping $queryId -> $conversationId');
      debugPrint('   Commit: ${putResult ? "success" : "failed"}');
    } catch (e, st) {
      debugPrint('❌ Failed to save query mapping: $e');
      debugPrint('StackTrace: $st');
    }
  }

  /// Retrieve a previously saved query->conversation mapping, or null
  Future<String?> getQueryMapping(String queryId) async {
    if (_atClient == null) {
      debugPrint('⚠️ AtClient not initialized, cannot load query mapping');
      return null;
    }

    try {
      final key = AtKey()
        ..key = 'mapping.$queryId'
        ..namespace = 'personalagent'
        ..sharedWith = null;

      final result = await _atClient!.get(key);
      if (result.value != null) {
        debugPrint('🔍 Found remote mapping for $queryId -> ${result.value}');
        return result.value as String;
      }
    } catch (e, st) {
      debugPrint('❌ Failed to load query mapping $queryId: $e');
      debugPrint('StackTrace: $st');
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
      debugPrint('Context stored: $key');
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
      debugPrint('Context deleted: $key');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Failed to delete context: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }

  /// Reset the service (for switching @signs or signing out)
  Future<void> reset() async {
    debugPrint('🔄 Resetting AtClientService');
    debugPrint('   Closing connections for $_currentAtSign');

    // Stop notification listener if active
    try {
      if (_atClient != null) {
        _atClient!.notificationService.stopAllSubscriptions();
        debugPrint('   Stopped notification subscriptions');
      }
    } catch (e) {
      debugPrint('   Error stopping notifications: $e');
    }

    // Clear references
    _atClient = null;
    _atClientManager = null;
    _currentAtSign = null;

    debugPrint('✅ AtClientService reset complete');
  }

  /// Cleanup resources
  void dispose() {
    _messageController.close();
  }
}
