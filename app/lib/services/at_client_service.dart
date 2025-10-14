import 'dart:async';
import 'dart:convert';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_commons/at_commons.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';

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
    if (_atClient != null && _currentAtSign == atSign) {
      debugPrint('AtClientService already initialized for $atSign');
      return;
    }

    try {
      debugPrint('Initializing AtClientService for $atSign');
      _currentAtSign = atSign;

      // Get the AtClientManager instance
      _atClientManager = AtClientManager.getInstance();
      
      // Check if atClient is already initialized (from at_onboarding_flutter)
      if (_atClientManager?.atClient.getCurrentAtSign() != null) {
        _atClient = _atClientManager!.atClient;
        debugPrint('Using existing atClient for ${_atClient!.getCurrentAtSign()}');
      } else {
        // AtClient not initialized yet - this requires proper onboarding
        debugPrint('WARNING: AtClient not initialized. User needs to complete onboarding with at_onboarding_flutter');
        debugPrint('For demo purposes, setting up minimal client...');
        
        // For now, just store the atSign
        // In production, this should trigger proper at_onboarding_flutter flow
        _atClient = null;
      }

      // Start listening for notifications if client is ready
      if (_atClient != null) {
        _startNotificationListener();
        debugPrint('AtClientService initialized successfully');
      } else {
        debugPrint('AtClientService initialized in limited mode (no atClient available)');
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to initialize AtClientService: $e');
      debugPrint('StackTrace: $stackTrace');
      // Don't rethrow - allow app to continue in limited mode
    }
  }

  /// Set the agent's @sign
  void setAgentAtSign(String agentAtSign) {
    _agentAtSign = agentAtSign;
    debugPrint('Agent @sign set to: $agentAtSign');
  }

  /// Send a query message to the agent
  Future<void> sendQuery(ChatMessage message) async {
    if (_atClient == null) {
      throw Exception('AtClient not initialized. Call initialize() first.');
    }

    if (_agentAtSign == null || _agentAtSign!.isEmpty) {
      throw Exception('Agent @sign not set. Call setAgentAtSign() first.');
    }

    try {
      debugPrint('Sending query to $_agentAtSign');

      // Create the query data
      final queryData = {
        'id': message.id,
        'type': 'query',
        'content': message.content,
        'userId': _currentAtSign,
        'timestamp': message.timestamp.toIso8601String(),
      };

      // Send as notification to agent
      final jsonData = json.encode(queryData);

      final notificationResult = await _atClient!.notificationService.notify(
        NotificationParams.forText(jsonData, _agentAtSign!),
      );

      debugPrint(
        'Query sent successfully: ${notificationResult.notificationID}',
      );
    } catch (e, stackTrace) {
      debugPrint('Failed to send query: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Start listening for notifications from the agent
  void _startNotificationListener() {
    if (_atClient == null) return;

    debugPrint('Starting notification listener');

    _atClient!.notificationService
        .subscribe(regex: 'response.*', shouldDecrypt: true)
        .listen(
      (notification) {
        _handleNotification(notification);
      },
      onError: (error) {
        debugPrint('Notification listener error: $error');
      },
    );
  }

  /// Handle incoming notification from agent
  void _handleNotification(AtNotification notification) {
    try {
      debugPrint('Received notification: ${notification.key}');

      if (notification.value == null) {
        debugPrint('Notification value is null');
        return;
      }

      // Parse the response
      final responseData = json.decode(notification.value!);

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
      );

      // Emit the message to listeners
      _messageController.add(message);
      debugPrint('Agent response received and emitted');
    } catch (e, stackTrace) {
      debugPrint('Failed to handle notification: $e');
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
      return keys
          .where((key) => key.key != null)
          .map((key) => key.key!.replaceFirst('context.', ''))
          .toList();
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

  /// Cleanup resources
  void dispose() {
    _messageController.close();
  }
}
