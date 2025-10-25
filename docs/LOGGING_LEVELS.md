# Logging Levels

## Overview

The agent now supports two logging modes:
- **Normal mode** (default): Shows only essential operational messages
- **Verbose mode** (`-v` flag): Shows detailed debugging information

## Usage

### Windows
```bash
# Normal mode (clean output)
.\run_agent.bat

# Verbose mode (detailed debugging)
.\run_agent.bat -v
```

### Linux/Mac
```bash
# Normal mode (clean output)
./run_agent.sh

# Verbose mode (detailed debugging)
./run_agent.sh -v
```

## Logging Levels

### INFO Level (Normal Mode)
Shows only the essentials:
- **Startup**: Agent initialization and configuration summary
- **Connections**: When apps connect/disconnect via stream
- **Queries**: When queries are received and responses sent
- **Status**: Ready state and shutdown messages

**Example Normal Output:**
```
🚀 Starting Private AI Agent
   atSign: @myagent
✅ AtPlatform ready
🎧 Listening for stream connections
✅ Listening for queries
✅ Ready - listening for queries
🔗 Connected: @user123
⚡ Query from @user123
✅ Sent response to @user123
🔌 Disconnected: @user123
```

### FINE Level (Verbose Mode)
Includes all INFO messages plus detailed debugging:
- Storage paths and configuration details
- Authentication flow details
- Subscription patterns and namespace info
- Query processing stages
- Conversation history details
- Mutex acquisition details
- Message routing and transformation
- API call details (Ollama/Claude)

**Example Verbose Output:**
```
FINE: 2024-10-24 10:15:23.456: Initializing agent services
FINE: 2024-10-24 10:15:23.789: Storage paths:
FINE: 2024-10-24 10:15:23.790:   Hive: ./storage/hive
FINE: 2024-10-24 10:15:23.791:   Commit: ./storage/commit
FINE: 2024-10-24 10:15:24.123: Authenticating with PKAM...
FINE: 2024-10-24 10:15:25.456: ✅ PKAM authentication successful
FINE: 2024-10-24 10:15:25.789: 📅 Configured to fetch ONLY new notifications
INFO: ✅ AtPlatform ready
...
```

## Log Level Details

### Critical Messages (Always Shown)
- **SEVERE**: Fatal errors, exceptions with stack traces
- **WARNING**: Non-fatal issues that need attention

### Operational Messages (INFO)
- Agent startup and ready state
- Stream connections established/closed
- Query received notifications
- Response sent confirmations

### Debug Details (FINE)
- Configuration and initialization steps
- Storage and authentication flow
- Subscription and channel setup
- Query processing stages
- Conversation history tracking
- Mutex acquisition for multi-agent coordination
- API communication details

## Implementation

The logging system uses Dart's `logging` package with hierarchical loggers:

```dart
// In agent.dart
final verbose = results['verbose'] as bool;
Logger.root.level = verbose ? Level.ALL : Level.INFO;

// In service classes
_logger.info('Essential operational message');  // Always shown
_logger.fine('Detailed debug information');     // Only with -v flag
```

## Benefits

### Normal Mode
- **Clean output**: Easy to monitor agent activity
- **Performance**: Minimal logging overhead
- **Production-ready**: Suitable for production deployments
- **Quick debugging**: See connection and query flow at a glance

### Verbose Mode
- **Full debugging**: Complete visibility into all operations
- **Troubleshooting**: Detailed information for diagnosing issues
- **Development**: Understand exact execution flow
- **Audit trail**: Complete record of all activities

## Log Format

### Normal Mode (INFO)
```
{message}
```
Simple, clean message without timestamp or level prefix.

### Verbose Mode (FINE+)
```
{LEVEL}: {timestamp}: {message}
```
Full details including log level and timestamp.

### Errors (Always Detailed)
```
{LEVEL}: {timestamp}: {message}
Error: {error details}
Stack: {stack trace}
```
Complete error information including stack traces.
