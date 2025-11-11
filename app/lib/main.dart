import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'package:at_utils/at_logger.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'providers/agent_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure atPlatform SDK logging - suppress verbose SDK logs
  // Use 'SHOUT' for critical only (quiet), 'INFO' for more detail
  AtSignLogger.root_level = 'SHOUT';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;

  // Configure app logging
  hierarchicalLoggingEnabled = true;

  // Set root to INFO level - show important app messages
  Logger.root.level = Level.INFO;

  // Clear any existing listeners that the SDK may have added
  Logger.root.clearListeners();

  // Add our own listener for INFO and above
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}|${record.time}|${record.loggerName}|${record.message}');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AgentProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          // Show loading while settings are being loaded
          if (!settings.isInitialized) {
            return const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            );
          }

          return MaterialApp(
            title: 'Private AI Agent',
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              // Apply text scale factor based on font size setting
              final textScaleFactor = settings.fontSize / SettingsProvider.defaultFontSize;
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaleFactor: textScaleFactor,
                ),
                child: child!,
              );
            },
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              textTheme: _getGoogleFontTextTheme(settings.fontFamily, ThemeData.light().textTheme),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              textTheme: _getGoogleFontTextTheme(settings.fontFamily, ThemeData.dark().textTheme),
            ),
            themeMode: ThemeMode.system,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }

  // Helper function to get Google Font text theme
  static TextTheme? _getGoogleFontTextTheme(String fontFamily, TextTheme base) {
    if (fontFamily == 'System Default') return null;

    try {
      switch (fontFamily) {
        case 'Roboto':
          return GoogleFonts.robotoTextTheme(base);
        case 'Open Sans':
          return GoogleFonts.openSansTextTheme(base);
        case 'Lato':
          return GoogleFonts.latoTextTheme(base);
        case 'Montserrat':
          return GoogleFonts.montserratTextTheme(base);
        case 'Poppins':
          return GoogleFonts.poppinsTextTheme(base);
        case 'Raleway':
          return GoogleFonts.ralewayTextTheme(base);
        case 'Source Sans Pro':
          return GoogleFonts.sourceSans3TextTheme(base);
        case 'Ubuntu':
          return GoogleFonts.ubuntuTextTheme(base);
        case 'Fira Sans':
          return GoogleFonts.firaSansTextTheme(base);
        default:
          return null;
      }
    } catch (e) {
      debugPrint('Failed to load Google Font: $e');
      return null;
    }
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!auth.isAuthenticated) {
          return const OnboardingScreen();
        }

        return const HomeScreen();
      },
    );
  }
}
