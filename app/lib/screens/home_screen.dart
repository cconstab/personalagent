import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/agent_provider.dart';
import '../providers/auth_provider.dart';
import '../services/at_client_service.dart' as app_service;
import '../widgets/chat_bubble.dart';
import '../widgets/input_field.dart';
import 'settings_screen.dart';
import 'conversations_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _initializeAtClient();
  }

  Future<void> _initializeAtClient() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      final authProvider = context.read<AuthProvider>();
      final agentProvider = context.read<AgentProvider>();

      if (authProvider.atSign != null) {
        debugPrint('🔄 Initializing AtClient for ${authProvider.atSign}');

        // Note: Don't clear messages here - causes setState during build
        // Messages will be loaded from atPlatform anyway

        // Use the SDK's onboarding to authenticate with keychain keys
        await _authenticateWithKeychain(authProvider.atSign!);

        final atClientService = app_service.AtClientService();
        await atClientService.initialize(authProvider.atSign!);

        // Set agent @sign if not already set
        if (agentProvider.agentAtSign == null) {
          agentProvider.setAgentAtSign('@llama');
        }

        debugPrint('✅ AtClient initialized successfully');

        // Now that AtClient is ready, reload conversations from atPlatform
        debugPrint('🔄 Reloading conversations now that AtClient is ready...');
        await agentProvider.reloadConversations();
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize AtClient: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _authenticateWithKeychain(String atSign) async {
    debugPrint('🔐 Authenticating with keychain for $atSign');

    final atClientPreference = AtClientPreference()
      ..rootDomain = 'root.atsign.org'
      ..namespace = 'personalagent'
      ..hiveStoragePath = (await getApplicationSupportDirectory()).path
      ..commitLogPath = (await getApplicationSupportDirectory()).path
      ..isLocalStoreRequired = true;

    // Check if we need to switch @signs (like NoPorts does)
    try {
      final currentAtSign =
          AtClientManager.getInstance().atClient.getCurrentAtSign();
      if (currentAtSign != null && currentAtSign != atSign) {
        debugPrint('🔄 Switching from $currentAtSign to $atSign');
        // Tell SDK to switch primary @sign
        bool switched = await AtOnboarding.changePrimaryAtsign(atsign: atSign);
        if (!switched) {
          throw Exception('Failed to switch from $currentAtSign to $atSign');
        }
        debugPrint('✅ Primary @sign switched');
      }
    } catch (e) {
      // AtClientManager not initialized yet - that's fine, first login
      debugPrint('No existing AtClient to switch from (first login)');
    }

    // CRITICAL: Pass the atsign parameter to force authentication with specific @sign
    // Without this, SDK will use whatever @sign is already initialized
    final result = await AtOnboarding.onboard(
      context: context,
      atsign: atSign, // Force authentication with this specific @sign
      config: AtOnboardingConfig(
        atClientPreference: atClientPreference,
        rootEnvironment: RootEnvironment.Production,
        domain: 'root.atsign.org',
        appAPIKey: 'personalagent',
      ),
    );

    if (result.status != AtOnboardingResultStatus.success) {
      throw Exception('Authentication failed: ${result.message}');
    }

    debugPrint(
        '✅ Authenticated successfully with keychain as ${result.atsign}');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    context.read<AgentProvider>().sendMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  void _showDeleteCurrentConversationDialog(
      BuildContext context, AgentProvider agent) {
    final conversation = agent.currentConversation;
    if (conversation == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text(
          'Are you sure you want to delete "${conversation.title}"?\n\nThis will permanently delete it from all your devices.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await agent.deleteConversation(conversation.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Conversation deleted'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer2<AuthProvider, AgentProvider>(
          builder: (context, auth, agent, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  auth.atSign ?? 'Private AI Agent',
                  style: const TextStyle(fontSize: 16),
                ),
                if (agent.agentAtSign != null)
                  Text(
                    '→ ${agent.agentAtSign}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          // Conversations list button
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Conversations',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ConversationsScreen()),
              );
            },
          ),
          // New conversation button
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Conversation',
            onPressed: () {
              context.read<AgentProvider>().createNewConversation();
            },
          ),
          // Delete current conversation button
          Consumer<AgentProvider>(
            builder: (context, agent, _) {
              // Only show if there's a current conversation
              if (agent.currentConversation == null) {
                return const SizedBox.shrink();
              }

              return IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete Conversation',
                onPressed: () {
                  _showDeleteCurrentConversationDialog(context, agent);
                },
              );
            },
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<AgentProvider>(
              builder: (context, agent, _) {
                if (agent.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ask me anything. I\'ll keep your data private.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.3),
                                  ),
                        ),
                      ],
                    ),
                  );
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: agent.messages.length,
                  itemBuilder: (context, index) {
                    final message = agent.messages[index];
                    return ChatBubble(message: message);
                  },
                );
              },
            ),
          ),
          Consumer<AgentProvider>(
            builder: (context, agent, _) {
              if (agent.isProcessing) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Agent is thinking...',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          InputField(controller: _textController, onSend: _sendMessage),
        ],
      ),
    );
  }
}
