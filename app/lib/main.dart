import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'package:at_utils/at_logger.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'providers/agent_provider.dart';
import 'providers/auth_provider.dart';

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
    debugPrint(
        '${record.level.name}|${record.time}|${record.loggerName}|${record.message}');
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
      ],
      child: MaterialApp(
        title: 'Private AI Agent',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
      ),
    );
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
