import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:logging/logging.dart';
import '../models/message.dart';

/// Service for managing atPlatform connections and encrypted storage
class AtPlatformService {
  final Logger _logger = Logger('AtPlatformService');
  final String atSign;
  final String keysFilePath;
  final String rootServer;

  AtClient? _atClient;
  AtClientManager? _atClientManager;
  bool _isInitialized = false;

  AtPlatformService({
    required this.atSign,
    required this.keysFilePath,
    this.rootServer = 'root.atsign.org',
  });

  /// Initialize the atPlatform connection
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.info('AtPlatform already initialized');
      return;
    }

    try {
      _logger.info('Initializing atPlatform for $atSign');

      // Load the atKeys file
      final keysFile = File(keysFilePath);
      if (!await keysFile.exists()) {
        throw Exception('atKeys file not found at $keysFilePath');
      }

      // Setup onboarding preferences (similar to at_notifications demo)
      final preference = AtOnboardingPreference()
        ..rootDomain = rootServer
        ..namespace = 'personalagent'
        ..hiveStoragePath = './storage/hive'
        ..commitLogPath = './storage/commit'
        ..isLocalStoreRequired = true
        ..atKeysFilePath = keysFilePath;

      // Use AtOnboardingService for proper PKAM authentication
      _logger.info('Authenticating with PKAM...');
      final onboardingService = AtOnboardingServiceImpl(atSign, preference);

      final authenticated = await onboardingService.authenticate();
      if (!authenticated) {
        throw Exception('Failed to authenticate $atSign with PKAM');
      }

      _logger.info('✅ PKAM authentication successful');

      // Get the authenticated atClient
      _atClient = onboardingService.atClient;
      _atClientManager = AtClientManager.getInstance();
      _isInitialized = true;

      _logger.info('✅ AtPlatform initialized successfully');
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
  Future<void> subscribeToMessages(
      Future<void> Function(QueryMessage) onQueryReceived) async {
    _ensureInitialized();

    _logger.info('🔔 Setting up notification listener');
    _logger.info('   AtClient: ${_atClient != null ? "initialized" : "NULL"}');
    _logger.info(
        '   NotificationService: ${_atClient?.notificationService != null ? "available" : "NULL"}');

    try {
      // Subscribe with same pattern as at_talk - this makes auto-decryption work!
      _logger.info('📡 Subscribing with regex: query.personalagent@');
      _logger.info('   (Following at_talk_gui pattern for auto-decryption)');

      final stream = _atClient!.notificationService
          .subscribe(regex: 'query.personalagent@', shouldDecrypt: true);

      _logger.info('✅ Subscribe call completed, got stream');

      stream.listen(
        (notification) async {
          try {
            _logger.info('🎉 NOTIFICATION RECEIVED!');
            _logger.info('   From: ${notification.from}');
            _logger.info('   Key: ${notification.key}');
            _logger.info('   ID: ${notification.id}');

            // Skip stats notifications (ID: -1)
            if (notification.id == '-1') {
              _logger.info('   ⏭️  Skipping stats notification');
              return;
            }

            // Filter for query notifications only
            if (!notification.key.contains('query')) {
              _logger.info('   ⏭️  Skipping non-query notification');
              return;
            }

            // Value should be auto-decrypted by SDK (like at_talk)
            if (notification.value == null) {
              _logger.warning('⚠️ Notification value is null');
              return;
            }

            _logger.info(
                '   Value preview: ${notification.value!.substring(0, notification.value!.length > 100 ? 100 : notification.value!.length)}...');

            // Parse the JSON data - should be decrypted automatically
            final jsonData = json.decode(notification.value!);
            _logger.info('✅ JSON decoded successfully (auto-decrypted!)');

            // Parse as QueryMessage
            final useOllamaOnly = jsonData['useOllamaOnly'] ?? false;
            final query = QueryMessage(
              id: jsonData['id'] ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              content: jsonData['content'] ?? '',
              userId: jsonData['userId'] ?? notification.from ?? '',
              useOllamaOnly: useOllamaOnly,
              timestamp: DateTime.parse(
                jsonData['timestamp'] ?? DateTime.now().toIso8601String(),
              ),
            );

            _logger.info('⚡ Processing query: ${query.id}');
            _logger.info(
                '   Ollama-Only Mode: ${useOllamaOnly ? "ENABLED 🔒" : "disabled"}');
            _logger.info(
                '   Content: ${query.content.substring(0, query.content.length > 50 ? 50 : query.content.length)}...');

            // Call the callback to process the query
            await onQueryReceived(query);

            _logger.info('✅ Query processed successfully');
          } catch (e, stackTrace) {
            _logger.severe('❌ Failed to parse or process query', e, stackTrace);
          }
        },
        onError: (error, stackTrace) {
          _logger.warning('⚠️ Notification stream error: $error');
          _logger.warning('Stack trace: $stackTrace');
          // The SDK will automatically retry the connection
        },
        onDone: () {
          _logger.info('🔌 Notification stream closed');
          _logger.info('   The SDK will automatically reconnect');
        },
        cancelOnError: false, // Keep listening even if there are errors
      );

      _logger.info('✅✅✅ Notification listener is ACTIVE and waiting');
      _logger.info('   Pattern: query.*');
      _logger.info('   Namespace: personalagent');
      _logger.info('   Decryption: enabled');
      _logger.info('   Ready to receive from any @sign');
    } catch (e, stackTrace) {
      _logger.severe('Failed to start notification listener', e, stackTrace);
      rethrow;
    }
  }

  /// Send response message to Flutter app
  Future<void> sendResponse(
      String recipientAtSign, ResponseMessage response) async {
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

      _logger.info(
          'Sent response to $recipientAtSign: ${notificationResult.notificationID}');
    } catch (e, stackTrace) {
      _logger.severe('Failed to send response', e, stackTrace);
      rethrow;
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception(
          'AtPlatformService not initialized. Call initialize() first.');
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    // Cleanup if needed
    _isInitialized = false;
  }
}
