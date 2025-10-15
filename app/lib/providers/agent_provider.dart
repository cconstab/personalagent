import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/at_client_service.dart';

/// Agent state provider
class AgentProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isProcessing = false;
  String? _agentAtSign;
  final AtClientService _atClientService = AtClientService();

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isProcessing => _isProcessing;
  String? get agentAtSign => _agentAtSign;

  AgentProvider() {
    // Listen for incoming messages from agent
    _atClientService.messageStream.listen((message) {
      _messages.add(message);
      _isProcessing = false;
      notifyListeners();
    });
  }

  void setAgentAtSign(String atSign) {
    _agentAtSign = atSign;
    _atClientService.setAgentAtSign(atSign);
    notifyListeners();
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
      // Send message to agent via atPlatform
      await _atClientService.sendQuery(userMessage);

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
    _messages.clear();
    notifyListeners();
  }
}
