# Private AI Agent Service

The agent service is the core backend that processes queries with privacy-preserving logic.

## Architecture

```
Query → atPlatform (encrypted) → Agent Service
                                      ↓
                            ┌─────────┴─────────┐
                            ↓                   ↓
                        Ollama              Claude API
                        (local)          (sanitized only)
                            ↓                   ↓
                            └─────────┬─────────┘
                                      ↓
                            Response → atPlatform
```

## Features

- **Privacy-First Processing**: 95% of queries processed locally with Ollama
- **Smart Routing**: Analyzes queries to determine if external knowledge is needed
- **Query Sanitization**: Removes personal information before sending to Claude
- **Encrypted Storage**: All context stored encrypted via atPlatform
- **Hybrid Intelligence**: Combines local LLM with cloud LLM when needed

## Setup

### Prerequisites

1. **Dart SDK** 3.0 or later
2. **Ollama** installed and running locally
3. **atPlatform Keys** - Get your @sign and keys from [atsign.com](https://atsign.com)
4. **Claude API Key** (optional) from [console.anthropic.com](https://console.anthropic.com)

### Installation

1. Install dependencies:
```bash
dart pub get
```

2. Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

3. Configure `.env`:
```bash
# Required
AT_SIGN=@your_agent
AT_KEYS_FILE_PATH=./keys/@your_agent_key.atKeys
OLLAMA_HOST=http://localhost:11434
OLLAMA_MODEL=llama2

# Optional (for hybrid mode)
CLAUDE_API_KEY=your_api_key_here
```

4. Place your atKeys file in the `keys/` directory

### Running Ollama

Install Ollama from [ollama.ai](https://ollama.ai), then:

```bash
# Pull a model
ollama pull llama2

# Start Ollama (if not running)
ollama serve
```

## Usage

### Start the Agent

```bash
dart run bin/agent.dart
```

### Run Tests

```bash
dart test
```

### Generate JSON Serialization Code

```bash
dart run build_runner build
```

## Privacy Guarantees

### What Stays Local (Ollama Only)
- All user context and personal information
- 95% of queries (simple questions, personal queries, context-based queries)
- All analysis and decision-making logic

### What Can Go External (Claude API)
- Only sanitized queries with personal information removed
- Only when local LLM determines external knowledge is needed
- Generic information requests (e.g., "latest tech trends", "job market analysis")

### Example Privacy Flow

**User Query**: "Should I accept this job offer at Acme Corp given my current salary of $120k?"

**Privacy Process**:
1. Ollama analyzes: needs external job market data
2. Sanitize: "Job market analysis for software engineers 2025" → Claude
3. Claude returns: generic market trends (never sees your salary or company)
4. Ollama combines: Claude's market data + YOUR salary + YOUR context
5. Response: Personalized recommendation based on YOUR situation

**What Claude Saw**: Generic job market question  
**What Claude Didn't See**: Your salary, company name, personal situation

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `AT_SIGN` | Yes | - | Your agent's @sign from https://atsign.com |
| `AT_KEYS_FILE_PATH` | Yes | - | Path to your agent's .atKeys file |
| `AT_ROOT_SERVER` | No | `root.atsign.org` | atPlatform root server |
| `ALLOWED_USERS` | No | - | Comma-separated @signs allowed to use agent (empty = allow all) |
| `AGENT_NAME` | No | - | Display name for agent (useful when running multiple agents) |
| `OLLAMA_HOST` | No | `http://localhost:11434` | Ollama server URL |
| `OLLAMA_MODEL` | No | `llama3.2` | Ollama model to use (llama2, llama3.2, etc.) |
| `CLAUDE_API_KEY` | No | - | Claude API key for hybrid mode (optional) |
| `CLAUDE_MODEL` | No | `claude-sonnet-4-5-20250929` | Claude model version |
| `PRIVACY_THRESHOLD` | No | `0.7` | Confidence threshold (0.0-1.0) for local processing |
| `MAX_CONTEXT_SIZE` | No | `4096` | Maximum context window size |

## Development

### Project Structure

```
agent/
├── bin/
│   └── agent.dart              # Main entry point
├── lib/
│   ├── models/
│   │   └── message.dart        # Data models
│   ├── services/
│   │   ├── agent_service.dart  # Main orchestration
│   │   ├── at_platform_service.dart
│   │   ├── ollama_service.dart
│   │   └── claude_service.dart
├── test/                       # Unit tests
├── pubspec.yaml
└── README.md
```

### Adding New Features

1. **Custom Context Sources**: Extend `AtPlatformService` to add new data sources
2. **New LLM Providers**: Implement service interface similar to `ClaudeService`
3. **Enhanced Analysis**: Modify `OllamaService.analyzeQuery()` for better routing logic

## Troubleshooting

### Ollama Connection Issues

```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Restart Ollama
ollama serve
```

### atPlatform Connection Issues

- Verify your atKeys file exists and is valid
- Check your internet connection
- Ensure your @sign is activated

### Model Not Found

```bash
# List available models
ollama list

# Pull the model
ollama pull llama2
```

## License

MIT License - See LICENSE file
