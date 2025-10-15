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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Welcome Back!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('We found your existing @sign:'),
            const SizedBox(height: 16),
            for (final atSign in atSigns)
              ListTile(
                leading: const Icon(Icons.account_circle),
                title: Text(atSign),
                tileColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _authenticateWithExistingKeys(atSign);
                },
              ),
            const SizedBox(height: 16),
            const Text(
              'Or create/import a new @sign:',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleOnboarding();
            },
            child: const Text('Use Different @sign'),
          ),
        ],
      ),
    );
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

      // Authenticate with existing keys from keychain
      final result = await AtOnboarding.onboard(
        context: context,
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

  Future<void> _handleOnboarding() async {
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

      // DON'T pass atsign parameter - let the SDK show its own atsign input
      // This prevents the SDK from immediately checking keychain for a specific atsign
      // The user will enter @cconstab in the SDK's UI, and by then we've cleared the keychain
      final result = await AtOnboarding.onboard(
        context: context,
        // NO atsign parameter! This is the key - SDK won't check keychain immediately
        config: AtOnboardingConfig(
          atClientPreference: atClientPreference,
          rootEnvironment: RootEnvironment.Production,
          domain: 'root.atsign.org',
          appAPIKey: 'personalagent',
          hideQrScan: true, // Hide QR code and file upload options
        ),
      );

      switch (result.status) {
        case AtOnboardingResultStatus.success:
          await _handleSuccessfulOnboarding(result.atsign!);
          break;

        case AtOnboardingResultStatus.error:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Onboarding failed: ${result.message}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
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
