import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/agent_provider.dart';
import 'context_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _useOllamaOnly = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // TODO: Load from SharedPreferences
    setState(() {
      _useOllamaOnly = false;
    });
  }

  Future<void> _saveSettings() async {
    // TODO: Save to SharedPreferences
  }

  void _showAgentAtSignDialog(BuildContext context) {
    final controller = TextEditingController(
      text: context.read<AgentProvider>().agentAtSign ?? '@llama',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configure Agent @sign'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the @sign of your agent backend:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Agent @sign',
                hintText: '@llama',
                prefixIcon: Icon(Icons.alternate_email),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Make sure your agent is running with this @sign.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final atSign = controller.text.trim();
              if (atSign.isNotEmpty) {
                // Add @ prefix if missing
                final formattedAtSign =
                    atSign.startsWith('@') ? atSign : '@$atSign';
                context.read<AgentProvider>().setAgentAtSign(formattedAtSign);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Agent @sign set to $formattedAtSign')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return ListTile(
                leading: const Icon(Icons.account_circle),
                title: const Text('Your @sign'),
                subtitle: Text(auth.atSign ?? 'Not signed in'),
              );
            },
          ),
          Consumer<AgentProvider>(
            builder: (context, agent, _) {
              return ListTile(
                leading: const Icon(Icons.smart_toy),
                title: const Text('Agent @sign'),
                subtitle: Text(agent.agentAtSign ?? 'Not configured'),
                trailing: const Icon(Icons.edit),
                onTap: () => _showAgentAtSignDialog(context),
              );
            },
          ),
          const Divider(),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Privacy Settings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.local_fire_department),
            title: const Text('Use Ollama Only'),
            subtitle: const Text('Never send queries to external services'),
            value: _useOllamaOnly,
            onChanged: (value) {
              setState(() {
                _useOllamaOnly = value;
              });
              _saveSettings();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    value
                        ? 'Ollama only mode enabled - 100% private'
                        : 'Hybrid mode enabled - uses Claude when needed',
                  ),
                ),
              );
            },
          ),
          const Divider(),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Data Management',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Manage Context'),
            subtitle: const Text('View and delete stored context data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContextManagementScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Clear Chat History'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Chat History'),
                  content: const Text(
                    'Are you sure you want to clear all chat history?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        context.read<AgentProvider>().clearMessages();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chat history cleared')),
                        );
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'About',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('0.1.0'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Open Source'),
            subtitle: const Text('View source code on GitHub'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final url =
                  Uri.parse('https://github.com/cconstab/personalagent');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open GitHub'),
                    ),
                  );
                }
              }
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FilledButton.tonal(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          context.read<AuthProvider>().signOut();
                          Navigator.pop(context);
                        },
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Sign Out'),
            ),
          ),
        ],
      ),
    );
  }
}
