import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
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
      // Navigate to atPlatform authentication
      _startAtOnboarding();
    }
  }

  Future<void> _startAtOnboarding() async {
    // Show dialog to get atSign and keys file
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _AtSignInputDialog(),
    );

    if (result == null) return; // User cancelled

    final atSign = result['atSign']!;
    final keysFilePath = result['keysFilePath']!;

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      await _initializeAtClient(atSign, keysFilePath);
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Authenticated as $atSign'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _initializeAtClient(String atSign, String keysFilePath) async {
    // Ensure @ prefix
    final formattedAtSign = atSign.startsWith('@') ? atSign : '@$atSign';

    // Get app documents directory for storage
    final appDocumentsDirectory = await getApplicationDocumentsDirectory();

    // Configure atClient preferences
    final atClientPreference = AtClientPreference()
      ..rootDomain = 'root.atsign.org'
      ..namespace = 'personalagent'
      ..hiveStoragePath = appDocumentsDirectory.path
      ..commitLogPath = appDocumentsDirectory.path
      ..isLocalStoreRequired = true;

    // Validate keys file exists
    final keysFile = File(keysFilePath);
    if (!await keysFile.exists()) {
      throw Exception('Keys file not found at $keysFilePath');
    }

    // Initialize AtClientManager with keys
    final atClientManager = AtClientManager.getInstance();
    await atClientManager.setCurrentAtSign(
      formattedAtSign,
      'personalagent',
      atClientPreference,
    );

    // TODO: Properly load encryption keys from file
    // The keys file should be parsed and loaded into the keystore
    // This is simplified for now - production needs proper key management

    // Initialize app service
    final atClientService = app_service.AtClientService();
    await atClientService.initialize(formattedAtSign);
    atClientService.setAgentAtSign('@llama');
    
    // Update auth provider
    if (mounted) {
      await context.read<AuthProvider>().authenticate(formattedAtSign);
    }
  }

  @override
  Widget build(BuildContext context) {
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

class _AtSignInputDialog extends StatefulWidget {
  const _AtSignInputDialog();

  @override
  State<_AtSignInputDialog> createState() => _AtSignInputDialogState();
}

class _AtSignInputDialogState extends State<_AtSignInputDialog> {
  final TextEditingController _atSignController = TextEditingController();
  String? _keysFilePath;

  @override
  void dispose() {
    _atSignController.dispose();
    super.dispose();
  }

  Future<void> _pickKeysFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['atKeys'],
      dialogTitle: 'Select your .atKeys file',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _keysFilePath = result.files.single.path;
      });
    }
  }

  void _submit() {
    final atSign = _atSignController.text.trim();
    
    if (atSign.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your @sign')),
      );
      return;
    }

    if (_keysFilePath == null || _keysFilePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your .atKeys file')),
      );
      return;
    }

    Navigator.pop(context, {
      'atSign': atSign,
      'keysFilePath': _keysFilePath!,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('atPlatform Authentication'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your @sign and select your .atKeys file.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _atSignController,
              decoration: const InputDecoration(
                labelText: '@sign',
                hintText: '@cconstab',
                border: OutlineInputBorder(),
                prefixText: '@',
              ),
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickKeysFile,
              icon: const Icon(Icons.folder_open),
              label: Text(_keysFilePath == null
                  ? 'Select .atKeys File'
                  : 'Keys file selected ✓'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            if (_keysFilePath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _keysFilePath!.split('/').last,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Need help?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Get a free @sign at atsign.com\n'
                    '• Keys file is usually in ~/.atsign/keys/\n'
                    '• File format: @yoursign_key.atKeys',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Authenticate'),
        ),
      ],
    );
  }
}
