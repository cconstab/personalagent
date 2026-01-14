import 'dart:io';
import 'package:args/args.dart';
import 'package:at_utils/at_logger.dart';
import 'package:dotenv/dotenv.dart';
import 'package:logging/logging.dart';
import 'package:personal_agent/services/agent_service.dart';
import 'package:personal_agent/services/at_platform_service.dart';
import 'package:personal_agent/services/ollama_service.dart';
import 'package:personal_agent/services/claude_service.dart';

void main(List<String> arguments) async {
  // Setup logging (level will be set after parsing args)
  Logger.root.onRecord.listen((record) {
    // Simple format for non-verbose mode
    if (record.level == Level.INFO) {
      print(record.message);
    } else {
      // Detailed format for verbose mode
      print('${record.level.name}: ${record.time}: ${record.message}');
    }
    if (record.error != null) print('Error: ${record.error}');
    if (record.stackTrace != null) print('Stack: ${record.stackTrace}');
  });

  final logger = Logger('Main');

  // Parse command line arguments
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', help: 'Show this help message', negatable: false)
    ..addFlag('verbose', abbr: 'v', help: 'Enable verbose logging', negatable: false)
    ..addOption('env', abbr: 'e', help: 'Path to .env file', defaultsTo: '.env')
    ..addOption('name', abbr: 'n', help: 'Agent name (displayed in responses)', defaultsTo: null);

  final results = parser.parse(arguments);

  // Configure logging level based on verbose flag
  final verbose = results['verbose'] as bool;
  Logger.root.level = verbose ? Level.ALL : Level.INFO;

  // Configure atPlatform SDK logging (like sshnpd does)
  AtSignLogger.root_level = verbose ? 'INFO' : 'SHOUT';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;

  if (results['help']) {
    print('Private AI Agent with atPlatform');
    print('\nUsage: dart run agent [options]\n');
    print(parser.usage);
    exit(0);
  }

  // Load environment variables
  final envPath = results['env'] as String;
  DotEnv? env;

  if (File(envPath).existsSync()) {
    env = DotEnv(includePlatformEnvironment: true)..load([envPath]);
    logger.info('Loaded environment from $envPath');
  } else {
    logger.warning('No .env file found at $envPath, using environment variables');
  }

  // Helper to get env value (from .env file or platform environment)
  String getEnv(String key, [String defaultValue = '']) {
    return env?[key] ?? Platform.environment[key] ?? defaultValue;
  }

  // Get configuration from environment
  final atSign = getEnv('AT_SIGN');
  final atKeysPath = getEnv('AT_KEYS_FILE_PATH');
  final atRootServer = getEnv('AT_ROOT_SERVER', 'root.atsign.org');

  final ollamaHost = getEnv('OLLAMA_HOST', 'http://localhost:11434');
  final ollamaModel = getEnv('OLLAMA_MODEL', 'llama2');

  final claudeApiKey = getEnv('CLAUDE_API_KEY');
  final claudeModel = getEnv('CLAUDE_MODEL', 'claude-3-5-sonnet-20241022');

  final privacyThreshold = double.tryParse(getEnv('PRIVACY_THRESHOLD', '0.7')) ?? 0.7;

  // Get agent name from command line or environment
  final agentName = (results['name'] as String?) ?? getEnv('AGENT_NAME', '');

  // Validate configuration
  if (atSign.isEmpty || atKeysPath.isEmpty) {
    logger.severe('AT_SIGN and AT_KEYS_FILE_PATH must be set');
    exit(1);
  }

  try {
    // Initialize services
    logger.info('🚀 Starting Private AI Agent');
    logger.info('   atSign: $atSign');
    if (agentName.isNotEmpty) {
      logger.info('   Name: $agentName');
    }
    if (verbose) {
      logger.info('   Ollama: $ollamaHost ($ollamaModel)');
      logger.info('   Claude: ${claudeApiKey.isNotEmpty ? "enabled" : "disabled"}');
    }

    final atPlatform = AtPlatformService(
      atSign: atSign,
      keysFilePath: atKeysPath,
      rootServer: atRootServer,
      instanceId: agentName.isNotEmpty ? agentName : null,
    );

    final ollama = OllamaService(host: ollamaHost, model: ollamaModel);

    // Check Ollama availability
    logger.info('🔍 Checking Ollama availability...');
    final ollamaAvailable = await ollama.healthCheck();
    if (!ollamaAvailable) {
      logger.warning('⚠️  Ollama is not available or model "$ollamaModel" is not installed');
      logger.warning('   Make sure Ollama is running and the model is pulled:');
      logger.warning('   ollama pull $ollamaModel');
      if (claudeApiKey.isEmpty) {
        logger.severe('❌ No fallback available - Claude is not configured');
        exit(1);
      }
      logger.warning('   Will use Claude as fallback');
    }

    final claude = claudeApiKey.isNotEmpty ? ClaudeService(apiKey: claudeApiKey, model: claudeModel) : null;

    // Check Claude availability if configured
    if (claude != null) {
      logger.info('🔍 Checking Claude API availability...');
      final claudeAvailable = await claude.healthCheck();
      if (!claudeAvailable) {
        logger.warning('⚠️  Claude API is not accessible');
        logger.warning('   Check your CLAUDE_API_KEY and model configuration');
        if (!ollamaAvailable) {
          logger.severe('❌ Neither Ollama nor Claude is available - cannot process queries');
          exit(1);
        }
        logger.warning('   Will use Ollama only');
      }
    } else if (!ollamaAvailable) {
      logger.severe('❌ Neither Ollama nor Claude is configured/available');
      exit(1);
    }

    // Use agent name if provided, otherwise use the atSign as the agent name
    final effectiveAgentName = agentName.isNotEmpty ? agentName : atSign;

    final agent = AgentService(
      atPlatform: atPlatform,
      ollama: ollama,
      claude: claude,
      privacyThreshold: privacyThreshold,
      agentName: effectiveAgentName,
    );

    // Initialize agent
    await agent.initialize();
    logger.fine('Agent initialized successfully');

    // Start listening for messages
    await agent.startListening();
    logger.info('✅ Ready - listening for queries');
    if (verbose) {
      logger.info('Press Ctrl+C to stop');
    }

    // Keep the process running
    await ProcessSignal.sigint.watch().first;
    logger.info('🛑 Shutting down...');

    // Cleanup
    await agent.dispose();
    logger.fine('Agent stopped');
  } catch (e, stackTrace) {
    logger.severe('Fatal error', e, stackTrace);
    exit(1);
  }
}
