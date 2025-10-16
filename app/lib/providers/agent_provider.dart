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

    // Listen for incoming messages from agent (including streaming updates)
    _atClientService.messageStream.listen((message) async {
      // Find which conversation this response belongs to using the message ID
      final conversationId = _queryToConversationMap[message.id];

      if (conversationId != null) {
        // Find the conversation
        final conversation = _conversations.firstWhere(
          (c) => c.id == conversationId,
          orElse: () => _conversations.first, // Fallback to first conversation
        );

        // Check if this is a streaming update (partial message)
        if (message.isPartial) {
          // Find existing AGENT message (not user message) with this ID and update it
          final existingIndex = conversation.messages
              .indexWhere((m) => m.id == message.id && !m.isUser);

          debugPrint(
              '📥 Received partial message ${message.id} (chunk ${message.chunkIndex})');
          debugPrint('   Content length: ${message.content.length}');
          debugPrint(
              '   Content preview: ${message.content.length > 50 ? message.content.substring(0, 50) : message.content}');
          debugPrint('   Looking for existing message with ID: ${message.id}');
          debugPrint('   Found at index: $existingIndex');
          debugPrint(
              '   Message IDs in conversation: ${conversation.messages.map((m) => m.id).toList()}');

          if (existingIndex != -1) {
            // Update existing message with new content
            final oldContent = conversation.messages[existingIndex].content;
            conversation.messages[existingIndex] = message;
            debugPrint(
                '🔄 Updated streaming message ${message.id} (chunk ${message.chunkIndex})');
            debugPrint(
                '   Old content length: ${oldContent.length}, New: ${message.content.length}');
          } else {
            // First chunk - replace thinking placeholder and add actual message
            final thinkingPlaceholderId = '${message.id}_thinking';
            final thinkingIndex = conversation.messages
                .indexWhere((m) => m.id == thinkingPlaceholderId);

            debugPrint(
                '🔍 Looking for thinking placeholder: $thinkingPlaceholderId');
            debugPrint('   Found at index: $thinkingIndex');
            debugPrint(
                '   Message IDs in conversation: ${conversation.messages.map((m) => m.id).toList()}');

            if (thinkingIndex != -1) {
              // Replace thinking placeholder with first chunk
              conversation.messages[thinkingIndex] = message;
              debugPrint(
                  '🔄 Replaced thinking placeholder with first chunk for ${message.id}');
              debugPrint(
                  '   New message ID at index $thinkingIndex: ${conversation.messages[thinkingIndex].id}');
            } else {
              // No placeholder found, just add
              conversation.messages.add(message);
              debugPrint(
                  '➕ Added first streaming chunk for ${message.id} (no placeholder found)');
            }
          }

          // Don't save to atPlatform yet (wait for final message)
          // Just notify UI to update
          notifyListeners();
        } else {
          // This is the final complete message
          debugPrint('📬 Received FINAL message ${message.id}');
          debugPrint(
              '   Message IDs before processing: ${conversation.messages.map((m) => m.id).toList()}');

          // Search for existing AGENT message (not user message) with this ID
          final existingIndex = conversation.messages
              .indexWhere((m) => m.id == message.id && !m.isUser);

          debugPrint(
              '   Looking for existing AGENT message with ID ${message.id}: index = $existingIndex');

          if (existingIndex != -1) {
            // Replace streaming message with final version
            conversation.messages[existingIndex] = message;
            debugPrint(
                '✅ Finalized streaming message ${message.id} at index $existingIndex');
          } else {
            // Check if there's a thinking placeholder to replace
            final thinkingPlaceholderId = '${message.id}_thinking';
            final thinkingIndex = conversation.messages
                .indexWhere((m) => m.id == thinkingPlaceholderId);

            debugPrint(
                '   Looking for thinking placeholder $thinkingPlaceholderId: index = $thinkingIndex');

            if (thinkingIndex != -1) {
              // Replace thinking placeholder with final message
              conversation.messages[thinkingIndex] = message;
              debugPrint(
                  '✅ Replaced thinking placeholder with final message ${message.id} at index $thinkingIndex');
            } else {
              // No streaming or placeholder, just add the complete message
              conversation.messages.add(message);
              debugPrint(
                  '✅ Added complete message ${message.id} (no placeholder or existing message found!)');
            }
          }

          debugPrint(
              '   Message IDs after processing: ${conversation.messages.map((m) => m.id).toList()}');

          conversation.updatedAt = DateTime.now(); // Refreshes TTL
          conversation.autoUpdateTitle();
          await _saveConversation(
              conversation); // Save to atPlatform with refreshed TTL

          // Clean up the mapping only after final message
          _queryToConversationMap.remove(message.id);

          _isProcessing = false;
        }

        debugPrint(
            '📝 Updated conversation: ${conversation.id} (${conversation.title})');
      } else {
        // No mapping found - this is a routing error!
        // DO NOT add to current conversation as it may have changed
        debugPrint(
            '⚠️ WARNING: No conversation mapping found for message ${message.id}');
        debugPrint(
            '   This message will be dropped to prevent cross-contamination');
        debugPrint(
            '   Message content preview: ${message.content.length > 50 ? message.content.substring(0, 50) : message.content}...');

        // Optionally: Search all conversations to find where this message belongs
        // Look for either the message itself OR the thinking placeholder
        final thinkingPlaceholderId = '${message.id}_thinking';
        Conversation? targetConversation;
        try {
          targetConversation = _conversations.firstWhere(
            (c) => c.messages.any(
                (m) => m.id == message.id || m.id == thinkingPlaceholderId),
          );
        } catch (e) {
          // No conversation has this message or placeholder
          targetConversation = null;
        }

        if (targetConversation != null) {
          debugPrint(
              '   ✅ Found message in conversation: ${targetConversation.id}');
          if (message.isPartial) {
            // Handle streaming in found conversation
            // Search for existing AGENT message (not user message)
            final existingIndex = targetConversation.messages
                .indexWhere((m) => m.id == message.id && !m.isUser);
            if (existingIndex != -1) {
              targetConversation.messages[existingIndex] = message;
              debugPrint('🔄 Updated streaming message in fallback path');
            } else {
              // Check for thinking placeholder
              final thinkingIndex = targetConversation.messages
                  .indexWhere((m) => m.id == thinkingPlaceholderId);
              if (thinkingIndex != -1) {
                targetConversation.messages[thinkingIndex] = message;
                debugPrint('🔄 Replaced thinking placeholder in fallback path');
              } else {
                targetConversation.messages.add(message);
                debugPrint('➕ Added new streaming message in fallback path');
              }
            }
            notifyListeners();
          } else {
            // Final message
            // Search for existing AGENT message (not user message)
            final existingIndex = targetConversation.messages
                .indexWhere((m) => m.id == message.id && !m.isUser);
            if (existingIndex != -1) {
              targetConversation.messages[existingIndex] = message;
              debugPrint('✅ Updated final message in fallback path');
            } else {
              // Check for thinking placeholder
              final thinkingIndex = targetConversation.messages
                  .indexWhere((m) => m.id == thinkingPlaceholderId);
              if (thinkingIndex != -1) {
                targetConversation.messages[thinkingIndex] = message;
                debugPrint(
                    '✅ Replaced thinking placeholder with final message in fallback path');
              } else {
                targetConversation.messages.add(message);
                debugPrint(
                    '➕ Added new final message in fallback path (should not happen!)');
              }
            }
            targetConversation.updatedAt = DateTime.now();
            targetConversation.autoUpdateTitle();
            await _saveConversation(targetConversation);
            _isProcessing = false;
          }
        } else {
          debugPrint('   ❌ Message dropped - no valid conversation found');
        }
      }

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

    // Add "Thinking..." placeholder message with unique ID
    // The agent's response will have userMessage.id, which we'll use to find and replace this
    final thinkingPlaceholderId = '${userMessage.id}_thinking';
    final thinkingMessage = ChatMessage(
      id: thinkingPlaceholderId,
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
      isPartial: true, // Mark as partial to show streaming indicator
      agentName: 'Agent',
    );
    currentConversation!.messages.add(thinkingMessage);
    debugPrint(
        '💭 Added thinking placeholder $thinkingPlaceholderId for query ${userMessage.id}');
    currentConversation!.updatedAt = DateTime.now(); // Refreshes TTL
    currentConversation!.autoUpdateTitle();
    _isProcessing = true;
    await _saveConversation(
        currentConversation!); // Save to atPlatform with refreshed TTL
    notifyListeners();

    try {
      // Get conversation history (all messages except the current user message and thinking placeholder)
      final messages = currentConversation!.messages;
      // Exclude last 2 messages: the user message we just added and the thinking placeholder
      final conversationHistory = messages.length > 2
          ? messages.sublist(0, messages.length - 2)
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
