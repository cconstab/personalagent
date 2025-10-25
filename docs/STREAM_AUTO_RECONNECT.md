# Stream Auto-Reconnect

## Overview

The Flutter app now includes automatic reconnection to the agent's stream when the connection is lost. This ensures continuous connectivity even if the agent process restarts or network issues occur.

## How It Works

### Connection to atSign, Not Process
- The stream connection is to the **agent's atSign** (e.g., `@mwcpi`), not a specific process
- If one agent process dies and another starts with the same atSign, messages automatically route to the new process
- The atPlatform handles routing transparently

### Auto-Reconnect Behavior

When the stream connection breaks (error or graceful close), the app:
1. **Detects the disconnection** via stream error or onDone callback
2. **Schedules a reconnect** with exponential backoff
3. **Attempts to reconnect** to the agent's atSign
4. **Connects to whatever agent process** is currently running on that atSign

### Exponential Backoff

Reconnection attempts use exponential backoff to avoid overwhelming the system:

| Attempt | Delay | Calculation |
|---------|-------|-------------|
| 1       | 1s    | 2^0 = 1     |
| 2       | 2s    | 2^1 = 2     |
| 3       | 4s    | 2^2 = 4     |
| 4       | 8s    | 2^3 = 8     |
| 5       | 16s   | 2^4 = 16    |
| 6+      | 30s   | Capped      |

### Visual Feedback

The app provides console feedback for reconnection activity:
- `✅ Stream connection established to @agent` - Successful connection
- `🔌 Stream connection closed` - Stream closed
- `❌ Response stream error: ...` - Stream error occurred
- `🔄 Scheduling reconnect attempt N in Xs...` - Reconnect scheduled

## Implementation Details

### Key Components

**`at_client_service.dart`:**
```dart
// Auto-reconnect state
bool _shouldReconnect = true;
int _reconnectAttempts = 0;
Timer? _reconnectTimer;

// Main entry point
Future<void> startResponseStreamConnection()

// Internal reconnection logic
Future<void> _connectToStreamWithRetry()

// Schedule next attempt
void _scheduleReconnect()

// Stop auto-reconnect
void stopReconnect()
```

### State Management

**`_shouldReconnect`**: Boolean flag controlling whether reconnection should occur
- Set to `true` when `startResponseStreamConnection()` is called
- Set to `false` when `stopReconnect()` is called
- Checked before each reconnection attempt

**`_reconnectAttempts`**: Counter for exponential backoff calculation
- Incremented on each failed attempt
- Reset to 0 on successful connection
- Used to calculate delay: `2^(attempts-1)` seconds (capped at 30s)

**`_reconnectTimer`**: Active timer for scheduled reconnection
- Canceled before scheduling new attempt
- Canceled when `stopReconnect()` is called
- Ensures only one reconnection attempt at a time

## Usage

### Starting Stream Connection

The stream connection starts automatically when the user selects an agent:

```dart
// In home_screen.dart
await atClientService.setAgentAtSign(agentAtSign);
await atClientService.startResponseStreamConnection();
```

Auto-reconnect begins immediately and continues until stopped.

### Stopping Auto-Reconnect

Auto-reconnect should be stopped when:
- User logs out
- User switches agents (old connection)
- App is closing

```dart
// When disposing
atClientService.stopReconnect();
atClientService.dispose();
```

The `dispose()` method automatically calls `stopReconnect()`.

## Testing Scenarios

### 1. Agent Process Restart
1. Start Flutter app and connect to agent
2. Kill the agent process: `Ctrl+C` in agent terminal
3. **Observe**: App detects disconnection, schedules reconnect
4. Start agent again: `.\run_agent.bat`
5. **Observe**: App automatically reconnects to new process

### 2. Network Interruption
1. Start app with stable connection
2. Disconnect network briefly
3. **Observe**: Stream breaks, reconnection scheduled
4. Restore network
5. **Observe**: Reconnection succeeds on next attempt

### 3. Multiple Agent Processes
1. Start first agent process on `@agent`
2. Connect Flutter app to `@agent`
3. Kill first agent process
4. Start second agent process on `@agent`
5. **Observe**: App reconnects to second process automatically

### 4. Exponential Backoff
1. Start app, don't start agent
2. **Observe**: Reconnect attempts with increasing delays
3. Console shows: 1s, 2s, 4s, 8s, 16s, 30s, 30s...

## Benefits

### Resilience
- **Survives agent restarts**: App stays connected through agent deployments/updates
- **Handles network issues**: Temporary network problems don't break the session
- **Load balancing**: Could route to different agent processes if multiple are running

### User Experience
- **Seamless reconnection**: Users don't need to manually reconnect
- **No lost messages**: Queue still works, responses arrive when reconnected
- **Transparent operation**: Reconnection happens in background

### Development
- **Easier testing**: Don't need to restart app when restarting agent
- **Live updates**: Agent code changes don't disrupt testing session
- **Debugging**: Can stop/start agent while investigating issues

## Limitations

### Current Behavior
- **Silent reconnection**: No UI feedback for users (only console logs)
- **No connection status**: UI doesn't show "connected" vs "reconnecting"
- **Queued queries**: Queries sent while disconnected may time out (5 min TTL)

### Future Enhancements
Consider adding:
- **Connection status indicator** in UI (green dot, etc.)
- **Reconnection notification** to user
- **Query queuing** while disconnected
- **Connection health metrics** (latency, uptime, etc.)

## Architecture Note

This auto-reconnect design leverages the atPlatform's **atSign-based routing**:
- Messages are addressed to `@agent` atSign, not an IP/port
- The atPlatform's secondary server handles routing to active processes
- Multiple processes can use the same atSign (last one "wins")
- Client doesn't need to know which process is active

This is fundamentally different from traditional socket/HTTP connections where you connect to a specific process at a specific IP:port. The atSign abstraction provides automatic failover without client-side service discovery.
