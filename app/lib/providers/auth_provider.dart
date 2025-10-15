import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/at_client_service.dart' as app_service;

/// Authentication state provider
class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _atSign;
  final app_service.AtClientService _atClientService =
      app_service.AtClientService();

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get atSign => _atSign;

  AuthProvider() {
    _checkAuthStatus();
  }

  // NOTE: Keychain clearing has been moved to OnboardingScreen._handleOnboarding()
  // to avoid race condition where calling KeyChainManager here initializes the SDK
  // which then recreates the biometric storage entries we're trying to clear.

  Future<void> _checkAuthStatus() async {
    try {
      // Just check saved auth status - don't clear keychain here!

      final prefs = await SharedPreferences.getInstance();
      final savedAtSign = prefs.getString('atSign');
      final hasCompletedOnboarding =
          prefs.getBool('hasCompletedOnboarding') ?? false;

      if (savedAtSign != null && hasCompletedOnboarding) {
        // Just mark as authenticated based on saved preferences
        // Don't initialize atClient here - let the onboarding widget handle that
        // This avoids triggering keychain checks before onboarding completes
        _atSign = savedAtSign;
        _isAuthenticated = true;
        debugPrint(
            'Found saved auth for $savedAtSign - will initialize on home screen');
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
      _atSign = atSign;

      // Initialize atClient
      await _atClientService.initialize(atSign);

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

  Future<void> signOut() async {
    try {
      // Clear saved preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('atSign');
      await prefs.setBool('hasCompletedOnboarding', false);

      _atSign = null;
      _isAuthenticated = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }
}
