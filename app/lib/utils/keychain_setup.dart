import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';

/// One-time utility to load .atKeys file into OS keychain
/// After this runs once, keys stay in keychain forever - no more file uploads!
class KeychainSetup {
  /// Import .atKeys file from disk into OS keychain
  /// NOTE: This is mostly handled automatically by the SDK during onboarding
  /// This utility is kept for manual import scenarios if needed
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

      // NOTE: The SDK automatically stores keys in keychain during onboarding
      // This method is primarily for checking if keys exist
      // Manual keychain storage is handled by the SDK's onboarding flow
      
      print('ℹ️ Keys should be imported during the onboarding flow');
      print('   If onboarding completed successfully, keys are already in keychain');
      return false;
    } catch (e, st) {
      print('❌ Failed to check keychain: $e');
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
