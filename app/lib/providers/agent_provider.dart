import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../services/at_client_service.dart';
import '../services/conversation_storage_service.dart';

/// Agent state provider with multi-conversation support
/// Conversations are stored in atPlatform with 7-day TTL (auto-expires)
class AgentProvider extends ChangeNotifier {
  final List<Conversation> _conversations = [];
  String? _currentConversationId;
  bool _isProcessing = false;
  String? _agentAtSign;
  bool _useOllamaOnly = false;
  final AtClientService _atClientService = AtClientService();
  final ConversationStorageService _storageService =
      ConversationStorageService();

  /// Map of query message ID -> conversation ID to route responses correctly
  final Map<String, String> _queryToConversationMap = {};

  List<Conversation> get conversations => List.unmodifiable(_conversations);
  Conversation? get currentConversation =>
      _conversations.where((c) => c.id == _currentConversationId).firstOrNull;
  List<ChatMessage> get messages => currentConversation?.messages ?? [];
  bool get isProcessing => _isProcessing;
  String? get agentAtSign => _agentAtSign;
  bool get useOllamaOnly => _useOllamaOnly;

  AgentProvider() {
    _loadSettings();
    _loadConversations();

    // Listen for incoming messages from agent
    _atClientService.messageStream.listen((message) async {
      // Find which conversation this response belongs to using the message ID
      final conversationId = _queryToConversationMap[message.id];

      if (conversationId != null) {
        // Find the conversation
        final conversation = _conversations.firstWhere(
          (c) => c.id == conversationId,
          orElse: () => _conversations.first, // Fallback to first conversation
        );

        // Add message to the correct conversation
        conversation.messages.add(message);
        conversation.updatedAt = DateTime.now(); // Refreshes TTL
        conversation.autoUpdateTitle();
        await _saveConversation(
            conversation); // Save to atPlatform with refreshed TTL

        // Clean up the mapping
        _queryToConversationMap.remove(message.id);

        debugPrint(
            '✅ Response added to conversation: ${conversation.id} (${conversation.title})');
      } else {
        // Fallback: add to current conversation if no mapping found
        debugPrint(
            '⚠️ No conversation mapping found for message ${message.id}, adding to current conversation');
        if (currentConversation != null) {
          currentConversation!.messages.add(message);
          currentConversation!.updatedAt = DateTime.now();
          currentConversation!.autoUpdateTitle();
          await _saveConversation(currentConversation!);
        }
      }

      _isProcessing = false;
      notifyListeners();
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _useOllamaOnly = prefs.getBool('useOllamaOnly') ?? false;
    notifyListeners();
  }

  /// Initialize the conversation storage service
  Future<void> initializeStorage() async {
    try {
      await _storageService.initialize();
      debugPrint('✅ Conversation storage service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing conversation storage: $e');
    }
  }

  /// Reload conversations from atPlatform (useful for refreshing after app restart)
  Future<void> reloadConversations() async {
    debugPrint('🔄 Manually reloading conversations from atPlatform...');
    await _loadConversations();
  }

  /// Debug method: List all keys in atPlatform
  Future<void> debugListAllKeys() async {
    if (!_storageService.isInitialized) {
      await _storageService.initialize();
    }
    await _storageService.debugListAllKeys();
  }

  Future<void> _loadConversations() async {
    try {
      // Initialize storage service if not already done
      if (!_storageService.isInitialized) {
        await _storageService.initialize();
      }

      // If AtClient still not ready (during initial app startup), create default conversation
      // and we'll load from atPlatform later when AtClient is ready
      if (!_storageService.isInitialized) {
        debugPrint(
            '⏳ AtClient not ready yet, will load conversations after initialization');
        _createNewConversation();
        return;
      }

      // Load conversations from atPlatform
      final loadedConversations = await _storageService.loadConversations();

      _conversations.clear();
      _conversations.addAll(loadedConversations);

      // Load current conversation ID from SharedPreferences (lightweight setting)
      final prefs = await SharedPreferences.getInstance();
      final currentId = prefs.getString('currentConversationId');

      // Restore current conversation or create a new one
      if (currentId != null && _conversations.any((c) => c.id == currentId)) {
        _currentConversationId = currentId;
      } else if (_conversations.isNotEmpty) {
        _currentConversationId = _conversations.first.id;
      } else {
        // Create first conversation
        _createNewConversation();
      }

      debugPrint(
          '📚 Loaded ${_conversations.length} conversations from atPlatform');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading conversations: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
      // Create a default conversation on error
      _createNewConversation();
    }
  }

  Future<void> _saveConversation(Conversation conversation) async {
    try {
      // Ensure storage service is initialized before saving
      if (!_storageService.isInitialized) {
        debugPrint('⚠️ Storage not initialized, initializing now...');
        await _storageService.initialize();
      }

      // Save conversation to atPlatform (with 7-day TTL)
      await _storageService.saveConversation(conversation);

      // Save current conversation ID to SharedPreferences
      if (_currentConversationId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentConversationId', _currentConversationId!);
      }
    } catch (e) {
      debugPrint('❌ Error saving conversation: $e');
    }
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

  /// Create a new conversation and switch to it
  void createNewConversation() {
    _createNewConversation();
    notifyListeners();
  }

  void _createNewConversation() {
    final newConversation = Conversation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'New Conversation',
    );
    _conversations.insert(0, newConversation);
    _currentConversationId = newConversation.id;
    _saveConversation(newConversation); // Save to atPlatform
    debugPrint('💬 Created new conversation: ${newConversation.id}');
  }

  /// Switch to a different conversation
  Future<void> switchConversation(String conversationId) async {
    if (_conversations.any((c) => c.id == conversationId)) {
      _currentConversationId = conversationId;
      // Save current conversation ID to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentConversationId', conversationId);
      notifyListeners();
      debugPrint('🔄 Switched to conversation: $conversationId');
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      // Ensure storage service is initialized before deleting
      if (!_storageService.isInitialized) {
        debugPrint('⚠️ Storage not initialized, initializing now...');
        await _storageService.initialize();
      }

      // Delete from atPlatform (includes sync to remote)
      await _storageService.deleteConversation(conversationId);

      // Give a moment for the deletion to sync to remote
      // (delete operation includes background sync)
      await Future.delayed(const Duration(milliseconds: 600));

      // Remove from local list
      _conversations.removeWhere((c) => c.id == conversationId);

      // If we deleted the current conversation, switch to another or create new
      if (_currentConversationId == conversationId) {
        if (_conversations.isNotEmpty) {
          await switchConversation(_conversations.first.id);
        } else {
          _createNewConversation();
        }
      }

      notifyListeners();
      debugPrint('✅ Deleted conversation $conversationId completely');
    } catch (e) {
      debugPrint('❌ Error deleting conversation: $e');
    }
  }

  /// Rename a conversation
  Future<void> renameConversation(
      String conversationId, String newTitle) async {
    final conversation =
        _conversations.firstWhere((c) => c.id == conversationId);
    conversation.title = newTitle;
    conversation.updatedAt = DateTime.now(); // Refreshes TTL
    await _saveConversation(
        conversation); // Save to atPlatform with refreshed TTL
    notifyListeners();
    debugPrint('✏️ Renamed conversation $conversationId to: $newTitle');
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    // Ensure we have a current conversation
    if (currentConversation == null) {
      _createNewConversation();
    }

    debugPrint('📤 Attempting to send message...');
    debugPrint('   AtClient initialized: ${_atClientService.isInitialized}');
    debugPrint('   Agent @sign: $_agentAtSign');
    debugPrint('   Conversation: ${currentConversation!.id}');

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
      currentConversation!.messages.add(errorMessage);
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
      currentConversation!.messages.add(errorMessage);
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

    // Track which conversation this query belongs to
    final conversationIdForThisQuery = currentConversation!.id;
    _queryToConversationMap[userMessage.id] = conversationIdForThisQuery;
    debugPrint(
        '📍 Mapped query ${userMessage.id} → conversation $conversationIdForThisQuery');

    currentConversation!.messages.add(userMessage);
    currentConversation!.updatedAt = DateTime.now(); // Refreshes TTL
    currentConversation!.autoUpdateTitle();
    _isProcessing = true;
    await _saveConversation(
        currentConversation!); // Save to atPlatform with refreshed TTL
    notifyListeners();

    try {
      // Get conversation history (all messages except the current one)
      final messages = currentConversation!.messages;
      final conversationHistory = messages.length > 1
          ? messages.sublist(0, messages.length - 1)
          : <ChatMessage>[];

      debugPrint(
          '📝 Including ${conversationHistory.length} previous messages for context');

      // Send message to agent via atPlatform with conversation context
      await _atClientService.sendQuery(
        userMessage,
        useOllamaOnly: _useOllamaOnly,
        conversationHistory: conversationHistory,
      );

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

      currentConversation!.messages.add(errorMessage);
    } finally {
      _isProcessing = false;
      await _saveConversation(
          currentConversation!); // Save response to atPlatform
      notifyListeners();
    }
  }

  Future<void> clearMessages() async {
    if (currentConversation != null) {
      debugPrint(
          '🧹 Clearing ${currentConversation!.messages.length} messages from current conversation');
      currentConversation!.messages.clear();
      currentConversation!.title = 'New Conversation';
      currentConversation!.updatedAt = DateTime.now(); // Refreshes TTL
      await _saveConversation(currentConversation!); // Save to atPlatform
    }
    _isProcessing = false;
    notifyListeners();
  }
}
