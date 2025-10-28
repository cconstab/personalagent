import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import '../models/conversation.dart';

/// Service for managing conversations via atPlatform storage
///
/// Conversations are stored as atKeys with:
/// - Key format: conversations.{conversationId}.personalagent@currentAtSign
/// - TTL: 7 days (refreshed on each update)
/// - Self keys (not shared with anyone)
class ConversationStorageService {
  static const String _conversationKeyPrefix = 'conversations';
  static const String _namespace = 'personalagent';
  static const int _ttlDays = 7;
  // CRITICAL: at_commons Metadata.ttl is in MILLISECONDS
  // 7 days = 7 * 24 * 60 * 60 * 1000 = 604,800,000 milliseconds
  static const int _ttlMilliseconds = _ttlDays * 24 * 60 * 60 * 1000;

  AtClient? _atClient;

  /// Initialize the service with the current AtClient
  Future<void> initialize() async {
    // Wait for AtClient to be ready
    _atClient = AtClientManager.getInstance().atClient;

    if (_atClient == null) {
      // AtClient not ready yet, but will be initialized soon
      // This is not a fatal error - we'll check again when needed
      return;
    }
  }

  /// Save a conversation to atPlatform
  /// Creates/updates an atKey with 7-day TTL that refreshes on each save
  Future<void> saveConversation(Conversation conversation) async {
    if (_atClient == null) {
      return; // Silently return instead of throwing during initialization
    }

    // Check if AtClient is authenticated (has a current @sign)
    final currentAtSign = _atClient!.getCurrentAtSign();
    if (currentAtSign == null) {
      return; // Silently return instead of throwing during initialization
    }

    try {
      // Create the atKey for this conversation
      final key = AtKey()
        ..key = '$_conversationKeyPrefix.${conversation.id}'
        ..namespace = _namespace
        ..sharedWith = null // Self key (not shared)
        ..metadata = (Metadata()
          ..ttl = _ttlMilliseconds // 7 days in milliseconds
          ..ttr = -1
          ..ccd = false);

      // Serialize conversation to JSON
      final jsonData = jsonEncode(conversation.toJson());

      // Save to atPlatform - MUST push to remote server for cross-device sync
      await _atClient!.put(
        key,
        jsonData,
        putRequestOptions: PutRequestOptions()
          ..useRemoteAtServer = true, // Push to remote server for sync
      );
    } catch (e) {
      debugPrint('❌ Error saving conversation: $e');
      rethrow;
    }
  }

  /// Load all conversations from atPlatform
  /// Returns list of conversations sorted by updatedAt (most recent first)
  Future<List<Conversation>> loadConversations() async {
    if (_atClient == null) {
      debugPrint('⚠️ AtClient not ready, cannot load conversations yet');
      return []; // Return empty list instead of throwing
    }

    try {
      final currentAtSign = _atClient!.getCurrentAtSign();
      if (currentAtSign == null) {
        debugPrint('⚠️ No current @sign set, cannot load conversations');
        return [];
      }
      final conversations = <Conversation>[];

      // Get all keys matching our conversation pattern
      final regex = '$_conversationKeyPrefix\\..*\\.$_namespace$currentAtSign';

      debugPrint('🔍 Loading conversations from atPlatform...');
      debugPrint('   Current @sign: $currentAtSign');
      debugPrint('   Regex pattern: $regex');

      // getAtKeys fetches from local storage
      // We use useRemoteAtServer=true on put/get to ensure data is on remote
      final keys = await _atClient!.getAtKeys(regex: regex);

      debugPrint('💾 Found ${keys.length} conversation keys');

      if (keys.isEmpty) {
        debugPrint('⚠️ No conversation keys found in atPlatform');
        debugPrint('   This could mean:');
        debugPrint('   1. First time running app (no conversations yet)');
        debugPrint('   2. Conversations not saved with useRemoteAtServer=true');
        debugPrint('   3. Different @sign than before');
      }

      // Load each conversation directly from atPlatform
      // getAtKeys returns keys that exist, get() fetches their values
      for (final keyString in keys) {
        try {
          // keyString is already an AtKey
          final result = await _atClient!.get(keyString);

          if (result.value != null) {
            final jsonData = jsonDecode(result.value);
            final conversation = Conversation.fromJson(jsonData);
            conversations.add(conversation);

            debugPrint(
                '   ✓ Loaded: ${conversation.title} (${conversation.messages.length} msgs)');
          } else {
            debugPrint('   ⚠️ Key exists but value is null: $keyString');
          }
        } catch (e) {
          debugPrint('   ✗ Error loading conversation $keyString: $e');
          // Continue loading other conversations
        }
      }

      // Sort by updatedAt (most recent first)
      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      debugPrint(
          '💾 Successfully loaded ${conversations.length} conversations');
      return conversations;
    } catch (e) {
      debugPrint('❌ Error loading conversations: $e');
      return []; // Return empty list on error
    }
  }

  /// Delete a conversation from atPlatform
  /// Removes the atKey permanently
  Future<void> deleteConversation(String conversationId) async {
    if (_atClient == null) {
      debugPrint('⚠️ AtClient not ready, cannot delete conversation yet');
      return; // Silently return instead of throwing during initialization
    }

    // Check if AtClient is authenticated (has a current @sign)
    final currentAtSign = _atClient!.getCurrentAtSign();
    if (currentAtSign == null) {
      debugPrint(
          '⚠️ AtClient not authenticated yet, cannot delete conversation');
      return; // Silently return instead of throwing during initialization
    }

    try {
      // Create the atKey to delete - must match exactly how it was saved
      final key = AtKey()
        ..key = '$_conversationKeyPrefix.$conversationId'
        ..namespace = _namespace
        ..sharedWith = null;

      debugPrint('🗑️ Attempting to delete conversation...');
      debugPrint('   Conversation ID: $conversationId');
      debugPrint(
          '   AtKey: $_conversationKeyPrefix.$conversationId.$_namespace$currentAtSign');
      debugPrint('   Using remote server: true');

      // Delete from atPlatform - MUST push to remote server
      final deleteResult = await _atClient!.delete(
        key,
        deleteRequestOptions: DeleteRequestOptions()
          ..useRemoteAtServer = true, // Critical: Delete from remote server
      );

      debugPrint('🗑️ Deleted conversation $conversationId from atPlatform');
      debugPrint('   Local delete: ${deleteResult ? "success" : "failed"}');

      // Important: The delete() call with useRemoteAtServer=true already
      // queues the deletion for sync. The sync happens automatically in background.
      // We just need to wait a moment for it to complete.

      debugPrint('   ⏳ Waiting for remote sync to complete...');
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('   ✅ Delete operation complete (syncing in background)');

      // Verify deletion by trying to get the key
      // Note: May still show in local cache briefly after delete
      try {
        final verifyResult = await _atClient!.get(key);
        if (verifyResult.value == null) {
          debugPrint('   ✅ Verified: Key no longer exists');
        } else {
          debugPrint('   ℹ️ Note: Key still in local cache (will be synced)');
          debugPrint('      This is normal - deletion syncs in background');
        }
      } catch (e) {
        // Expected - key should not exist
        debugPrint('   ✅ Verified: Key not found (expected)');
      }
    } catch (e) {
      debugPrint('❌ Error deleting conversation: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Load a specific conversation by ID
  Future<Conversation?> loadConversation(String conversationId) async {
    if (_atClient == null) {
      throw Exception('ConversationStorageService not initialized');
    }

    try {
      final key = AtKey()
        ..key = '$_conversationKeyPrefix.$conversationId'
        ..namespace = _namespace
        ..sharedWith = null;

      final result = await _atClient!.get(key);

      if (result.value != null) {
        final jsonData = jsonDecode(result.value);
        return Conversation.fromJson(jsonData);
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error loading conversation $conversationId: $e');
      return null;
    }
  }

  /// Get the current atSign
  String? getCurrentAtSign() {
    return _atClient?.getCurrentAtSign();
  }

  /// Check if the service is initialized
  bool get isInitialized => _atClient != null;

  /// Debug method: List all atKeys to diagnose storage issues
  Future<void> debugListAllKeys() async {
    if (_atClient == null) {
      debugPrint('❌ AtClient not initialized');
      return;
    }

    try {
      final currentAtSign = _atClient!.getCurrentAtSign();
      debugPrint(
          '🔍 DEBUG: Listing all keys in personalagent namespace for $currentAtSign');

      // Get all keys in the personalagent namespace
      final regex = '.*\\.$_namespace$currentAtSign';
      final namespaceKeys = await _atClient!.getAtKeys(regex: regex);
      debugPrint(
          '   Total keys in personalagent namespace: ${namespaceKeys.length}');

      if (namespaceKeys.isNotEmpty) {
        debugPrint('   All personalagent keys:');
        for (final key in namespaceKeys) {
          debugPrint('   - $key');
        }
      } else {
        debugPrint('   No keys found in personalagent namespace');
      }
    } catch (e) {
      debugPrint('❌ Error listing keys: $e');
    }
  }
}
