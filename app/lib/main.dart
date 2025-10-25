import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'providers/agent_provider.dart';
import 'providers/auth_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure logging before any other code runs
  hierarchicalLoggingEnabled = true;

  // Set root to WARNING level - this will suppress all INFO logs
  Logger.root.level = Level.WARNING;

  // Clear any existing listeners that the SDK may have added
  Logger.root.clearListeners();

  // Add our own listener for WARNING and above
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
