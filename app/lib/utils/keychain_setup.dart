import 'dart:io';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';

/// One-time utility to load .atKeys file into OS keychain
/// After this runs once, keys stay in keychain forever - no more file uploads!
class KeychainSetup {
  /// Import .atKeys file from disk into OS keychain
  /// This is a one-time operation - once keys are in keychain, this is never needed again
  static Future<bool> importKeysToKeychain({
    required String atSign,
    required String atKeysFilePath,
  }) async {
    try {
      // Check if already in keychain
      final existingKeys = await KeychainUtil.getAtsignList() ?? [];
      if (existingKeys.contains(atSign)) {
        print('✅ $atSign already in keychain - no import needed!');
        return true;
      }

      // Read .atKeys file
      final atKeysFile = File(atKeysFilePath);
      if (!await atKeysFile.exists()) {
        print('❌ .atKeys file not found: $atKeysFilePath');
        return false;
      }

      final atKeysContent = await atKeysFile.readAsString();

      // Store in keychain using SDK method
      final keyChainManager = KeyChainManager.getInstance();
      await keyChainManager.storeCredentialToKeychain(
        atSign,
        atKeysContent,
      );

      print('✅ Successfully imported $atSign keys to OS keychain!');
      print(
          '   Keys are now secure and persistent - no more file uploads needed.');
      return true;
    } catch (e, st) {
      print('❌ Failed to import keys to keychain: $e');
      print(st);
      return false;
    }
  }

  /// Check if an @sign's keys are in the OS keychain
  static Future<bool> isInKeychain(String atSign) async {
    final existingKeys = await KeychainUtil.getAtsignList() ?? [];
    return existingKeys.contains(atSign);
  }

  /// List all @signs stored in OS keychain
  static Future<List<String>> listKeychainAtSigns() async {
    return await KeychainUtil.getAtsignList() ?? [];
  }
}
