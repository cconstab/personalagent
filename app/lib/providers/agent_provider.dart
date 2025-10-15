import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../services/at_client_service.dart';

/// Agent state provider
class AgentProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isProcessing = false;
  String? _agentAtSign;
  bool _useOllamaOnly = false;
  final AtClientService _atClientService = AtClientService();

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isProcessing => _isProcessing;
  String? get agentAtSign => _agentAtSign;
  bool get useOllamaOnly => _useOllamaOnly;

  AgentProvider() {
    _loadSettings();

    // Listen for incoming messages from agent
    _atClientService.messageStream.listen((message) {
      _messages.add(message);
      _isProcessing = false;
      notifyListeners();
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _useOllamaOnly = prefs.getBool('useOllamaOnly') ?? false;
    notifyListeners();
  }

  void setAgentAtSign(String atSign) {
    _agentAtSign = atSign;
    _atClientService.setAgentAtSign(atSign);
    notifyListeners();
  }

  Future<void> setUseOllamaOnly(bool value) async {
    _useOllamaOnly = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useOllamaOnly', value);
    notifyListeners();

    debugPrint('🔧 Ollama-only mode: ${value ? "ENABLED" : "DISABLED"}');
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    debugPrint('📤 Attempting to send message...');
    debugPrint('   AtClient initialized: ${_atClientService.isInitialized}');
    debugPrint('   Agent @sign: $_agentAtSign');

    // Check if AtClient is initialized
    if (!_atClientService.isInitialized) {
      debugPrint('❌ AtClient not initialized!');
      final errorMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: 'Error: Not connected to atPlatform. Please restart the app.',
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      );
      _messages.add(errorMessage);
      notifyListeners();
      return;
    }

    // Check if agent @sign is configured
    if (_agentAtSign == null) {
      debugPrint('❌ Agent @sign not configured!');
      final errorMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content:
            'Error: Agent @sign not configured. Please set it in Settings.',
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      );
      _messages.add(errorMessage);
      notifyListeners();
      return;
    }

    debugPrint('✅ All checks passed, sending message to $_agentAtSign');

    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    _isProcessing = true;
    notifyListeners();

    try {
      // Send message to agent via atPlatform with privacy setting
      await _atClientService.sendQuery(userMessage,
          useOllamaOnly: _useOllamaOnly);

      // Response will be received via messageStream listener
      // and added to messages automatically
    } catch (e) {
      final errorMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: 'Error: ${e.toString()}',
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      );

      _messages.add(errorMessage);
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    debugPrint('🧹 Clearing ${_messages.length} messages');
    _messages.clear();
    _isProcessing = false;
    notifyListeners();
  }
}
