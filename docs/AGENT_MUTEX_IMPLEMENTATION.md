# Agent Mutex Implementation Summary

## Overview
Implemented a mutex mechanism to ensure only one agent responds to each query when multiple agents share the same atSign. This enables load balancing and high availability.

## Pattern Source
Based on the session-based mutex pattern from `sshnpd` in the atsign-foundation/noports repository, using **immutable metadata flag** for atomic key creation.

## Implementation

### Files Modified

1. **agent/lib/services/agent_service.dart**
   - Added `_tryAcquireQueryMutex()` method
   - Modified `_handleIncomingQuery()` to check mutex before processing
   - Logs: `😎 Acquired mutex` or `🤷‍♂️ Will not handle`

2. **agent/lib/services/at_platform_service.dart**
   - Added `tryAcquireMutex()` method
   - Implements **atomic mutex using immutable metadata flag** (requires at_client 3.8.0+)
   - Uses query ID as mutex identifier
   - 30-second TTL to prevent stale locks

### AtClient Version Requirement
**Requires at_client 3.8.0 or later** for `Metadata.immutable` support.

### How It Works

```
Query Received
    ↓
Try Acquire Mutex (query ID)
    ↓
    ├─ Success → Process Query → Send Response
    │             Log: 😎 Acquired mutex
    │
    └─ Failure → Skip Query
                  Log: 🤷‍♂️ Will not handle
```

### Mutex Key Format
```
{queryId}.query_mutexes.personalagent@{agentAtSign}
```

### Technical Details

**Mutex Acquisition Logic (Atomic with Immutable Flag):**
1. Create self-shared AtKey with `metadata.immutable = true`
   - **CRITICAL**: Must use `sharedWith = atSign` so all instances can see it!
   - Without this, each instance creates its own private key (invisible to others)
2. Try to PUT the key to remote server
3. **If successful** → This agent won! Return true
4. **If AtKeyException** → Another agent already created it, return false
5. **If other error** → Log warning and proceed anyway (fail-safe)

This is a **truly atomic operation**:
- First agent to PUT succeeds
- All other agents get AtKeyException immediately
- No race conditions or verification needed!

**Key Structure:**
```dart
AtKey()
  ..key = '{queryId}.query_mutexes.personalagent'
  ..sharedWith = atSign  // Self-shared: visible to all instances!
  ..metadata = (Metadata()
    ..ttl = 30000
    ..immutable = true)
```

**Lock Data Structure:**
```json
{
  "timestamp": "2025-10-15T10:30:00.000Z",
  "agent": "@myagent",
  "instanceId": "tarial1"
}
```

**TTL:** 30 seconds (prevents stale locks from crashed agents)

**Why Immutable + Self-Shared Works:**
- The `immutable = true` metadata tells the atServer to reject any PUT if the key already exists
- The `sharedWith = atSign` makes the key visible to all agent instances (self-shared)
- Without self-sharing, each instance would create a different private key!
- This makes key creation atomic at the server level
- This is the same proven pattern used by sshnpd

### Logging

| Log Message | Meaning |
|------------|---------|
| `😎 Acquired mutex for query {id}` | This agent will process the query |
| `🤷‍♂️ Will not handle query {id}` | Another agent acquired mutex |
| `Attempting to acquire mutex: {id}` | Trying to create mutex key |
| `✅ Acquired mutex: {id}` | Successfully created immutable key |
| `🔒 Mutex held by another agent: {id}` | AtKeyException - another agent has it |
| `⚠️ Error with mutex (will proceed anyway)` | Unexpected error, processing anyway |

## Usage

### Load Balanced Setup (Same atSign)
```bash
# Terminal 1
./run_agent.sh -n "Agent 1"

# Terminal 2
./run_agent.sh -n "Agent 2"

# Terminal 3
./run_agent.sh -n "Agent 3"
```

**Result:** Each query handled by exactly one agent

### Benefits
- ✅ Automatic load distribution
- ✅ High availability (redundancy)
- ✅ No duplicate responses
- ✅ No configuration required
- ✅ Graceful handling of agent failures

## Testing

1. Start 2-3 agents with same atSign but different names
2. Send query from Flutter app
3. Check logs - one shows `😎 Acquired`, others show `🤷‍♂️ Will not handle`
4. App receives exactly one response
5. Agent name identifies which agent responded

## Documentation

- **[AGENT_MUTEX.md](AGENT_MUTEX.md)** - Detailed technical documentation
- **[MULTIPLE_AGENTS.md](MULTIPLE_AGENTS.md)** - Updated with mutex information

## Error Handling

If mutex mechanism fails:
- Agent logs warning but proceeds with query
- Ensures system remains functional
- Worst case: multiple agents respond (still works, just less efficient)

## Comparison to sshnpd

| Aspect | sshnpd | Personal Agent |
|--------|---------|----------------|
| **Mutex Key** | `{sessionId}.session_mutexes` | `{queryId}.query_mutexes` |
| **Mechanism** | `immutable = true` metadata | get-then-put pattern |
| **TTL** | 30 seconds | 30 seconds |
| **Use Case** | SSH session requests | Query requests |
| **Logging** | Emoji-based | Emoji-based |
| **Error Handling** | Proceed on error | Proceed on error |

## Future Enhancements

Potential improvements:
- [ ] Configurable TTL via environment variable
- [ ] Mutex acquisition statistics/metrics
- [ ] Health checks to skip dead agents
- [ ] Priority system for agent selection
- [ ] Use true atomic locks if AtClient API supports in future

## Code Quality

- ✅ No compilation errors
- ✅ No lint warnings
- ✅ Clear logging for debugging
- ✅ Graceful error handling
- ✅ Well-documented code
- ✅ Follows sshnpd pattern

## Related Code References

- **noports sshnpd**: [packages/dart/noports_core/lib/src/sshnpd/sshnpd_impl.dart](https://github.com/atsign-foundation/noports/blob/main/packages/dart/noports_core/lib/src/sshnpd/sshnpd_impl.dart#L427-L454)
- **noports srvd**: [packages/dart/noports_core/lib/src/srvd/srvd_impl.dart](https://github.com/atsign-foundation/noports/blob/main/packages/dart/noports_core/lib/src/srvd/srvd_impl.dart#L238-L260)
