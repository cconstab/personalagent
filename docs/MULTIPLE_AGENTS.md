# Running Multiple Agents

This guide shows you how to run multiple agents with different names to distinguish their responses.

## Agent Name Feature

Each agent can have a custom name that appears in the chat interface, making it easy to identify which agent responded when running multiple agents.

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

To run multiple agents simultaneously, each monitoring the same atSign or different atSigns:

### Example 1: Multiple specialized agents

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
# Edit .env.research with appropriate settings
dart run bin/agent.dart --env .env.code -n "Code Helper"
```

### Example 2: Using different Ollama models

You can run agents with different models by specifying different OLLAMA_MODEL values:

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

Send a message from the app and you should see responses from all running agents, each clearly labeled with their configured name.
