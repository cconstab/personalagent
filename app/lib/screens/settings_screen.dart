import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/agent_provider.dart';
import '../providers/settings_provider.dart';
import 'context_management_screen.dart';
import 'debug_atkeys_screen.dart';

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

  // Helper method to show a banner at the top using MaterialBanner instead of SnackBar
  // This avoids layout conflicts and positioning issues
  void _showTopSnackBar(BuildContext context, String message, {Color? backgroundColor}) {
    // Clear any existing banners first
    ScaffoldMessenger.of(context).clearMaterialBanners();

    // Determine colors based on background
    final bgColor = backgroundColor ?? Theme.of(context).colorScheme.inverseSurface;
    final textColor =
        backgroundColor == Colors.red || backgroundColor == Colors.green || backgroundColor == Colors.orange
            ? Colors.white
            : Theme.of(context).colorScheme.onInverseSurface;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.showMaterialBanner(
      MaterialBanner(
        content: Text(
          message,
          style: TextStyle(color: textColor),
        ),
        backgroundColor: bgColor,
        leading: Icon(
          backgroundColor == Colors.red
              ? Icons.error_outline
              : backgroundColor == Colors.green
                  ? Icons.check_circle_outline
                  : backgroundColor == Colors.orange
                      ? Icons.info_outline
                      : Icons.info_outline,
          color: textColor,
        ),
        actions: [
          TextButton(
            onPressed: () {
              scaffoldMessenger.hideCurrentMaterialBanner();
            },
            child: Text('Dismiss', style: TextStyle(color: textColor)),
          ),
        ],
      ),
    );

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      scaffoldMessenger.hideCurrentMaterialBanner();
    });
  }

  void _showFontFamilyDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Font Family'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: SettingsProvider.availableFonts.length,
            itemBuilder: (context, index) {
              final fontFamily = SettingsProvider.availableFonts[index];
              final isSelected = fontFamily == settings.fontFamily;

              // Get the appropriate TextStyle for preview
              TextStyle? previewStyle;
              if (fontFamily != 'System Default') {
                try {
                  switch (fontFamily) {
                    case 'Roboto':
                      previewStyle = GoogleFonts.roboto();
                      break;
                    case 'Open Sans':
                      previewStyle = GoogleFonts.openSans();
                      break;
                    case 'Lato':
                      previewStyle = GoogleFonts.lato();
                      break;
                    case 'Montserrat':
                      previewStyle = GoogleFonts.montserrat();
                      break;
                    case 'Poppins':
                      previewStyle = GoogleFonts.poppins();
                      break;
                    case 'Raleway':
                      previewStyle = GoogleFonts.raleway();
                      break;
                    case 'Source Sans Pro':
                      previewStyle = GoogleFonts.sourceSans3();
                      break;
                    case 'Ubuntu':
                      previewStyle = GoogleFonts.ubuntu();
                      break;
                    case 'Fira Sans':
                      previewStyle = GoogleFonts.firaSans();
                      break;
                  }
                } catch (e) {
                  // If Google Fonts fails, use default
                  previewStyle = null;
                }
              }

              return ListTile(
                title: Text(
                  fontFamily,
                  style: (previewStyle ?? const TextStyle()).copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  'The quick brown fox jumps',
                  style: previewStyle?.copyWith(fontSize: 12),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  settings.setFontFamily(fontFamily);
                  Navigator.pop(dialogContext);
                },
              );
            },
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

  void _showAgentAtSignDialog(BuildContext context) {
    final controller = TextEditingController(
      text: context.read<AgentProvider>().agentAtSign ?? '@llama',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configure Agent atSign'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the atSign of your agent backend:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Agent atSign',
                hintText: '@llama',
                prefixIcon: Icon(Icons.alternate_email),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Make sure your agent is running with this atSign.',
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
            onPressed: () async {
              final atSign = controller.text.trim();
              if (atSign.isNotEmpty) {
                // Add @ prefix if missing
                final formattedAtSign = atSign.startsWith('@') ? atSign : '@$atSign';

                // Save to atPlatform via AuthProvider
                try {
                  await context.read<AuthProvider>().saveAgentAtSign(formattedAtSign);
                  context.read<AgentProvider>().setAgentAtSign(formattedAtSign);

                  if (context.mounted) {
                    Navigator.pop(context);
                    _showTopSnackBar(context, 'Agent atSign set to $formattedAtSign');
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showTopSnackBar(
                      context,
                      'Failed to save agent atSign: $e',
                      backgroundColor: Colors.red,
                    );
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSwitchAtSignDialog() async {
    // Get list of atSigns from keychain
    final atSigns = await KeychainUtil.getAtsignList() ?? [];

    if (!mounted) return;

    if (atSigns.isEmpty) {
      _showTopSnackBar(context, 'No atSigns found in keychain');
      return;
    }

    final currentAtSign = context.read<AuthProvider>().atSign;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Switch atSign'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select an atSign to switch to:'),
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
                      color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                    ),
                    title: Text(
                      atSign,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
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
          _showTopSnackBar(
            context,
            'Already using $atSign',
            backgroundColor: Colors.orange,
          );
        }
        return;
      }

      // Show loading
      if (mounted) {
        _showTopSnackBar(context, 'Switching to $atSign...');
      }

      // NOTE: We do NOT call clearMessages() here because it would save an empty
      // conversation to atPlatform, destroying the conversation data!
      // The conversations will be reloaded for the new atSign automatically.

      // Use AtOnboarding.changePrimaryAtsign to switch (like NoPorts)
      debugPrint('Calling changePrimaryAtsign...');
      bool switched = await AtOnboarding.changePrimaryAtsign(atsign: atSign);
      if (!switched) {
        throw Exception('Failed to change primary atSign to $atSign');
      }

      // Now onboard with the new atSign
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

          // CRITICAL: Reload conversations for the new atSign
          // Without this, the UI shows empty even though conversations exist
          if (mounted) {
            await context.read<AgentProvider>().reloadConversations();
          }

          // Success! Close settings and stay on home screen
          if (mounted) {
            Navigator.of(context).pop(); // Close settings
            _showTopSnackBar(
              context,
              '✅ Switched to $atSign',
              backgroundColor: Colors.green,
            );
          }
        } else {
          throw Exception('Onboarding failed: ${result.message}');
        }
      }
    } catch (e) {
      debugPrint('Error switching atSign: $e');
      if (mounted) {
        _showTopSnackBar(
          context,
          'Failed to switch atSign: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _showManageAtSignsDialog() async {
    // Get list of atSigns from keychain
    final atSigns = await KeychainUtil.getAtsignList() ?? [];

    if (!mounted) return;

    if (atSigns.isEmpty) {
      _showTopSnackBar(context, 'No atSigns found in keychain');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Manage atSigns'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('atSigns stored in your keychain:'),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                itemCount: atSigns.length,
                itemBuilder: (context, index) {
                  final atSign = atSigns[index];
                  final isCurrent = atSign == this.context.read<AuthProvider>().atSign;
                  return ListTile(
                    leading: Icon(
                      Icons.account_circle,
                      color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                    ),
                    title: Text(
                      atSign,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
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
        title: const Text('Remove atSign?'),
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
            _showTopSnackBar(
              context,
              '$atSign removed from keychain',
              backgroundColor: Colors.green,
            );
          }
        } else {
          throw Exception('Failed to remove from keychain: ${result.stderr}');
        }
      } else {
        throw Exception('Remove atSign not yet supported on this platform');
      }
    } catch (e) {
      debugPrint('Error removing atSign: $e');
      if (mounted) {
        _showTopSnackBar(
          context,
          'Failed to remove atSign: $e',
          backgroundColor: Colors.red,
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
                title: const Text('Current atSign'),
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
                title: const Text('Agent atSign'),
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

                  _showTopSnackBar(
                    context,
                    value ? 'Ollama only mode enabled - 100% private' : 'Hybrid mode enabled - uses Claude when needed',
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
              'Appearance',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.font_download),
                    title: const Text('Font Family'),
                    subtitle: Text(settings.fontFamily),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showFontFamilyDialog(context, settings),
                  ),
                  ListTile(
                    leading: const Icon(Icons.format_size),
                    title: const Text('Font Size'),
                    subtitle: Text('${settings.fontSize.toStringAsFixed(0)} pt'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: settings.fontSize > SettingsProvider.minFontSize
                              ? () => settings.setFontSize(settings.fontSize - 1)
                              : null,
                        ),
                        SizedBox(
                          width: 40,
                          child: Center(
                            child: Text(
                              settings.fontSize.toStringAsFixed(0),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: settings.fontSize < SettingsProvider.maxFontSize
                              ? () => settings.setFontSize(settings.fontSize + 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: settings.fontSize,
                            min: SettingsProvider.minFontSize,
                            max: SettingsProvider.maxFontSize,
                            divisions: ((SettingsProvider.maxFontSize - SettingsProvider.minFontSize) / 1).round(),
                            label: '${settings.fontSize.toStringAsFixed(0)} pt',
                            onChanged: (value) => settings.setFontSize(value),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => settings.setFontSize(SettingsProvider.defaultFontSize),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                  ),
                ],
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
            title: const Text('Manage atSigns'),
            subtitle: const Text('View and remove stored atSigns'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showManageAtSignsDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('Debug: View atPlatform Keys'),
            subtitle: const Text('View and manage all stored keys'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DebugAtKeysScreen(),
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
            subtitle: Text('0.2.0'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Open Source'),
            subtitle: const Text('View source code on GitHub'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final url = Uri.parse('https://github.com/cconstab/personalagent');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  _showTopSnackBar(context, 'Could not open GitHub');
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
                          // NOTE: We do NOT call clearMessages() here because it would save an empty
                          // conversation to atPlatform, destroying the conversation data!
                          // The in-memory state will be cleared when the app restarts.
                          await context.read<AuthProvider>().signOut();
                          if (context.mounted) {
                            // Pop all routes to return to the front screen (onboarding)
                            Navigator.of(context).popUntil((route) => route.isFirst);
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
