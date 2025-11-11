import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

/// Manages app-wide UI settings like font family and size
class SettingsProvider extends ChangeNotifier {
  static const String _fontFamilyKey = 'font_family';
  static const String _fontSizeKey = 'font_size';

  // Default values
  String _fontFamily = 'System Default';
  double _fontSize = 14.0;
  bool _isInitialized = false;

  // Available font families
  static const List<String> availableFonts = [
    'System Default',
    'Roboto',
    'Open Sans',
    'Lato',
    'Montserrat',
    'Poppins',
    'Raleway',
    'Source Sans Pro',
    'Ubuntu',
    'Fira Sans',
  ];

  // Font size range
  static const double minFontSize = 10.0;
  static const double maxFontSize = 24.0;
  static const double defaultFontSize = 14.0;

  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;
  bool get isInitialized => _isInitialized;

  /// Get the actual font family name for TextStyle
  /// Returns null for 'System Default' to use platform default
  String? get fontFamilyForTextStyle {
    return _fontFamily == 'System Default' ? null : _fontFamily;
  }

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _fontFamily = prefs.getString(_fontFamilyKey) ?? 'System Default';
      _fontSize = prefs.getDouble(_fontSizeKey) ?? defaultFontSize;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load settings: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setFontFamily(String fontFamily) async {
    if (!availableFonts.contains(fontFamily)) {
      debugPrint('Invalid font family: $fontFamily');
      return;
    }

    _fontFamily = fontFamily;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fontFamilyKey, fontFamily);
    } catch (e) {
      debugPrint('Failed to save font family: $e');
    }
  }

  Future<void> setFontSize(double size) async {
    if (size < minFontSize || size > maxFontSize) {
      debugPrint('Font size out of range: $size');
      return;
    }

    _fontSize = size;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontSizeKey, size);
    } catch (e) {
      debugPrint('Failed to save font size: $e');
    }
  }

  Future<void> resetToDefaults() async {
    _fontFamily = 'System Default';
    _fontSize = defaultFontSize;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fontFamilyKey);
      await prefs.remove(_fontSizeKey);
    } catch (e) {
      debugPrint('Failed to reset settings: $e');
    }
  }

  /// Create a TextTheme with the current font settings
  TextTheme applyToTextTheme(TextTheme base) {
    // Safety check to ensure fontSize is valid
    if (_fontSize <= 0 || _fontSize.isNaN || _fontSize.isInfinite) {
      debugPrint('Invalid fontSize: $_fontSize, using default');
      _fontSize = defaultFontSize;
    }

    debugPrint('Applying font theme: family=$_fontFamily, size=$_fontSize');

    try {
      final scale = _fontSize / defaultFontSize;
      final clampedScale = scale.clamp(0.5, 2.0);

      debugPrint('Font size scale: $clampedScale');

      // Get the font theme
      TextTheme fontTheme = base;

      if (_fontFamily != 'System Default') {
        switch (_fontFamily) {
          case 'Roboto':
            fontTheme = GoogleFonts.robotoTextTheme(base);
            break;
          case 'Open Sans':
            fontTheme = GoogleFonts.openSansTextTheme(base);
            break;
          case 'Lato':
            fontTheme = GoogleFonts.latoTextTheme(base);
            break;
          case 'Montserrat':
            fontTheme = GoogleFonts.montserratTextTheme(base);
            break;
          case 'Poppins':
            fontTheme = GoogleFonts.poppinsTextTheme(base);
            break;
          case 'Raleway':
            fontTheme = GoogleFonts.ralewayTextTheme(base);
            break;
          case 'Source Sans Pro':
            fontTheme = GoogleFonts.sourceSans3TextTheme(base);
            break;
          case 'Ubuntu':
            fontTheme = GoogleFonts.ubuntuTextTheme(base);
            break;
          case 'Fira Sans':
            fontTheme = GoogleFonts.firaSansTextTheme(base);
            break;
        }
      }

      // Apply font size scale to all text styles
      return TextTheme(
        displayLarge: _applyScale(fontTheme.displayLarge, clampedScale),
        displayMedium: _applyScale(fontTheme.displayMedium, clampedScale),
        displaySmall: _applyScale(fontTheme.displaySmall, clampedScale),
        headlineLarge: _applyScale(fontTheme.headlineLarge, clampedScale),
        headlineMedium: _applyScale(fontTheme.headlineMedium, clampedScale),
        headlineSmall: _applyScale(fontTheme.headlineSmall, clampedScale),
        titleLarge: _applyScale(fontTheme.titleLarge, clampedScale),
        titleMedium: _applyScale(fontTheme.titleMedium, clampedScale),
        titleSmall: _applyScale(fontTheme.titleSmall, clampedScale),
        bodyLarge: _applyScale(fontTheme.bodyLarge, clampedScale),
        bodyMedium: _applyScale(fontTheme.bodyMedium, clampedScale),
        bodySmall: _applyScale(fontTheme.bodySmall, clampedScale),
        labelLarge: _applyScale(fontTheme.labelLarge, clampedScale),
        labelMedium: _applyScale(fontTheme.labelMedium, clampedScale),
        labelSmall: _applyScale(fontTheme.labelSmall, clampedScale),
      );
    } catch (e) {
      debugPrint('Failed to apply font theme: $e');
      // Return base theme on any error
      return base;
    }
  }

  /// Safely apply font size scale to a TextStyle
  /// Only applies if the TextStyle has a fontSize defined
  TextStyle? _applyScale(TextStyle? style, double scale) {
    if (style == null) return null;

    // If the style has no fontSize, return it unchanged
    if (style.fontSize == null) {
      debugPrint('TextStyle has no fontSize, returning unchanged');
      return style;
    }

    // Calculate the new font size and use copyWith to set it
    final oldSize = style.fontSize!;
    final newSize = oldSize * scale;
    debugPrint('Scaling font: $oldSize -> $newSize (scale: $scale)');
    return style.copyWith(fontSize: newSize);
  }
}
