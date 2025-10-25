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

            final query = QueryMessage(
              id: jsonData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              content: jsonData['content'] ?? '',
              userId: jsonData['userId'] ?? notification.from ?? '',
              useOllamaOnly: useOllamaOnly,
              conversationHistory: conversationHistory?.cast<Map<String, dynamic>>(),
              notificationId: notification.id, // CRITICAL: Use notification ID for mutex
              timestamp: DateTime.parse(jsonData['timestamp'] ?? DateTime.now().toIso8601String()),
            );

            _logger.info('⚡ Processing query: ${query.id}');
            _logger.info('   Ollama-Only Mode: ${useOllamaOnly ? "ENABLED 🔒" : "disabled"}');
            _logger.info('   Conversation History: ${conversationHistory?.length ?? 0} messages');
            _logger.info(
              '   Content: ${query.content.substring(0, query.content.length > 50 ? 50 : query.content.length)}...',
            );

            // Call the callback to process the query
            await onQueryReceived(query);

            _logger.info('✅ Query processed successfully');
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
  Future<void> sendResponse(String recipientAtSign, ResponseMessage response) async {
    _ensureInitialized();

    try {
      final atKey = AtKey()
        ..key = 'message.${response.id}'
        ..namespace = 'personalagent'
        ..sharedWith = recipientAtSign;

      final jsonData = json.encode(response.toJson());

      // Use notificationService.notify instead of direct notify
      final notificationResult = await _atClient!.notificationService.notify(
        NotificationParams.forUpdate(atKey, value: jsonData),
      );

      _logger.fine('Sent response to $recipientAtSign: ${notificationResult.notificationID}');
    } catch (e, stackTrace) {
      _logger.severe('Failed to send response', e, stackTrace);
      rethrow;
    }
  }

  /// Send response via stream channel (stream-only, no fallback)
  Future<void> sendStreamResponse(String recipientAtSign, ResponseMessage response) async {
    _ensureInitialized();

    // Get the active stream channel for this recipient
    final channel = _activeChannels[recipientAtSign];

    if (channel == null) {
      _logger.warning('No active stream channel for $recipientAtSign');
      _logger.warning('Active channels: ${_activeChannels.keys.join(", ")}');
      throw Exception('No active stream channel for $recipientAtSign. App must connect before sending queries.');
    }

    try {
      // Send via stream channel
      final jsonData = json.encode(response.toJson());
      channel.sink.add(jsonData);

      _logger.fine('📤 Sent response via stream to $recipientAtSign');
    } catch (e, stackTrace) {
      _logger.severe('Failed to send response via stream to $recipientAtSign', e, stackTrace);
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
              // Handle ping messages from app
              try {
                final decoded = json.decode(data);
                if (decoded['type'] == 'ping') {
                  _logger.fine('📡 Received ping from $fromAtSign');
                }
              } catch (e) {
                // Ignore parse errors - might not be JSON
              }
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

  /// Try to acquire a mutex for a specific identifier (query ID, session ID, etc.).
  /// Returns true if this instance acquired the mutex, false if another instance already has it.
  ///
  /// This implements an atomic mutex pattern for load balancing between multiple agents:
  /// - Uses immutable metadata flag to make key creation atomic
  /// - First agent to successfully create the key wins (like sshnpd pattern)
  /// - Other agents get AtKeyException and know to skip the query
  /// - Mutex expires after ttlSeconds to prevent stale locks
  Future<bool> tryAcquireMutex({required String mutexId, int ttlSeconds = 30}) async {
    _ensureInitialized();

    try {
      // Create mutex key with IMMUTABLE flag for atomic creation
      // This is the same pattern used by sshnpd for mutex coordination
      // CRITICAL: Use AtKey.fromString with full key path to create PRIVATE key
      // that all instances of the same atSign will see identically
      final mutexKey = AtKey.fromString('$mutexId.query_mutexes.personalagent$atSign')
        ..metadata = (Metadata()
          ..ttl =
              ttlSeconds *
              1000 // TTL in milliseconds
          ..immutable = true); // CRITICAL: Makes creation atomic - first wins!

      _logger.info('Attempting to acquire mutex: $mutexId (key: $mutexId.query_mutexes.personalagent$atSign)');

      // Try to create the mutex key atomically
      // If another agent already created it, this will throw an exception
      final lockData = json.encode({
        'timestamp': DateTime.now().toIso8601String(),
        'agent': atSign,
        'instanceId': instanceId ?? 'default',
      });

      final putOptions = PutRequestOptions()..useRemoteAtServer = true; // CRITICAL: write to remote server

      await _atClient!.put(mutexKey, lockData, putRequestOptions: putOptions);

      // Success! This agent won the mutex
      _logger.info('✅ Acquired mutex: $mutexId');
      return true;
    } on AtKeyException catch (e) {
      // Another agent already has the mutex (immutable key already exists)
      _logger.info('🔒 Mutex held by another agent: $mutexId - ${e.message}');
      return false;
    } catch (e) {
      // Check if this is an immutable key error (different exception type)
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('immutable')) {
        _logger.info('🔒 Mutex held by another agent: $mutexId - $e');
        return false;
      }

      // For any other error, log it but allow the query to proceed
      // This ensures the system keeps working even if there are unexpected issues
      _logger.warning('⚠️ Error with mutex (will proceed anyway): $e');
      return true;
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    // Cleanup if needed
    _isInitialized = false;
  }
}
