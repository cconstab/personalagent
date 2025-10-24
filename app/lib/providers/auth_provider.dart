import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/at_client_service.dart' as app_service;
import '../utils/keychain_setup.dart';

/// Authentication state provider
class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _atSign;
  final app_service.AtClientService _atClientService = app_service.AtClientService();

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get atSign => _atSign;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      debugPrint('🔍 Checking for existing authentication...');

      final prefs = await SharedPreferences.getInstance();
      final savedAtSign = prefs.getString('atSign');
      final hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;

      // Only try to auto-authenticate if we have both:
      // 1. A saved @sign in preferences
      // 2. Confirmed onboarding completion
      if (savedAtSign != null && hasCompletedOnboarding) {
        debugPrint('✅ Found saved authentication for $savedAtSign');

        // Check if keys exist in OS keychain
        final keychainAtSigns = await KeychainSetup.listKeychainAtSigns();
        debugPrint('📦 Keychain contains: $keychainAtSigns');

        if (keychainAtSigns.contains(savedAtSign)) {
          debugPrint('✅ Keys found in keychain for $savedAtSign');
          debugPrint('🔐 Will initialize on home screen');

          // Mark as authenticated - actual initialization happens on home screen
          // This prevents race conditions with SDK initialization
          _atSign = savedAtSign;
          _isAuthenticated = true;
        } else {
          debugPrint('⚠️ Keys not found in keychain for $savedAtSign');
          debugPrint('   Clearing saved state - will show onboarding');
          await prefs.remove('atSign');
          await prefs.setBool('hasCompletedOnboarding', false);
        }
      } else {
        debugPrint('ℹ️ No saved authentication - onboarding required');
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> authenticate(String atSign) async {
    try {
      debugPrint('🔐 Authenticating as $atSign');

      // If switching from a different @sign, we need to reset and switch
      if (_atSign != null && _atSign != atSign) {
        debugPrint('⚠️ Switching from $_atSign to $atSign');
        await _clearCurrentSession();
        // Reset AtClientService to close old connections
        await _atClientService.reset();
      }

      _atSign = atSign;

      // Initialize atClient (will handle SDK switching if needed)
      await _atClientService.initialize(atSign);

      // Start the response stream connection for efficient LLM streaming
      try {
        debugPrint('🔌 Starting response stream connection...');
        await _atClientService.startResponseStreamConnection();
        debugPrint('✅ Response stream connection established');
      } catch (e) {
        debugPrint('⚠️ Failed to start response stream (will fall back to notifications): $e');
        // Non-fatal - agent will fall back to notifications if stream unavailable
      }

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('atSign', atSign);
      await prefs.setBool('hasCompletedOnboarding', true);

      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Authentication failed: $e');
      rethrow;
    }
  }

  /// Clear current session state (but keep keychain keys)
  Future<void> _clearCurrentSession() async {
    debugPrint('🧹 Clearing current session state');
    // This will be called when switching @signs
    // Subclasses or other providers can override/extend this
  }

  Future<void> signOut() async {
    try {
      debugPrint('🚪 Signing out from $_atSign...');

      // CRITICAL: Reset the AtClientService to close connections
      await _atClientService.reset();

      // Clear saved preferences only
      // NOTE: We do NOT clear keys from OS keychain - they persist for next login
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('atSign');
      await prefs.setBool('hasCompletedOnboarding', false);

      _atSign = null;
      _isAuthenticated = false;

      debugPrint('✅ Signed out successfully');
      debugPrint('   AtClient closed, PKAM keys remain in keychain');

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
    }
  }
}
