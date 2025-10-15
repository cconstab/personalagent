import 'dart:io';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';

/// One-time CLI utility to import .atKeys into macOS keychain
/// Run this once, then keys stay in keychain forever!
void main(List<String> args) async {
  print('🔐 atSign Keychain Import Utility');
  print('=====================================\n');

  if (args.isEmpty) {
    print('Usage: dart run import_keys.dart <path-to-atKeys-file> [atsign]');
    print('');
    print('Example:');
    print(
        '  dart run import_keys.dart ~/.atsign/keys/@cconstab_key.atKeys @cconstab');
    print('');
    exit(1);
  }

  final atKeysPath = args[0].replaceAll('~', Platform.environment['HOME']!);
  String atSign;

  if (args.length > 1) {
    atSign = args[1];
  } else {
    // Try to infer from filename
    final filename = atKeysPath.split('/').last;
    atSign = '@${filename.split('_').first.replaceAll('@', '')}';
    print('ℹ️  Inferred @sign from filename: $atSign');
  }

  // Ensure @sign format
  if (!atSign.startsWith('@')) {
    atSign = '@$atSign';
  }

  print('\n📁 .atKeys file: $atKeysPath');
  print('🏷️  @sign: $atSign\n');

  // Check if file exists
  final atKeysFile = File(atKeysPath);
  if (!await atKeysFile.exists()) {
    print('❌ Error: .atKeys file not found!');
    print('   Path: $atKeysPath');
    exit(1);
  }

  print('✅ .atKeys file found\n');

  // Check if already in keychain
  print('🔍 Checking macOS keychain...');
  final existingKeys = await KeychainUtil.getAtsignList() ?? [];

  if (existingKeys.contains(atSign)) {
    print('✅ $atSign is already in keychain!');
    print('   No import needed - keys are ready to use.\n');
    print('📱 Your app will now load keys automatically from keychain.');
    exit(0);
  }

  print('   $atSign not found in keychain\n');

  // Read .atKeys file
  print('📖 Reading .atKeys file...');
  final atKeysContent = await atKeysFile.readAsString();
  print('✅ .atKeys file loaded\n');

  // Import to keychain
  print('💾 Importing to macOS keychain...');
  try {
    final keyChainManager = KeyChainManager.getInstance();

    // First try to store just the keys
    await keyChainManager.storeAtKeysToKeychain(atSign, atKeysContent);

    print('✅ Successfully imported $atSign to keychain!\n');
    print('══════════════════════════════════════════════');
    print('✨ SETUP COMPLETE!');
    print('══════════════════════════════════════════════');
    print('');
    print('Your $atSign keys are now securely stored in macOS keychain.');
    print('');
    print('📱 From now on:');
    print('   - Your Flutter app will load keys automatically');
    print('   - No .atKeys file uploads needed');
    print('   - Keys persist across app restarts');
    print('');
    print('🚀 You can now run your app:');
    print('   ./run_app.sh');
    print('');
  } catch (e, st) {
    print('❌ Failed to import keys to keychain');
    print('   Error: $e');
    print('');
    print('   Stack trace:');
    print('   $st');
    exit(1);
  }
}
