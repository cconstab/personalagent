import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:at_client/at_client.dart';
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

      // Setup atClient preferences
      final preference = AtClientPreference()
        ..rootDomain = rootServer
        ..namespace = 'personalagent'
        ..hiveStoragePath = './storage/hive'
        ..commitLogPath = './storage/commit'
        ..isLocalStoreRequired = true
        ..privateKey = null; // Will be loaded from file

      // Initialize atClientManager
      await AtClientManager.getInstance().setCurrentAtSign(
        atSign,
        preference.namespace!,
        preference,
      );

      _atClientManager = AtClientManager.getInstance();
      _atClient = _atClientManager!.atClient;
      _isInitialized = true;

      _logger.info('AtPlatform initialized successfully');
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

  /// Listen for incoming messages from Flutter app
  Stream<AgentMessage> listenForMessages() async* {
    _ensureInitialized();

    _logger.info('Starting message listener');

    // Set up notification listener
    _atClient!.notificationService
        .subscribe(regex: 'message.*', shouldDecrypt: true)
        .listen((notification) {
      try {
        final jsonData = json.decode(notification.value!);
        final message = AgentMessage.fromJson(jsonData);
        _logger.info('Received message: ${message.id}');
      } catch (e, stackTrace) {
        _logger.warning('Failed to parse message', e, stackTrace);
      }
    });

    // For now, return empty stream - implement full notification handling
    await Future.delayed(Duration.zero);
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
