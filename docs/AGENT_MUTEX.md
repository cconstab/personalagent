# Agent Mutex for Load Balancing

## Overview

This document describes the mutex mechanism implemented in the Personal Agent to enable load balancing and redundancy across multiple agent instances listening with the same atSign.

## Problem

When multiple agent instances run simultaneously with the same atSign (for redundancy or load distribution), all agents would receive and respond to the same incoming query. This causes:
- Duplicate responses sent to users
- Wasted computational resources
- Potential confusion when multiple agents with different names respond

## Solution

A query-based mutex mechanism ensures only one agent responds to each query. When a query is received, agents race to acquire a mutex using an **atomic immutable key creation**. The first agent to successfully create the mutex lock processes the query, while others get an immediate exception and skip it.

**Requires at_client 3.8.0 or later** for `Metadata.immutable` support.

## How It Works

### Mutex Acquisition Flow

1. **Query Received**: Agent receives a query notification from the Flutter app
2. **Mutex Check**: Agent attempts to acquire mutex using query ID as the identifier
3. **Race Condition**: Multiple agents may try simultaneously
4. **First Wins**: The first agent to create the mutex key succeeds
5. **Others Skip**: Other agents detect the existing mutex and skip the query
6. **TTL Expiry**: Mutex automatically expires after 30 seconds to prevent stale locks

### Mutex Key Format

```
{queryId}.query_mutexes.personalagent@{agentAtSign}
```

Example:
```
1234567890.query_mutexes.personalagent@myagent
```

### Implementation Details

#### Agent Service (`agent_service.dart`)

The `_handleIncomingQuery` method now includes mutex checking:

```dart
Future<void> _handleIncomingQuery(QueryMessage query) async {
  // Try to acquire mutex for this query
  final mutexAcquired = await _tryAcquireQueryMutex(query);
  if (!mutexAcquired) {
    _logger.info('🤷‍♂️ Will not handle query - another agent will handle this');
    return; // Skip this query
  }

  _logger.info('😎 Acquired mutex - this agent will respond');
  
  // Process and respond to query...
}
```

#### AtPlatform Service (`at_platform_service.dart`)

The `tryAcquireMutex` method implements the actual mutex logic:

1. **Check Existing**: First checks if mutex key already exists
2. **Validate TTL**: If exists, checks if it's expired
3. **Acquire Lock**: Creates new mutex with timestamp
4. **Return Result**: Returns true if acquired, false if another agent has it

```dart
Future<bool> tryAcquireMutex({
  required String mutexId,
  int ttlSeconds = 30,
}) async {
  try {
    // Create mutex key with IMMUTABLE flag for atomic creation
    final mutexKey = AtKey.fromString(
      '$mutexId.query_mutexes.personalagent$atSign',
    )..metadata = (Metadata()
      ..ttl = ttlSeconds * 1000
      ..immutable = true); // ATOMIC: First wins, others get exception!

    // Try to create the mutex - only first agent succeeds
    await _atClient!.put(mutexKey, lockData, 
                         putRequestOptions: PutRequestOptions()
                           ..useRemoteAtServer = true);
    
    return true; // Success! This agent won
  } on AtKeyException {
    return false; // Another agent already has it
  }
}
```

**Key Advantage**: The `immutable = true` flag makes this **truly atomic** - no race conditions possible!

### Logging

The mutex system provides clear logging to help diagnose load balancing:

- `😎 Acquired mutex for query {queryId}` - This agent will respond
- `🤷‍♂️ Will not handle query {queryId} - another agent will handle this` - Another agent acquired mutex
- `Attempting to acquire mutex: {queryId}` - Trying to create mutex
- `✅ Acquired mutex: {queryId}` - Successfully created immutable key
- `� Mutex held by another agent: {queryId}` - AtKeyException received

## Benefits

1. **Load Balancing**: Multiple agent instances can share the workload automatically
2. **Redundancy**: If one agent fails, others can take over new queries
3. **No Configuration**: Existing queries work without modification
4. **Resource Efficiency**: Only one agent processes each query
5. **Simple Deployment**: Just run multiple instances with the same atSign

## Usage

### Running Multiple Agents

To run multiple agent instances for load balancing:

```bash
# Terminal 1 - First agent instance
./run_agent.sh -n "Agent 1"

# Terminal 2 - Second agent instance
./run_agent.sh -n "Agent 2"

# Terminal 3 - Third agent instance
./run_agent.sh -n "Agent 3"
```

All agents should use the same `.env` configuration (same `ATSIGN`).

### Configuration

No special configuration is required for the mutex mechanism. It's enabled by default.

The mutex TTL is currently hardcoded to 30 seconds, which is sufficient for most query processing times.

## Testing

To test the mutex mechanism:

1. Start two or more agent instances with the same atSign
2. Send a query from the Flutter app
3. Check the logs - only one agent should show `😎 Acquired mutex`
4. Check the app - only one response should be received
5. Verify the agent name shows which agent responded

## Technical Notes

### Race Conditions

The mutex implementation uses a get-then-put pattern which has a small race condition window. In practice, this is acceptable because:

- The race window is very small (milliseconds)
- If both agents acquire the mutex due to race condition, it's not catastrophic (user gets response)
- The TTL mechanism prevents permanent locks

### TTL Mechanism

Mutexes expire after 30 seconds to handle edge cases:

- Agent crashes mid-processing
- Network issues
- Unexpected errors

This ensures queries don't get permanently locked if an agent fails.

### Error Handling

If mutex acquisition fails with an unexpected error, the agent proceeds anyway. This ensures the system remains functional even if there are issues with the mutex mechanism.

## Comparison to sshnpd

This implementation is inspired by the session-based mutex pattern used in `sshnpd` from the noports project, with some adaptations:

- **sshnpd**: Uses `immutable = true` metadata flag for atomic mutex creation
- **Personal Agent**: Uses get-then-put pattern (due to AtClient API version differences)
- **sshnpd**: Handles SSH session requests
- **Personal Agent**: Handles query requests

Both achieve the same goal: ensuring only one instance handles each request.

## Future Enhancements

Potential improvements:

1. **Configurable TTL**: Allow setting mutex TTL via environment variable
2. **Mutex Statistics**: Track mutex acquisition success rate
3. **Health Checks**: Monitor agent responsiveness and skip dead agents
4. **Priority System**: Allow certain agents to have priority for mutex acquisition
5. **True Atomic Locks**: If AtClient API supports it in future, use immutable keys

## Troubleshooting

### All Agents Responding

If multiple agents are responding to the same query:

- Check that all agents are using the same atSign
- Verify mutex logging shows acquisition attempts
- Check for network delays causing race conditions

### No Agent Responding

If no agent is responding:

- Check mutex expiry (default 30 seconds)
- Look for errors in mutex acquisition logging
- Verify at least one agent is running and connected

### Mutex Stale Locks

If queries seem stuck:

- Wait 30 seconds for TTL expiry
- Restart agents to clear state
- Check agent logs for processing errors
