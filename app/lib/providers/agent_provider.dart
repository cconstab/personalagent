import 'dart:async';
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

  /// Queue for messages that arrive before conversations are loaded
  final List<ChatMessage> _pendingMessages = [];
  bool _conversationsLoaded = false;

  /// Query timeout tracking
  final Map<String, Timer> _queryTimeouts = {};
  static const Duration _queryTimeout = Duration(seconds: 60);

  /// Safely notify listeners immediately
  void _safeNotifyListeners() {
    if (!hasListeners) return;
    notifyListeners();
  }

  /// Start a timeout for a query - shows error if no response received
  void _startQueryTimeout(String queryId, String conversationId) {
    // Cancel any existing timeout for this query
    _queryTimeouts[queryId]?.cancel();

    // Start new timeout
    _queryTimeouts[queryId] = Timer(_queryTimeout, () {
      debugPrint(
          '⏰ Query $queryId timed out after ${_queryTimeout.inSeconds}s');

      // Find the conversation
      final conversation =
          _conversations.where((c) => c.id == conversationId).firstOrNull;
      if (conversation == null) return;

      // Remove the thinking placeholder
      final thinkingPlaceholderId = '${queryId}_thinking';
      conversation.messages.removeWhere((m) => m.id == thinkingPlaceholderId);

      // Add timeout error message
      final errorMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content:
            'Request timed out. The agent may be offline or unresponsive. The app will automatically reconnect when an agent is available.',
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      );
      conversation.messages.add(errorMessage);

      // Clean up
      _queryTimeouts.remove(queryId);
      _queryToConversationMap.remove(queryId);
      _isProcessing = false;

      _safeNotifyListeners();
    });
  }

  /// Cancel query timeout when response is received
  void _cancelQueryTimeout(String queryId) {
    _queryTimeouts[queryId]?.cancel();
    _queryTimeouts.remove(queryId);
  }

  List<Conversation> get conversations => List.unmodifiable(_conversations);
  Conversation? get currentConversation =>
      _conversations.where((c) => c.id == _currentConversationId).firstOrNull;
  List<ChatMessage> get messages => currentConversation?.messages ?? [];
  bool get isProcessing => _isProcessing;
  String? get agentAtSign => _agentAtSign;
  bool get useOllamaOnly => _useOllamaOnly;
  AgentProvider() {
    _loadSettings();
    // DON'T load conversations here - AtClient not initialized yet!
    // Conversations will be loaded after onboarding via reloadConversations()

    // Listen for incoming messages from agent (including streaming updates)
    _atClientService.messageStream.listen(_handleIncomingMessage);
  }

  /// Handle incoming message from agent
  Future<void> _handleIncomingMessage(ChatMessage message) async {
    debugPrint('📨 Received message from agent: ${message.id}');
    debugPrint('   isPartial: ${message.isPartial}');
    debugPrint('   chunkIndex: ${message.chunkIndex}');
    debugPrint('   Conversations loaded: ${_conversations.length}');

    // Check if we have any conversations loaded
    if (_conversations.isEmpty && !_conversationsLoaded) {
      debugPrint(
          '⏳ Conversations not loaded yet - queueing message ${message.id}');
      _pendingMessages.add(message);
      return;
    }

    if (_conversations.isEmpty) {
      debugPrint(
          '⚠️ WARNING: No conversations exist! Creating default conversation...');
      await _createNewConversation();
    }

    // Try to find which conversation this response belongs to
    // First, check if the response includes conversationId (new stateless approach)
    String? conversationId = message.conversationId;

    if (conversationId != null) {
      debugPrint('✅ Using conversationId from response: $conversationId');
    } else {
      debugPrint('⚠️ No conversationId in response, checking fallback map...');
    }

    // Fallback: Check the in-memory map (for backwards compatibility with old agents)
    conversationId ??= _queryToConversationMap[message.id];

    if (conversationId == null) {
      debugPrint(
          '❌ No conversationId found in map either for message ${message.id}');
      debugPrint(
          '   Current map keys: ${_queryToConversationMap.keys.toList()}');
      debugPrint('🔍 Checking atPlatform for persisted mapping...');
      conversationId = await _atClientService.getQueryMapping(message.id);
      if (conversationId != null) {
        debugPrint(
            '✅ Found persisted mapping: ${message.id} -> $conversationId');
      }
    } else {
      debugPrint('📍 Found conversationId: $conversationId');
    }

    if (conversationId != null) {
      // Find the conversation
      Conversation? conversation;
      try {
        conversation = _conversations.firstWhere((c) => c.id == conversationId);
        debugPrint(
            '✅ Found conversation: ${conversation.id} (${conversation.title})');
      } catch (e) {
        debugPrint(
            '❌ Conversation $conversationId not found in loaded conversations!');
        debugPrint(
            '   Available conversations: ${_conversations.map((c) => c.id).toList()}');
        debugPrint('   This response will be dropped to prevent misrouting');
        return; // Don't add to wrong conversation
      }

      // Check if this is a streaming update (partial message)
      // Cancel the query timeout since we received ANY response (partial or final)
      _cancelQueryTimeout(message.id);

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
        _safeNotifyListeners();
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
          (c) => c.messages
              .any((m) => m.id == message.id || m.id == thinkingPlaceholderId),
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
          _safeNotifyListeners();
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

    _safeNotifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _useOllamaOnly = prefs.getBool('useOllamaOnly') ?? false;
    _safeNotifyListeners();
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

    // CRITICAL: Re-initialize storage service to pick up new AtClient after @sign switch
    // Without this, the service still points to the old @sign's AtClient
    await _storageService.initialize();

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
        await _createNewConversation();
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
        debugPrint('📌 Restored current conversation: $currentId');
      } else if (_conversations.isNotEmpty) {
        _currentConversationId = _conversations.first.id;
        debugPrint(
            '📌 Set current conversation to first: ${_currentConversationId}');
      } else {
        // Create first conversation
        await _createNewConversation();
        debugPrint('📌 Created new conversation: $_currentConversationId');
      }

      debugPrint(
          '📚 Loaded ${_conversations.length} conversations from atPlatform');
      debugPrint('📌 Current conversation ID: $_currentConversationId');
      debugPrint(
          '📌 Current conversation: ${currentConversation?.id} (${currentConversation?.messages.length} msgs)');

      // Mark conversations as loaded
      _conversationsLoaded = true;

      // Process any pending messages that arrived before conversations were loaded
      if (_pendingMessages.isNotEmpty) {
        debugPrint(
            '📬 Processing ${_pendingMessages.length} pending messages...');
        final messagesToProcess = List<ChatMessage>.from(_pendingMessages);
        _pendingMessages.clear();
        for (final message in messagesToProcess) {
          await _handleIncomingMessage(message);
        }
      }

      _safeNotifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading conversations: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
      // Create a default conversation on error
      await _createNewConversation();
      _safeNotifyListeners(); // Notify UI after creating default conversation
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
    _safeNotifyListeners();
  }

  Future<void> setUseOllamaOnly(bool value) async {
    _useOllamaOnly = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useOllamaOnly', value);
    _safeNotifyListeners();

    debugPrint('🔧 Ollama-only mode: ${value ? "ENABLED" : "DISABLED"}');
  }

  /// Create a new conversation and switch to it
  Future<void> createNewConversation() async {
    await _createNewConversation();
    _safeNotifyListeners();
  }

  Future<void> _createNewConversation() async {
    final newConversation = Conversation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'New Conversation',
    );
    _conversations.insert(0, newConversation);
    _currentConversationId = newConversation.id;
    debugPrint('💬 Created new conversation: ${newConversation.id}');

    // Try to save, but don't fail if AtClient not ready yet
    try {
      await _saveConversation(newConversation); // Save to atPlatform
    } catch (e) {
      debugPrint('⚠️ Could not save new conversation yet (will retry): $e');
      // Conversation is still created in memory, just not persisted yet
    }
  }

  /// Switch to a different conversation
  Future<void> switchConversation(String conversationId) async {
    if (_conversations.any((c) => c.id == conversationId)) {
      _currentConversationId = conversationId;
      // Save current conversation ID to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentConversationId', conversationId);
      _safeNotifyListeners();
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
          await _createNewConversation();
        }
      }

      _safeNotifyListeners();
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
    _safeNotifyListeners();
    debugPrint('✏️ Renamed conversation $conversationId to: $newTitle');
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    // Ensure we have a current conversation
    if (currentConversation == null) {
      await _createNewConversation();
    }

    debugPrint('📤 Attempting to send message...');
    debugPrint('   AtClient initialized: ${_atClientService.isInitialized}');
    debugPrint('   Agent atSign: $_agentAtSign');
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
      _safeNotifyListeners();
      return;
    }

    // Check if agent atSign is configured
    if (_agentAtSign == null) {
      debugPrint('❌ Agent atSign not configured!');
      final errorMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content:
            'Error: Agent atSign not configured. Please set it in Settings.',
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      );
      currentConversation!.messages.add(errorMessage);
      _safeNotifyListeners();
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
    _safeNotifyListeners();

    try {
      // Get conversation history (all messages except the current user message and thinking placeholder)
      final messages = currentConversation!.messages;
      // Exclude last 2 messages: the user message we just added and the thinking placeholder
      final conversationHistory = messages.length > 2
          ? messages.sublist(0, messages.length - 2)
          : <ChatMessage>[];

      debugPrint(
          '📝 Including ${conversationHistory.length} previous messages for context');

      // Send message to agent via atPlatform with conversation context and ID
      await _atClientService.sendQuery(
        userMessage,
        useOllamaOnly: _useOllamaOnly,
        conversationHistory: conversationHistory,
        conversationId:
            conversationIdForThisQuery, // Include conversation ID for stateless routing
      );

      // Persist the mapping to atPlatform as well (short TTL, helpful after restarts/sign switches)
      await _atClientService.saveQueryMapping(
        userMessage.id,
        conversationIdForThisQuery,
      );
      debugPrint('💾 Persisted query mapping to atPlatform');

      // Start timeout timer for this query
      _startQueryTimeout(userMessage.id, conversationIdForThisQuery);

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
      _safeNotifyListeners();
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
    _safeNotifyListeners();
  }
}
