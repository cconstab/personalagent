import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/at_client_service.dart';

/// Authentication state provider
class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _atSign;
  final AtClientService _atClientService = AtClientService();

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get atSign => _atSign;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAtSign = prefs.getString('atSign');
      final hasCompletedOnboarding =
          prefs.getBool('hasCompletedOnboarding') ?? false;

      if (savedAtSign != null && hasCompletedOnboarding) {
        _atSign = savedAtSign;
        _isAuthenticated = true;

        // Try to initialize atClient
        try {
          await _atClientService.initialize(savedAtSign);
        } catch (e) {
          debugPrint('Failed to initialize atClient: $e');
          // Continue anyway, user can re-authenticate if needed
        }
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
