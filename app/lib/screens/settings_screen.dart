import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/agent_provider.dart';
import 'context_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
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
                    content: Text('Agent @sign set to $formattedAtSign'),
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.only(
                      bottom: MediaQuery.of(context).size.height - 100,
                      left: 10,
                      right: 10,
                    ),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSwitchAtSignDialog() async {
    // Get list of @signs from keychain
    final atSigns = await KeychainUtil.getAtsignList() ?? [];

    if (!mounted) return;

    if (atSigns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No @signs found in keychain'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            left: 10,
            right: 10,
          ),
        ),
      );
      return;
    }

    final currentAtSign = context.read<AuthProvider>().atSign;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Switch @sign'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select an @sign to switch to:'),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                itemCount: atSigns.length,
                itemBuilder: (context, index) {
                  final atSign = atSigns[index];
                  final isCurrent = atSign == currentAtSign;
                  return ListTile(
                    leading: Icon(
                      Icons.account_circle,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(
                      atSign,
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: isCurrent ? const Text('Current') : null,
                    trailing: isCurrent
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: isCurrent
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                            _switchToAtSign(atSign);
                          },
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _switchToAtSign(String atSign) async {
    try {
      debugPrint('🔄 Switching to $atSign');

      final currentAtSign = context.read<AuthProvider>().atSign;
      if (currentAtSign == atSign) {
        debugPrint('Already using $atSign');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Already using $atSign'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height - 100,
                left: 10,
                right: 10,
              ),
            ),
          );
        }
        return;
      }

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switching to $atSign...'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 100,
              left: 10,
              right: 10,
            ),
          ),
        );
      }

      // Clear messages before switching
      if (mounted) {
        context.read<AgentProvider>().clearMessages();
      }

      // Use AtOnboarding.changePrimaryAtsign to switch (like NoPorts)
      debugPrint('Calling changePrimaryAtsign...');
      bool switched = await AtOnboarding.changePrimaryAtsign(atsign: atSign);
      if (!switched) {
        throw Exception('Failed to change primary @sign to $atSign');
      }

      // Now onboard with the new @sign
      final dir = await getApplicationSupportDirectory();
      final atClientPreference = AtClientPreference()
        ..rootDomain = 'root.atsign.org'
        ..namespace = 'personalagent'
        ..hiveStoragePath = dir.path
        ..commitLogPath = dir.path
        ..isLocalStoreRequired = true;

      if (mounted) {
        final result = await AtOnboarding.onboard(
          context: context,
          atsign: atSign,
          config: AtOnboardingConfig(
            atClientPreference: atClientPreference,
            rootEnvironment: RootEnvironment.Production,
            domain: 'root.atsign.org',
            appAPIKey: 'personalagent',
          ),
        );

        if (result.status == AtOnboardingResultStatus.success) {
          // Update auth provider
          await context.read<AuthProvider>().authenticate(atSign);

          // Success! Close settings and stay on home screen
          if (mounted) {
            Navigator.of(context).pop(); // Close settings
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Switched to $atSign'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height - 100,
                  left: 10,
                  right: 10,
                ),
              ),
            );
          }
        } else {
          throw Exception('Onboarding failed: ${result.message}');
        }
      }
    } catch (e) {
      debugPrint('Error switching @sign: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch @sign: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 100,
              left: 10,
              right: 10,
            ),
          ),
        );
      }
    }
  }

  Future<void> _showManageAtSignsDialog() async {
    // Get list of @signs from keychain
    final atSigns = await KeychainUtil.getAtsignList() ?? [];

    if (!mounted) return;

    if (atSigns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No @signs found in keychain'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            left: 10,
            right: 10,
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Manage @signs'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('@signs stored in your keychain:'),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                itemCount: atSigns.length,
                itemBuilder: (context, index) {
                  final atSign = atSigns[index];
                  final isCurrent =
                      atSign == this.context.read<AuthProvider>().atSign;
                  return ListTile(
                    leading: Icon(
                      Icons.account_circle,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(
                      atSign,
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: isCurrent ? const Text('Current') : null,
                    trailing: !isCurrent
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _confirmRemoveAtSign(atSign);
                            },
                            tooltip: 'Remove',
                          )
                        : null,
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveAtSign(String atSign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove @sign?'),
        content: Text(
          'Remove $atSign from the keychain?\n\nThis will delete the keys permanently. Make sure you have a backup of your .atKeys file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _removeAtSignFromKeychain(atSign);
    }
  }

  Future<void> _removeAtSignFromKeychain(String atSign) async {
    try {
      debugPrint('🗑️ Removing $atSign from keychain');

      if (Platform.isMacOS) {
        final result = await Process.run('security', [
          'delete-generic-password',
          '-a',
          atSign,
        ]);

        if (result.exitCode == 0) {
          debugPrint('✅ Removed $atSign from keychain');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$atSign removed from keychain'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height - 100,
                  left: 10,
                  right: 10,
                ),
              ),
            );
          }
        } else {
          throw Exception('Failed to remove from keychain: ${result.stderr}');
        }
      } else {
        throw Exception('Remove @sign not yet supported on this platform');
      }
    } catch (e) {
      debugPrint('Error removing @sign: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove @sign: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 100,
              left: 10,
              right: 10,
            ),
          ),
        );
      }
    }
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
                title: const Text('Current @sign'),
                subtitle: Text(auth.atSign ?? 'Not signed in'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showSwitchAtSignDialog(),
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
          Consumer<AgentProvider>(
            builder: (context, agent, _) {
              return SwitchListTile(
                secondary: const Icon(Icons.local_fire_department),
                title: const Text('Use Ollama Only'),
                subtitle: const Text('Never send queries to external services'),
                value: agent.useOllamaOnly,
                onChanged: (value) {
                  context.read<AgentProvider>().setUseOllamaOnly(value);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        value
                            ? 'Ollama only mode enabled - 100% private'
                            : 'Hybrid mode enabled - uses Claude when needed',
                      ),
                      behavior: SnackBarBehavior.floating,
                      margin: EdgeInsets.only(
                        bottom: MediaQuery.of(context).size.height - 100,
                        left: 10,
                        right: 10,
                      ),
                    ),
                  );
                },
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
            leading: const Icon(Icons.manage_accounts),
            title: const Text('Manage @signs'),
            subtitle: const Text('View and remove stored @signs'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showManageAtSignsDialog(),
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
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Debug: List atPlatform Keys'),
            subtitle: const Text('Show what conversations are stored'),
            onTap: () async {
              final agent = context.read<AgentProvider>();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Check console for debug output')),
              );
              await agent.debugListAllKeys();
            },
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
                        onPressed: () async {
                          // Clear messages before signing out
                          context.read<AgentProvider>().clearMessages();
                          await context.read<AuthProvider>().signOut();
                          if (context.mounted) {
                            // Pop all routes to return to the front screen (onboarding)
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          }
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
