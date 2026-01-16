import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_stream/at_stream.dart';
import 'package:logging/logging.dart';
import '../models/message.dart';
import 'stream_transformers.dart';

/// Service for managing atPlatform connections and encrypted storage
class AtPlatformService {
  final Logger _logger = Logger('AtPlatformService');
  final String atSign;
  final String keysFilePath;
  final String rootServer;
  final String? instanceId;

  AtClient? _atClient;
  bool _isInitialized = false;

  // Store active stream channels for each connected user
  final Map<String, AtNotificationStreamChannel<String, String>> _activeChannels = {};

  // Store query-specific channels (key: queryId)
  final Map<String, AtNotificationStreamChannel<String, String>> _queryChannels = {};

  AtPlatformService({
    required this.atSign,
    required this.keysFilePath,
    this.rootServer = 'root.atsign.org',
    this.instanceId,
  });

  /// Initialize the atPlatform connection
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.fine('AtPlatform already initialized');
      return;
    }

    try {
      _logger.info('🔧 Initializing atPlatform for $atSign');

      // Load the atKeys file
      final keysFile = File(keysFilePath);
      if (!await keysFile.exists()) {
        throw Exception('atKeys file not found at $keysFilePath');
      }

      // Create unique storage paths for each agent instance
      // This prevents file locking conflicts when running multiple agents with same atSign
      final storageSuffix = instanceId != null && instanceId!.isNotEmpty
          ? '_${instanceId!.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}'
          : '';
      final hiveStoragePath = './storage/hive$storageSuffix';
      final commitLogPath = './storage/commit$storageSuffix';

      _logger.fine('Storage paths:');
      _logger.fine('  Hive: $hiveStoragePath');
      _logger.fine('  Commit: $commitLogPath');

      // Setup onboarding preferences (similar to at_notifications demo)
      final preference = AtOnboardingPreference()
        ..rootDomain = rootServer
        ..namespace = 'personalagent'
        ..hiveStoragePath = hiveStoragePath
        ..commitLogPath = commitLogPath
        ..isLocalStoreRequired = true
        ..atKeysFilePath = keysFilePath;

      // Use AtOnboardingService for proper PKAM authentication
      _logger.fine('Authenticating with PKAM...');
      final onboardingService = AtOnboardingServiceImpl(atSign, preference);

      final authenticated = await onboardingService.authenticate();
      if (!authenticated) {
        throw Exception('Failed to authenticate $atSign with PKAM');
      }

      _logger.fine('✅ PKAM authentication successful');

      // Get the authenticated atClient
      _atClient = onboardingService.atClient;

      // CRITICAL: Set fetchOfflineNotifications to false to ignore old notifications
      // This prevents processing stale queries that accumulated while agent was offline
      _atClient!.getPreferences()!.fetchOfflineNotifications = false;
      _logger.fine('📅 Configured to fetch ONLY new notifications (ignore offline backlog)');

      _isInitialized = true;

      _logger.info('✅ AtPlatform ready');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize atPlatform', e, stackTrace);
      rethrow;
    }
  }

  /// Store encrypted context data
  Future<void> storeContext(ContextData context) async {
    _ensureInitialized();

    try {
      final atKey = AtKey()
        ..key = 'context.${context.key}'
        ..namespace = 'personalagent'
        ..sharedWith = atSign; // Only accessible by this atSign

      final jsonData = json.encode(context.toJson());
      await _atClient!.put(atKey, jsonData);

      _logger.info('Stored context: ${context.key}');
    } catch (e, stackTrace) {
      _logger.severe('Failed to store context', e, stackTrace);
      rethrow;
    }
  }

  /// Retrieve encrypted context data
  Future<ContextData?> getContext(String key) async {
    _ensureInitialized();

    try {
      final atKey = AtKey()
        ..key = 'context.$key'
        ..namespace = 'personalagent'
        ..sharedWith = atSign;

      final value = await _atClient!.get(atKey);
      if (value.value == null) {
        return null;
      }

      final jsonData = json.decode(value.value);
      return ContextData.fromJson(jsonData);
    } catch (e, stackTrace) {
      _logger.warning('Failed to retrieve context: $key', e, stackTrace);
      return null;
    }
  }

  /// List all context keys
  Future<List<String>> listContextKeys() async {
    _ensureInitialized();

    try {
      final keys = await _atClient!.getAtKeys(regex: 'context.*');
      return keys.map((key) => key.key.replaceFirst('context.', '')).toList();
    } catch (e, stackTrace) {
      _logger.severe('Failed to list context keys', e, stackTrace);
      return [];
    }
  }

  /// Delete context data
  Future<bool> deleteContext(String key) async {
    _ensureInitialized();

    try {
      final atKey = AtKey()
        ..key = 'context.$key'
        ..namespace = 'personalagent'
        ..sharedWith = atSign;

      await _atClient!.delete(atKey);
      _logger.info('Deleted context: $key');
      return true;
    } catch (e, stackTrace) {
      _logger.warning('Failed to delete context: $key', e, stackTrace);
      return false;
    }
  }

  /// Subscribe to incoming messages from Flutter app
  Future<void> subscribeToMessages(Future<void> Function(QueryMessage) onQueryReceived) async {
    _ensureInitialized();

    _logger.fine('🔔 Setting up notification listener');
    _logger.fine('   AtClient: ${_atClient != null ? "initialized" : "NULL"}');
    _logger.fine('   NotificationService: ${_atClient?.notificationService != null ? "available" : "NULL"}');

    try {
      // Subscribe with same pattern as at_talk - this makes auto-decryption work!
      _logger.fine('📡 Subscribing with regex: query.personalagent@');
      _logger.fine('   (Following at_talk_gui pattern for auto-decryption)');

      final stream = _atClient!.notificationService.subscribe(regex: 'query.personalagent@', shouldDecrypt: true);

      _logger.fine('✅ Subscribe call completed, got stream');

      stream.listen(
        (notification) async {
          try {
            _logger.fine('🎉 NOTIFICATION RECEIVED!');
            _logger.fine('   From: ${notification.from}');
            _logger.fine('   Key: ${notification.key}');
            _logger.fine('   ID: ${notification.id}');

            // Skip stats notifications (ID: -1)
            if (notification.id == '-1') {
              _logger.fine('   ⏭️  Skipping stats notification');
              return;
            }

            // Filter for query notifications only
            if (!notification.key.contains('query')) {
              _logger.fine('   ⏭️  Skipping non-query notification');
              return;
            }

            // Value should be auto-decrypted by SDK (like at_talk)
            if (notification.value == null) {
              _logger.warning('⚠️ Notification value is null');
              return;
            }

            _logger.fine(
              '   Value preview: ${notification.value!.substring(0, notification.value!.length > 100 ? 100 : notification.value!.length)}...',
            );

            // Parse the JSON data - should be decrypted automatically
            final jsonData = json.decode(notification.value!);
            _logger.fine('✅ JSON decoded successfully (auto-decrypted!)');

            // Parse as QueryMessage
            final useOllamaOnly = jsonData['useOllamaOnly'] ?? false;
            final conversationHistory = jsonData['conversationHistory'] as List<dynamic>?;
            final streamSessionId = jsonData['streamSessionId'] as String?;

            final query = QueryMessage(
              id: jsonData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              content: jsonData['content'] ?? '',
              userId: jsonData['userId'] ?? notification.from ?? '',
              useOllamaOnly: useOllamaOnly,
              conversationHistory: conversationHistory?.cast<Map<String, dynamic>>(),
              conversationId: jsonData['conversationId'] as String?,
              streamSessionId: streamSessionId, // Stream session ID for routing
              notificationId: notification.id, // CRITICAL: Use notification ID for mutex
              timestamp: DateTime.parse(jsonData['timestamp'] ?? DateTime.now().toIso8601String()),
            );

            _logger.info('[${query.id}] ⚡ Processing query');
            _logger.info('[${query.id}]    Ollama-Only Mode: ${useOllamaOnly ? "ENABLED 🔒" : "disabled"}');
            _logger.info('[${query.id}]    Conversation History: ${conversationHistory?.length ?? 0} messages');
            _logger.info(
              '[${query.id}]    Content: ${query.content.substring(0, query.content.length > 50 ? 50 : query.content.length)}...',
            );

            // Call the callback to process the query
            await onQueryReceived(query);

            _logger.info('[${query.id}] ✅ Query processed successfully');
          } catch (e, stackTrace) {
            _logger.severe('❌ Failed to parse or process query', e, stackTrace);
          }
        },
        onError: (error, stackTrace) {
          _logger.warning('⚠️ Notification stream error: $error');
          _logger.fine('Stack trace: $stackTrace');
          // The SDK will automatically retry the connection
        },
        onDone: () {
          _logger.info('🔌 Notification stream closed');
          _logger.fine('   The SDK will automatically reconnect');
        },
        cancelOnError: false, // Keep listening even if there are errors
      );

      _logger.info('✅ Listening for queries');
      _logger.fine('   Pattern: query.*');
      _logger.fine('   Namespace: personalagent');
      _logger.fine('   Decryption: enabled');
      _logger.fine('   Ready to receive from any @sign');
    } catch (e, stackTrace) {
      _logger.severe('Failed to start notification listener', e, stackTrace);
      rethrow;
    }
  }

  /// Send response message to Flutter app
  /// Check if we have a stream channel for the given recipient
  /// Used to determine if this agent instance should respond to a query
  bool hasStreamChannel(String recipientAtSign, {String? streamSessionId}) {
    _logger.fine('🔍 Checking stream channel for $recipientAtSign (sessionId: $streamSessionId)');
    _logger.fine('   Active channels: ${_activeChannels.length}');

    if (streamSessionId != null) {
      // Check if we have a channel with this session ID
      _logger.fine('   Looking for sessionId: $streamSessionId');
      for (final entry in _activeChannels.entries) {
        _logger.fine('   Channel ${entry.key}: sessionId = ${entry.value.sessionId}');
        if (entry.value.sessionId == streamSessionId) {
          _logger.fine('   ✅ MATCH! This agent has the channel');
          return true;
        }
      }
      _logger.fine('   ❌ NO MATCH! This agent does NOT have the channel');
      return false;
    } else {
      _logger.fine('   No sessionId provided, falling back to atSign check');
      final hasIt = _activeChannels.containsKey(recipientAtSign);
      _logger.fine('   Result: $hasIt');
      return hasIt;
    }
  }

  /// Send response via stream channel (stream-only, requires sessionId)
  Future<void> sendStreamResponse(String recipientAtSign, ResponseMessage response, {String? streamSessionId}) async {
    _ensureInitialized();

    // Try to find the stream channel for this recipient
    // If streamSessionId is provided, use it to find the correct channel (for mutex winners)
    // Otherwise, use recipientAtSign to find channel (for original notification receiver)
    dynamic channel;

    if (streamSessionId != null) {
      // Find channel by sessionId - allows any agent instance to respond
      for (final entry in _activeChannels.entries) {
        if (entry.value.sessionId == streamSessionId) {
          channel = entry.value;
          break;
        }
      }

      if (channel == null) {
        _logger.warning('No active stream channel with session ID: $streamSessionId');
        final availableSessions = _activeChannels.values.map((ch) => ch.sessionId).join(", ");
        _logger.warning('Available sessions: $availableSessions');
        throw Exception('No active stream channel for session $streamSessionId');
      }
      _logger.fine('📍 Found channel by session ID: $streamSessionId');
    } else {
      // Fall back to looking up by atSign
      channel = _activeChannels[recipientAtSign];

      if (channel == null) {
        _logger.warning('No active stream channel for $recipientAtSign');
        _logger.warning('Active channels: ${_activeChannels.keys.join(", ")}');
        throw Exception('No active stream channel for $recipientAtSign');
      }
      _logger.fine('📍 Found channel by atSign: $recipientAtSign');
    }

    try {
      // Send via stream channel
      final jsonData = json.encode(response.toJson());
      channel.sink.add(jsonData);
      _logger.fine('📤 Sent response via stream to $recipientAtSign');
    } catch (e, stackTrace) {
      _logger.severe('Failed to send response via stream', e, stackTrace);

      // Remove the channel since it's not working
      _activeChannels.remove(recipientAtSign);

      // Check if this is a timeout or network error - these are recoverable
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('timeout') ||
          errorString.contains('timed out') ||
          errorString.contains('network') ||
          errorString.contains('remote atsign not found') ||
          errorString.contains('full response not received')) {
        _logger.warning('⚠️ Network/timeout error sending to $recipientAtSign - client may retry');
        // Don't rethrow - this is expected when network is down
        return;
      }

      // For other unexpected errors, rethrow so caller can handle
      rethrow;
    }
  }

  /// Try to acquire mutex for a query (ensures only one agent responds)
  /// Accepts nullable mutexId to handle edge cases
  /// Implementation based on sshnpd's session mutex pattern
  Future<bool> acquireQueryMutex(Object mutexId, String agentName) async {
    _ensureInitialized();

    final id = mutexId.toString();
    if (id.isEmpty || id == 'null') {
      _logger.warning('⚠️ No valid mutex ID provided');
      return false;
    }

    try {
      final mutexKey = AtKey()
        ..key = 'mutex.$id'
        ..namespace = 'personalagent'
        ..sharedBy = atSign
        ..sharedWith =
            atSign // Self-shared for coordination between agent instances
        ..metadata = (Metadata()
          ..immutable =
              true // Only one agent will succeed in creating this
          ..ttl =
              60000 // 60 seconds TTL
          ..isPublic = false
          ..isEncrypted = false); // Don't encrypt for faster ops

      // Use PutRequestOptions to ensure operation happens on remote server
      final putOptions = PutRequestOptions()
        ..shouldEncrypt = false
        ..useRemoteAtServer = true; // Critical: ensures all agents check same server

      try {
        await _atClient!.put(mutexKey, agentName, putRequestOptions: putOptions);
        _logger.shout('� Acquired mutex for query $id; will handle this request');
        return true;
      } catch (err) {
        if (err.toString().toLowerCase().contains('immutable')) {
          _logger.shout('🤷‍♂️ Did not acquire mutex for query $id; another agent will handle this');
          return false;
        } else {
          _logger.warning('Unexpected error acquiring mutex: $err');
          return true; // Proceed anyway to maintain functionality
        }
      }
    } catch (e, stackTrace) {
      _logger.warning('Failed to acquire mutex', e, stackTrace);
      return false;
    }
  }

  /// Connect to query-specific response stream and send response
  Future<void> sendStreamResponseToQuery(String recipientAtSign, String queryId, ResponseMessage response) async {
    _ensureInitialized();

    try {
      // Check if we already have a channel for this query
      AtNotificationStreamChannel<String, String>? channel = _queryChannels[queryId];

      if (channel == null) {
        // First message for this query - establish connection with retry
        _logger.info('[${queryId}] 🔗 Connecting to query-specific stream: response.$queryId');

        // Retry connection up to 3 times with increasing delays
        int retryCount = 0;
        const maxRetries = 3;
        Exception? lastError;

        while (channel == null && retryCount < maxRetries) {
          try {
            channel = await AtNotificationStreamChannel.connect<String, String>(
              _atClient!,
              otherAtsign: recipientAtSign,
              baseNamespace: 'personalagent',
              domainNamespace: 'response.$queryId', // Query-specific namespace
              sendTransformer: const MessageSendTransformer(),
              recvTransformer: const QueryReceiveTransformer(),
            );
            _logger.info('[${queryId}] ✅ Connected to query stream');
          } catch (e) {
            lastError = e as Exception;
            retryCount++;
            if (retryCount < maxRetries) {
              final delayMs = 200 * retryCount; // 200ms, 400ms, 600ms
              _logger.warning('[${queryId}] ⚠️ Connection attempt $retryCount failed, retrying in ${delayMs}ms: $e');
              await Future.delayed(Duration(milliseconds: delayMs));
            }
          }
        }

        if (channel == null) {
          _logger.severe('[${queryId}] ❌ Failed to connect after $maxRetries attempts');
          throw lastError ?? Exception('Failed to connect to stream');
        }

        // Cache the channel for reuse
        _queryChannels[queryId] = channel;
      }

      // Send the response through the existing/cached channel
      final jsonData = json.encode(response.toJson());
      channel.sink.add(jsonData);
      _logger.fine('📤 Sent response for query $queryId (isPartial: ${response.isPartial})');

      // If this is the final message, send disconnect and cleanup
      if (!response.isPartial) {
        _logger.finer('[${queryId}] 🏁 Sending final message, will disconnect');

        // Give a brief moment for the message to be sent
        await Future.delayed(const Duration(milliseconds: 100));

        // Send disconnect control message
        channel.sink.add(json.encode({'control': 'disconnect'}));

        // Give time for disconnect message to be sent, then remove from cache
        // Don't explicitly close the sink - let it be garbage collected
        await Future.delayed(const Duration(milliseconds: 100));
        _queryChannels.remove(queryId);
        _logger.info('[${queryId}] ✅ Completed query, cleaned up channel');
      }
    } catch (e, stackTrace) {
      _logger.severe('[${queryId}] Failed to send response to query stream', e, stackTrace);

      // Remove channel from cache - it's likely invalid now
      _queryChannels.remove(queryId);
      _logger.warning('[${queryId}] Removed cached channel due to error');

      // Check if this is a timeout or network error - these are recoverable
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('timeout') ||
          errorString.contains('timed out') ||
          errorString.contains('network') ||
          errorString.contains('remote atsign not found') ||
          errorString.contains('full response not received')) {
        _logger.warning('[${queryId}] ⚠️ Network/timeout error - client may retry');
        // Don't rethrow - this is expected when network is down
        // The calling code already has error handling for this
        return;
      }

      // For other unexpected errors, rethrow so caller can handle
      rethrow;
    }
  }

  /// Start listening for response stream connection requests from apps
  /// This uses at_stream to establish efficient bi-directional channels
  void startResponseStreamListener() {
    _ensureInitialized();

    _logger.info('🎧 Listening for stream connections');
    _logger.fine('   Base namespace: personalagent');
    _logger.fine('   Domain namespace: response');

    try {
      // Bind listener for incoming stream connection requests
      AtNotificationStreamChannel.bind<String, String>(
        _atClient!,
        baseNamespace: 'personalagent',
        domainNamespace: 'response',
        sendTransformer: const MessageSendTransformer(),
        recvTransformer: const QueryReceiveTransformer(),
      ).listen(
        (channel) async {
          final fromAtSign = channel.otherAtsign;
          _logger.info('🔗 Connected: $fromAtSign');
          _logger.fine('   Session ID: ${channel.sessionId}');

          // Store the channel for this user
          _activeChannels[fromAtSign] = channel;
          _logger.info('   Total active channels: ${_activeChannels.length}');

          // Listen for incoming data and channel closure
          channel.stream.listen(
            (data) {
              // Could handle control messages here in the future
              // For now, just ignore incoming data on the general stream
              _logger.fine('📥 Received data from $fromAtSign: ${data.substring(0, 50)}...');
            },
            onDone: () {
              _logger.info('🔌 Disconnected: $fromAtSign');
              _activeChannels.remove(fromAtSign);
            },
            onError: (error) {
              _logger.warning('⚠️ Channel error with $fromAtSign: $error');
              _activeChannels.remove(fromAtSign);
            },
          );
        },
        onError: (error, stackTrace) {
          _logger.warning('⚠️ Stream channel error: $error');
          _logger.fine('Stack trace: $stackTrace');
        },
        onDone: () {
          _logger.info('🔌 Stream channel listener closed');
        },
        cancelOnError: false,
      );

      _logger.fine('✅ Response stream listener is ACTIVE');
    } catch (e, stackTrace) {
      _logger.severe('Failed to start response stream listener', e, stackTrace);
      rethrow;
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('AtPlatformService not initialized. Call initialize() first.');
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    // Cleanup if needed
    _isInitialized = false;
  }
}
