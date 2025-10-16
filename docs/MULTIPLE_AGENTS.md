# Running Multiple Agents

This guide shows you how to run multiple agents with different names to distinguish their responses.

## Agent Name Feature

Each agent can have a custom name that appears in the chat interface, making it easy to identify which agent responded when running multiple agents.

## Load Balancing with Mutex

✨ **New Feature**: Agents now include an automatic mutex mechanism to ensure only one agent responds to each query when multiple agents share the same atSign. This enables:

- **Load Balancing**: Distribute queries across multiple agent instances
- **High Availability**: Redundancy - if one agent fails, others continue serving
- **No Duplicate Responses**: Only one agent responds per query

For detailed technical information, see [AGENT_MUTEX.md](AGENT_MUTEX.md).

## Starting an Agent with a Name

### Option 1: Using the `-n` flag

```bash
./run_agent.sh -n "Research Assistant"
```

### Option 2: Using environment variable

Add to your `.env` file:
```env
AGENT_NAME=Research Assistant
```

Then start normally:
```bash
./run_agent.sh
```

## Running Multiple Agents

To run multiple agents simultaneously. You can run agents with:
- **Same atSign** (load balancing) - mutex ensures only one responds per query
- **Different atSigns** (independent agents) - each responds to its own queries

### Example 1: Load Balanced Agents (Same atSign)

Run multiple instances with the same atSign for automatic load balancing:

**Terminal 1:**
```bash
./run_agent.sh -n "Agent 1"
```

**Terminal 2:**
```bash
./run_agent.sh -n "Agent 2"
```

**Terminal 3:**
```bash
./run_agent.sh -n "Agent 3"
```

**Result**: Each query is automatically handled by exactly one agent. The mutex system ensures no duplicate responses.

### Example 2: Multiple specialized agents (Different atSigns)

**Terminal 1 - General Agent:**
```bash
cd agent
cp .env .env.general
# Edit .env.general with appropriate settings
dart run bin/agent.dart --env .env.general -n "General AI"
```

**Terminal 2 - Research Agent:**
```bash
cd agent
cp .env .env.research
# Edit .env.research with appropriate settings
dart run bin/agent.dart --env .env.research -n "Research Assistant"
```

**Terminal 3 - Code Agent:**
```bash
cd agent
cp .env .env.code
# Edit .env.code with appropriate settings
dart run bin/agent.dart --env .env.code -n "Code Helper"
```

### Example 3: Using different Ollama models

You can run load-balanced agents with different models by specifying different OLLAMA_MODEL values:

**.env.fast** (using llama3):
```env
AT_SIGN=@fast_agent
OLLAMA_MODEL=llama3
AGENT_NAME=Quick Response
```

**.env.smart** (using llama3:70b or another model):
```env
AT_SIGN=@smart_agent
OLLAMA_MODEL=llama3:70b
AGENT_NAME=Deep Thinker
```

Then run:
```bash
# Terminal 1
dart run bin/agent.dart --env .env.fast

# Terminal 2
dart run bin/agent.dart --env .env.smart
```

## Agent Name Display

In the chat interface, agent responses will show the agent name above the message:

```
┌─────────────────────────┐
│ Research Assistant      │ ← Agent name
│                         │
│ Based on my research... │
│                         │
│ [ollama] [private]      │
└─────────────────────────┘
```

## Configuration Tips

1. **Distinct Names**: Use clear, descriptive names like "Code Helper", "Research Assistant", "General AI"
2. **Different @signs**: For completely independent agents, use different AT_SIGN values
3. **Model Selection**: Match the model to the agent's purpose (fast models for quick responses, larger models for complex reasoning)
4. **Resource Management**: Be mindful of system resources when running multiple Ollama models simultaneously

## Monitoring Multiple Agents

When running multiple agents, each will log independently. Consider using terminal multiplexers like tmux or using separate terminal windows to monitor each agent's logs.

```bash
# Using tmux
tmux new-session -d -s agent1 './run_agent.sh -n "Agent 1"'
tmux new-session -d -s agent2 './run_agent.sh -n "Agent 2"'
tmux new-session -d -s agent3 './run_agent.sh -n "Agent 3"'
```

## Testing

### Testing Load Balanced Agents (Same atSign)

1. Start multiple agents with the same atSign but different names
2. Send a message from the app
3. **Expected**: You should see exactly ONE response, labeled with one agent's name
4. Check the agent logs - one will show `😎 Acquired mutex`, others show `🤷‍♂️ Will not handle`
5. Send another message - it may be handled by a different agent

### Testing Independent Agents (Different atSigns)

1. Start agents with different atSigns
2. Send a message from the app
3. **Expected**: You should see responses from ALL running agents (if they all monitor your atSign)
4. Each response will be clearly labeled with the agent's name

## How the Mutex Works

When you run multiple agents with the **same atSign**:

1. Query arrives → All agents receive it
2. Agents race to acquire mutex using query ID
3. First agent to create mutex lock wins
4. Winner processes query and responds
5. Losers skip the query (log: `🤷‍♂️ Will not handle`)

This happens automatically - no configuration needed!

**Mutex Logging:**
- `😎 Acquired mutex for query {id}` - This agent won and will respond
- `🤷‍♂️ Will not handle query {id}` - Another agent won, this one skips
- `🆕 Creating new mutex` - No existing lock found
- `🔒 Mutex already acquired` - Another agent has valid lock

For more details, see [AGENT_MUTEX.md](AGENT_MUTEX.md).
