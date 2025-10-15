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

        // Use the SDK's onboarding to authenticate with keychain keys
        await _authenticateWithKeychain(authProvider.atSign!);

        final atClientService = app_service.AtClientService();
        await atClientService.initialize(authProvider.atSign!);

        // Set agent @sign if not already set
        if (agentProvider.agentAtSign == null) {
          agentProvider.setAgentAtSign('@llama');
        }

        debugPrint('✅ AtClient initialized successfully');
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

    // Use the onboarding service to authenticate with keychain
    final result = await AtOnboarding.onboard(
      context: context,
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

    debugPrint('✅ Authenticated successfully with keychain');
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
