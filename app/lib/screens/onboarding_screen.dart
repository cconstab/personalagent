import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/at_client_service.dart' as app_service;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isClearing = true;

  @override
  void initState() {
    super.initState();
    _checkForExistingKeys();
  }

  Future<void> _checkForExistingKeys() async {
    try {
      // Check if user has keys in keychain already
      final keychainAtSigns = await KeychainUtil.getAtsignList() ?? [];

      if (keychainAtSigns.isNotEmpty) {
        debugPrint('📦 Found existing @signs in keychain: $keychainAtSigns');
        // User has keys - offer to sign in with existing keys
        setState(() {
          _isClearing = false;
        });
      } else {
        debugPrint('ℹ️ No existing keys found - will show onboarding flow');
        // No keys found - clear any stale SDK state before fresh onboarding
        await _clearSDKStateWithoutInitialization();
        setState(() {
          _isClearing = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking for existing keys: $e');
      setState(() {
        _isClearing = false;
      });
    }
  }

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Private AI Assistant',
      description:
          'Your personal AI agent that keeps your data private and encrypted using atPlatform.',
      icon: Icons.lock_outline,
      color: Colors.deepPurple,
    ),
    OnboardingPage(
      title: 'Local-First Processing',
      description:
          '95% of your queries are processed locally with Ollama. No data leaves your device.',
      icon: Icons.computer_outlined,
      color: Colors.blue,
    ),
    OnboardingPage(
      title: 'Smart Privacy',
      description:
          'When external knowledge is needed, queries are sanitized before being sent to Claude.',
      icon: Icons.security_outlined,
      color: Colors.green,
    ),
    OnboardingPage(
      title: 'Get Started',
      description:
          'Create your @sign to begin using your private AI assistant.',
      icon: Icons.rocket_launch_outlined,
      color: Colors.orange,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Check for existing keys before showing onboarding
      _handleGetStarted();
    }
  }

  Future<void> _handleGetStarted() async {
    // Check if user already has keys in keychain
    final keychainAtSigns = await KeychainUtil.getAtsignList() ?? [];

    if (keychainAtSigns.isNotEmpty && mounted) {
      // User has existing keys - show selection dialog
      _showExistingKeysDialog(keychainAtSigns);
    } else {
      // No keys found - proceed with normal onboarding
      _handleOnboarding();
    }
  }

  void _showExistingKeysDialog(List<String> atSigns) {
    final TextEditingController atSignController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, // Must select an option
      builder: (context) => AlertDialog(
        title: const Text('Select @sign'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose an @sign to sign in with:'),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                itemCount: atSigns.length,
                itemBuilder: (context, index) {
                  final atSign = atSigns[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      leading: const Icon(Icons.account_circle),
                      title: Text(atSign),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmRemoveAtSign(atSign);
                            },
                            tooltip: 'Remove',
                          ),
                        ],
                      ),
                      tileColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onTap: () {
                        debugPrint('👆 User selected: $atSign');
                        Navigator.pop(context);
                        _authenticateWithExistingKeys(atSign);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Or add a different @sign:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: atSignController,
                decoration: InputDecoration(
                  hintText: 'Enter @sign (e.g., @alice)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                onChanged: (value) {
                  // Auto-add @ symbol if not present
                  if (value.isNotEmpty && !value.startsWith('@')) {
                    atSignController.value = TextEditingValue(
                      text: '@$value',
                      selection:
                          TextSelection.collapsed(offset: value.length + 1),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              final newAtSign = atSignController.text.trim();
              if (newAtSign.isEmpty || newAtSign == '@') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter an @sign'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _handleAddNewAtSign(newAtSign);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add @sign'),
          ),
        ],
      ),
    );
  }

  /// Confirm removal of @sign from keychain
  Future<void> _confirmRemoveAtSign(String atSign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove @sign?'),
        content: Text(
          'Remove $atSign from the keychain?\n\nYou can always add it back later by importing the .atKeys file.',
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

  /// Remove @sign from keychain (uses SDK method like NoPorts)
  Future<void> _removeAtSignFromKeychain(String atSign) async {
    try {
      debugPrint('🗑️ Removing $atSign from keychain');

      // Use KeyChainManager (same as NoPorts) to properly delete from keychain
      await KeyChainManager.getInstance().resetAtSignFromKeychain(atSign);

      debugPrint('✅ Removed $atSign from keychain');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$atSign removed from keychain'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the dialog
        _checkForExistingKeys();
      }
    } catch (e) {
      debugPrint('Error removing @sign: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove @sign: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle "Add New @sign" - onboard a new @sign without clearing existing ones
  Future<void> _handleAddNewAtSign(String newAtSign) async {
    try {
      debugPrint('➕ User wants to add: $newAtSign');

      // IMPORTANT: Clear SDK's biometric storage for this specific @sign
      // This prevents the SDK from finding old/partial keys and trying PKAM auth
      if (Platform.isMacOS || Platform.isIOS) {
        debugPrint('Clearing SDK biometric storage for $newAtSign...');
        final result = await Process.run('security', [
          'delete-generic-password',
          '-a',
          newAtSign,
          '-s',
          '@atsigns:com.example.personalAgentApp', // SDK's biometric key
        ]);
        if (result.exitCode == 0) {
          debugPrint('✅ Cleared SDK biometric storage for $newAtSign');
        } else if (result.stderr.toString().contains('could not be found')) {
          debugPrint(
              'ℹ️ No SDK biometric entry found for $newAtSign (this is fine)');
        }
      }

      // Clear the app's current state but preserve other @signs' keys in keychain
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('atSign');
      await prefs.setBool('hasCompletedOnboarding', false);

      // Clear the app's local storage to start fresh
      final dir = await getApplicationSupportDirectory();
      final hiveDir = Directory(dir.path);
      if (await hiveDir.exists()) {
        await for (var entity in hiveDir.list(recursive: true)) {
          if (entity is File) {
            final name = entity.path.split('/').last;
            if (name.endsWith('.hive') ||
                name.endsWith('.lock') ||
                name.endsWith('.hivelock')) {
              try {
                await entity.delete();
              } catch (e) {
                debugPrint('Could not delete $name: $e');
              }
            }
          }
        }
      }

      debugPrint('✅ Cleared app state. Ready to onboard $newAtSign');
      debugPrint('Note: SDK will create fresh state for $newAtSign');

      // Show onboarding for the specific @sign
      // Now SDK won't find any existing keys and will show proper import/activate UI
      await _handleOnboarding(atsign: newAtSign);
    } catch (e) {
      debugPrint('Error in _handleAddNewAtSign: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _authenticateWithExistingKeys(String atSign) async {
    try {
      debugPrint('🔐 Authenticating with existing keys for $atSign');

      final dir = await getApplicationSupportDirectory();

      final atClientPreference = AtClientPreference()
        ..rootDomain = 'root.atsign.org'
        ..namespace = 'personalagent'
        ..hiveStoragePath = dir.path
        ..commitLogPath = dir.path
        ..isLocalStoreRequired = true;

      // Check if we need to switch @signs (if one is already active)
      try {
        final currentAtSign =
            AtClientManager.getInstance().atClient.getCurrentAtSign();
        if (currentAtSign != null && currentAtSign != atSign) {
          debugPrint('🔄 Switching from $currentAtSign to $atSign');
          // Tell SDK to switch primary @sign
          bool switched =
              await AtOnboarding.changePrimaryAtsign(atsign: atSign);
          if (!switched) {
            throw Exception('Failed to switch from $currentAtSign to $atSign');
          }
          debugPrint('✅ Primary @sign switched');
        }
      } catch (e) {
        // AtClientManager not initialized yet - that's fine, first login
        debugPrint('No existing AtClient to switch from: $e');
      }

      // CRITICAL: Pass atsign parameter to force authentication with this specific @sign
      final result = await AtOnboarding.onboard(
        context: context,
        atsign: atSign, // Force authentication with selected @sign
        config: AtOnboardingConfig(
          atClientPreference: atClientPreference,
          rootEnvironment: RootEnvironment.Production,
          domain: 'root.atsign.org',
          appAPIKey: 'personalagent',
        ),
      );

      if (result.status == AtOnboardingResultStatus.success) {
        await _handleSuccessfulOnboarding(result.atsign!);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handles successful onboarding by initializing services and updating auth state
  Future<void> _handleSuccessfulOnboarding(String atSign) async {
    // Initialize our app service wrapper
    final atClientService = app_service.AtClientService();
    await atClientService.initialize(atSign);
    atClientService.setAgentAtSign('@llama');

    // Update auth provider
    if (mounted) {
      await context.read<AuthProvider>().authenticate(atSign);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Authenticated as $atSign'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Clear SDK state without initializing the SDK
  /// This prevents race condition where SDK recreates entries we're trying to clear
  Future<void> _clearSDKStateWithoutInitialization() async {
    try {
      debugPrint('Clearing SDK state before onboarding...');

      // 1. Clear SDK's biometric storage entry using security command directly
      // This DOES NOT initialize the SDK like KeyChainManager.getInstance() does
      if (Platform.isMacOS) {
        final result = await Process.run('security', [
          'delete-generic-password',
          '-a',
          '@atsigns:com.example.personalAgentApp'
        ]);
        if (result.exitCode == 0) {
          debugPrint('✅ SDK biometric storage entry cleared');
        } else if (result.stderr.toString().contains('could not be found')) {
          debugPrint('No SDK biometric storage entry to clear');
        }
      }

      // 2. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('atSign');
      await prefs.setBool('hasCompletedOnboarding', false);
      debugPrint('✅ SharedPreferences cleared');

      // 3. Clear Hive storage
      final dir = await getApplicationSupportDirectory();
      final hiveDir = Directory(dir.path);
      if (await hiveDir.exists()) {
        await for (var entity in hiveDir.list(recursive: true)) {
          if (entity is File) {
            final name = entity.path.split('/').last;
            if (name.endsWith('.hive') ||
                name.endsWith('.lock') ||
                name.endsWith('.hivelock')) {
              await entity.delete();
            }
          }
        }
        debugPrint('✅ Hive storage cleared');
      }

      debugPrint('✅ All SDK state cleared - ready for onboarding');
    } catch (e) {
      debugPrint('Note: Error clearing SDK state: $e');
      // Not critical - continue with onboarding anyway
    }
  }

  Future<void> _handleOnboarding({String? atsign}) async {
    try {
      // SDK state was already cleared in initState()
      // Use app's Application Support directory (isolated from ~/.atsign)
      // This prevents conflicts with other atSign apps like NoPortsDesktop
      final dir = await getApplicationSupportDirectory();

      final atClientPreference = AtClientPreference()
        ..rootDomain = 'root.atsign.org'
        ..namespace = 'personalagent'
        ..hiveStoragePath = dir.path // Isolated storage in app directory
        ..commitLogPath = dir.path
        ..isLocalStoreRequired = true;

      // Check if the specified @sign already exists in keychain
      final keychainAtSigns = await KeychainUtil.getAtsignList() ?? [];
      final atSignExists = atsign != null && keychainAtSigns.contains(atsign);

      if (atSignExists) {
        // User tried to add an @sign that's already in the keychain
        debugPrint('⚠️ $atsign already exists in keychain: $keychainAtSigns');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '$atsign is already in your keychain. Use the sign-in option instead.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        // Show the selection dialog again
        _handleGetStarted();
        return;
      }

      debugPrint(
          '✅ $atsign not in keychain. Current keychain: $keychainAtSigns');

      // Track whether user chose import or activate
      bool isImporting = false;

      // If a specific @sign was provided, show choice dialog
      if (atsign != null && atsign.isNotEmpty) {
        debugPrint('Checking server status for $atsign...');
        // Show a choice dialog: Import keys or Activate new @sign
        final choice = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('How would you like to add this @sign?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Choose how to set up $atsign:'),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.file_upload),
                  title: const Text('Import .atKeys file'),
                  subtitle: const Text('Use existing keys from another device'),
                  onTap: () => Navigator.pop(context, 'import'),
                ),
                ListTile(
                  leading: const Icon(Icons.add_circle),
                  title: const Text('Activate new @sign'),
                  subtitle: const Text('Activate a new @sign you own'),
                  onTap: () => Navigator.pop(context, 'activate'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

        if (choice == null) {
          // User cancelled
          _handleGetStarted();
          return;
        }

        // Store the choice
        isImporting = choice == 'import';
        if (isImporting) {
          debugPrint('User chose to import keys for $atsign');
          debugPrint(
              '⚠️ For import, NOT passing atsign to SDK - let it detect from file');
        } else {
          debugPrint('User chose to activate $atsign');
        }
      }

      // Call SDK onboarding with the appropriate configuration
      // CRITICAL: For import flow, DON'T pass atsign parameter!
      // - If importing: Let SDK detect @sign from the imported .atKeys file
      // - If activating: Pass the atsign to start activation for that specific @sign
      final result = await AtOnboarding.onboard(
        context: context,
        // Only pass atsign for activation, not for import
        atsign: isImporting ? null : atsign,
        isSwitchingAtsign: atsign != null, // This is adding a new @sign
        config: AtOnboardingConfig(
          atClientPreference: atClientPreference,
          rootEnvironment: RootEnvironment.Production,
          domain: 'root.atsign.org',
          appAPIKey: 'personalagent',
          // Hide QR code scanner, only show file upload option
          hideQrScan: true,
          // Add theme for better visibility
          theme: AtOnboardingTheme(
            primaryColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

      switch (result.status) {
        case AtOnboardingResultStatus.success:
          await _handleSuccessfulOnboarding(result.atsign!);
          break;

        case AtOnboardingResultStatus.error:
          debugPrint('❌ Onboarding error: ${result.message}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Onboarding failed',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(result.message ?? 'Unknown error'),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 8),
              ),
            );
          }
          break;

        case AtOnboardingResultStatus.cancel:
          // User cancelled onboarding
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while clearing SDK state
    if (_isClearing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Preparing your secure environment...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _pages[index];
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (_currentPage > 0)
                        TextButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: const Text('Back'),
                        )
                      else
                        const SizedBox(width: 80),
                      const Spacer(),
                      FilledButton(
                        onPressed: _nextPage,
                        child: Text(_currentPage == _pages.length - 1
                            ? 'Get Started'
                            : 'Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const OnboardingPage({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 120,
            color: color,
          ),
          const SizedBox(height: 48),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
