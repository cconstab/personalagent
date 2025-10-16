# 🏗️ System Architecture

This document provides a comprehensive overview of the Private AI Agent architecture, explaining how the system maintains privacy while delivering intelligent responses.

## 📋 Table of Contents

- [High-Level Overview](#high-level-overview)
- [System Components](#system-components)
- [Data Flow](#data-flow)
- [Privacy Architecture](#privacy-architecture)
- [Communication Patterns](#communication-patterns)
- [Ollama-Only Mode](#ollama-only-mode)
- [State Management](#state-management)
- [Security Model](#security-model)

## 🎯 High-Level Overview

The system consists of two main applications communicating via the atPlatform:

```mermaid
graph TB
    subgraph "User's Device"
        A[Flutter App<br/>Your @sign]
        O[Ollama<br/>Local LLM]
    end
    
    subgraph "atPlatform Cloud"
        AP[atServer<br/>End-to-End Encrypted]
    end
    
    subgraph "Agent Server"
        B[Agent Service<br/>Agent @sign]
    end
    
    subgraph "External Services"
        C[Claude API<br/>Sanitized Only]
    end
    
    A -->|1. Encrypted Query| AP
    AP -->|2. Notification| B
    B -->|3a. Local Processing| O
    B -->|3b. Generic Query<br/>No Personal Data| C
    B -->|4. Encrypted Response| AP
    AP -->|5. Notification| A
    
    style A fill:#4CAF50
    style B fill:#2196F3
    style O fill:#FF9800
    style C fill:#F44336
    style AP fill:#9C27B0
```

### Key Design Principles

1. **Privacy by Default**: All personal data stays local or encrypted
2. **Hybrid Intelligence**: Combines local and cloud LLMs strategically
3. **End-to-End Encryption**: atPlatform ensures data security
4. **Transparent Processing**: Users see exactly how queries are handled
5. **User Control**: Ollama-only mode for 100% local processing

## 🔧 System Components

### 1. Flutter Application (`app/`)

The cross-platform user interface built with Flutter.

```mermaid
graph LR
    subgraph "Flutter App Architecture"
        UI[Screens<br/>Home, Settings, Onboarding]
        PM[Providers<br/>State Management]
        SV[Services<br/>atClient Communication]
        MD[Models<br/>Data Structures]
        
        UI --> PM
        PM --> SV
        SV --> MD
    end
```

**Key Components:**

- **Screens**:
  - `OnboardingScreen`: PKAM authentication with keychain support
  - `HomeScreen`: Chat interface with message history
  - `SettingsScreen`: Privacy controls and configuration
  - `ContextManagementScreen`: User context/memory management

- **Providers** (State Management):
  - `AuthProvider`: Authentication state and keychain operations
  - `AgentProvider`: Message handling, Ollama-only mode, API communication

- **Services**:
  - `AtClientService`: Manages atPlatform connection and notifications
  - Handles encrypted message sending/receiving

- **Models**:
  - `Message`: Chat message structure
  - `AgentResponse`: Typed responses from agent

### 2. Agent Service (`agent/`)

The Dart backend that processes queries intelligently.

```mermaid
graph TB
    subgraph "Agent Service Architecture"
        AP[AtPlatformService<br/>Notification Listener]
        AS[AgentService<br/>Query Processor]
        OS[OllamaService<br/>Local LLM]
        CS[ClaudeService<br/>External LLM]
        
        AP -->|QueryMessage| AS
        AS -->|Analyze & Route| OS
        AS -->|Sanitized Query| CS
        AS -->|ResponseMessage| AP
    end
```

**Key Components:**

- **AtPlatformService**:
  - Listens for encrypted notifications from users
  - Auto-decrypts using at_talk_gui pattern
  - Parses QueryMessage with privacy settings
  - Sends ResponseMessage back to users

- **AgentService** (Core Logic):
  - Analyzes queries for local vs external processing
  - Determines confidence level for local answers
  - Sanitizes queries before external API calls
  - Combines local + external knowledge intelligently
  - Respects Ollama-only mode flag

- **OllamaService**:
  - Interfaces with local Ollama instance
  - Handles all personal/private queries
  - Provides context-aware responses
  - Free and unlimited usage

- **ClaudeService**:
  - Interfaces with Claude API (optional)
  - Only receives sanitized, generic queries
  - Provides external knowledge and current information
  - Usage minimized through smart routing

## 🔄 Data Flow

### Complete Query Processing Flow

```mermaid
sequenceDiagram
    participant U as User (App)
    participant AC as AtClientService
    participant AS as atServer
    participant AP as AtPlatformService
    participant AG as AgentService
    participant OL as OllamaService
    participant CL as ClaudeService

    U->>AC: Send Query
    Note over AC: Add useOllamaOnly flag<br/>Add timestamp & ID
    AC->>AS: Encrypted Notification<br/>query.personalagent@
    AS->>AP: Notify (Auto-decrypt)
    AP->>AP: Parse QueryMessage<br/>Extract useOllamaOnly
    
    alt Ollama-Only Mode Enabled
        AP->>AG: ProcessQuery(useOllamaOnly=true)
        AG->>OL: Generate Response (100% Local)
        OL-->>AG: Response
        AG->>AP: ResponseMessage
    else Hybrid Mode (Default)
        AP->>AG: ProcessQuery(useOllamaOnly=false)
        AG->>OL: Analyze Query
        OL-->>AG: Analysis (canAnswerLocally, confidence)
        
        alt High Confidence Local
            AG->>OL: Generate Response
            OL-->>AG: Response
        else Need External Knowledge
            AG->>AG: Sanitize Query<br/>(Remove personal data)
            AG->>CL: Sanitized Query
            CL-->>AG: Generic Knowledge
            AG->>OL: Combine with Context
            OL-->>AG: Personalized Response
        end
        AG->>AP: ResponseMessage
    end
    
    AP->>AS: Encrypted Response
    AS->>AC: Notify
    AC->>U: Display Response
```

### Message Structure

**QueryMessage** (App → Agent):
```dart
{
  "id": "1760497926402",
  "type": "query",
  "content": "Should I take this job offer?",
  "userId": "@alice",
  "useOllamaOnly": false,  // Privacy flag
  "timestamp": "2025-10-14T20:12:06.588Z"
}
```

**ResponseMessage** (Agent → App):
```dart
{
  "id": "1760497926402",
  "type": "response",
  "content": "Based on your current situation...",
  "metadata": {
    "processingMode": "hybrid",
    "usedOllama": true,
    "usedClaude": false,
    "confidence": 0.85
  },
  "timestamp": "2025-10-14T20:12:08.123Z"
}
```

## 🔐 Privacy Architecture

### Three-Tier Privacy Model

```mermaid
graph TD
    subgraph "Tier 1: Local Only (95% of Queries)"
        T1[Personal Info<br/>Context-Based<br/>Simple Questions]
    end
    
    subgraph "Tier 2: Hybrid Processing (5% of Queries)"
        T2[External Knowledge Needed<br/>Personal Data Sanitized<br/>Generic Query to Claude]
    end
    
    subgraph "Tier 3: Ollama-Only Mode (100% Local)"
        T3[User-Enforced Privacy<br/>No External APIs Ever<br/>Slightly Reduced Capabilities]
    end
    
    Q[User Query] --> D{Analysis}
    D -->|High Confidence| T1
    D -->|Need External| T2
    Q2[User Query<br/>with Flag] --> T3
    
    T1 --> R1[Ollama Response]
    T2 --> R2[Ollama + Claude Response]
    T3 --> R3[Ollama Response Only]
    
    style T1 fill:#4CAF50
    style T2 fill:#FF9800
    style T3 fill:#2196F3
```

### Data Classification

| Data Type | Location | Encryption | External Access |
|-----------|----------|------------|-----------------|
| User Context/Memory | atServer | E2E Encrypted | Never |
| Chat History | Local Device | Encrypted | Never |
| Query Content | Processed Locally | Encrypted in Transit | Sanitized Only |
| Personal Information | Local/Encrypted | E2E Encrypted | Never |
| Generic Queries | Processed Hybrid | None Needed | Sanitized Only |
| Responses | atServer + Local | E2E Encrypted | Never |

### Query Sanitization Process

```mermaid
flowchart TD
    Q["Original Query: 'Should I accept $120k job at Acme?'"]
    
    A[Analyze for Personal Data]
    
    S["Sanitize: Remove names, numbers, personal identifiers"]
    
    C["Claude Query: 'Software engineer compensation analysis'"]
    
    R["Generic Response: Market trends, average salaries"]
    
    P["Personalize: Apply to user's specific situation"]
    
    F["Final Response: Personalized advice using user context"]
    
    Q --> A
    A --> S
    S --> C
    C --> R
    R --> P
    P --> F
    
    style Q fill:#F44336
    style C fill:#4CAF50
    style F fill:#2196F3
```

## 📡 Communication Patterns

### atPlatform Notification Pattern

Following the `at_talk_gui` pattern for automatic decryption:

```dart
// Sender (App)
await notificationService.notify(
  NotificationParams.forUpdate(
    atKey,
    value: jsonEncode(queryData),
  ),
  checkForFinalDeliveryStatus: false,
  waitForFinalDeliveryStatus: false,
);

// Receiver (Agent)
notificationService.subscribe(
  regex: 'query.*',
  namespace: 'personalagent',
  shouldDecrypt: true,  // Auto-decrypt!
);
```

### Notification Flow

```mermaid
sequenceDiagram
    participant App as Flutter App<br/>@alice
    participant AS1 as atServer<br/>(alice's)
    participant AS2 as atServer<br/>(agent's)
    participant Agent as Agent Service<br/>@alice_agent

    App->>App: Create QueryMessage
    App->>AS1: notify.update:<br/>@alice_agent:query.personalagent@alice
    Note over AS1: Store encrypted
    AS1->>AS2: Forward notification
    AS2->>Agent: Monitor notification
    Agent->>Agent: Auto-decrypt & parse
    Agent->>Agent: Process query
    Agent->>AS2: notify.update:<br/>@alice:response.personalagent@alice_agent
    AS2->>AS1: Forward notification
    AS1->>App: Monitor notification
    App->>App: Auto-decrypt & display
```

### Authentication Flow (PKAM)

```mermaid
sequenceDiagram
    participant App as Flutter App
    participant KC as Keychain/Keystore
    participant OS as AtOnboardingService
    participant AS as atServer

    App->>KC: Check for existing @sign
    
    alt Keys Found in Keychain
        KC-->>App: .atKeys file
        App->>OS: Authenticate with PKAM
        OS->>AS: PKAM challenge/response
        AS-->>OS: Authenticated
        OS-->>App: AtClient ready
        App->>App: Show "Welcome Back!"
    else No Keys Found
        App->>App: Show Onboarding
        App->>OS: Start onboarding flow
        OS->>AS: Request activation
        Note over OS,AS: User follows activation<br/>process (QR code, etc.)
        AS-->>OS: Keys generated
        OS-->>KC: Store .atKeys securely
        OS-->>App: AtClient ready
    end
```

## 🔒 Ollama-Only Mode

A user-controlled privacy feature that ensures 100% local processing.

### Architecture

```mermaid
graph TB
    subgraph "Settings UI"
        SW[Toggle Switch<br/>"Use Ollama Only"]
    end
    
    subgraph "State Management"
        AP[AgentProvider]
        SP[SharedPreferences]
    end
    
    subgraph "Communication"
        AC[AtClientService]
        JSON[QueryMessage JSON]
    end
    
    subgraph "Agent Processing"
        PS[AtPlatformService]
        AS[AgentService]
        OL[OllamaService]
    end
    
    SW --> AP
    AP --> SP
    AP --> AC
    AC --> JSON
    JSON --> PS
    PS --> AS
    AS --> OL
    
    style SW fill:#4CAF50
    style OL fill:#2196F3
    style AS fill:#FF9800
```

### Implementation Details

**1. State Persistence (App)**:
```dart
// AgentProvider
bool _useOllamaOnly = false;
bool get useOllamaOnly => _useOllamaOnly;

Future<void> setUseOllamaOnly(bool value) async {
  _useOllamaOnly = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('useOllamaOnly', value);
  notifyListeners();
}
```

**2. Query Transmission**:
```dart
// AtClientService
Future<void> sendQuery(ChatMessage message, {bool useOllamaOnly = false}) async {
  final queryData = {
    'id': message.id,
    'content': message.content,
    'useOllamaOnly': useOllamaOnly,  // Include flag
    'timestamp': DateTime.now().toIso8601String(),
  };
  // Send via atPlatform...
}
```

**3. Agent Parsing**:
```dart
// AtPlatformService
final useOllamaOnly = jsonData['useOllamaOnly'] ?? false;
final query = QueryMessage(
  id: jsonData['id'],
  content: jsonData['content'],
  userId: jsonData['userId'],
  useOllamaOnly: useOllamaOnly,  // Extract from JSON
  timestamp: DateTime.parse(jsonData['timestamp']),
);
```

**4. Processing Logic**:
```dart
// AgentService
Future<ResponseMessage> processQuery(QueryMessage query) async {
  if (query.useOllamaOnly) {
    _logger.info('🔒 User requested Ollama-only mode - 100% private processing');
    return await _processWithOllama(query, context);
  }
  
  // Normal hybrid logic...
}
```

## 🎭 State Management

### Flutter App State Architecture

```mermaid
graph TB
    subgraph "UI Layer"
        HS[HomeScreen]
        SS[SettingsScreen]
        OS[OnboardingScreen]
    end
    
    subgraph "Provider Layer"
        AP[AgentProvider<br/>Messages & Settings]
        AUP[AuthProvider<br/>Authentication State]
    end
    
    subgraph "Service Layer"
        ACS[AtClientService<br/>Communication]
    end
    
    subgraph "Persistence Layer"
        SP[SharedPreferences<br/>Settings]
        KC[Keychain<br/>Keys]
    end
    
    HS --> AP
    SS --> AP
    OS --> AUP
    
    AP --> ACS
    AUP --> ACS
    
    AP --> SP
    AUP --> KC
    
    style AP fill:#4CAF50
    style AUP fill:#2196F3
```

### State Flow

**AgentProvider** manages:
- Message list (query/response pairs)
- Loading states
- Ollama-only mode setting
- Error handling

**AuthProvider** manages:
- Authentication status
- Current @sign
- Onboarding completion
- Keychain operations

## 🔐 Security Model

### Encryption Layers

```mermaid
graph TD
    subgraph "Layer 1: Transport"
        TLS[TLS 1.3<br/>All Network Traffic]
    end
    
    subgraph "Layer 2: atPlatform"
        E2E[End-to-End Encryption<br/>AES-256]
    end
    
    subgraph "Layer 3: Local Storage"
        KS[Keychain/Keystore<br/>OS-Level Encryption]
    end
    
    subgraph "Layer 4: Memory"
        MEM[Secure Memory<br/>No Plaintext Logging]
    end
    
    APP[Application Data]
    
    APP --> MEM
    MEM --> KS
    KS --> E2E
    E2E --> TLS
    
    style TLS fill:#4CAF50
    style E2E fill:#2196F3
    style KS fill:#FF9800
```

### Key Management

| Key Type | Storage | Purpose | Rotation |
|----------|---------|---------|----------|
| PKAM Private Key | Keychain/Keystore | Authentication | Never (user-owned) |
| Encryption Keys | atPlatform SDK | Message encryption | Per-message |
| API Keys (Claude) | Environment Variables | External API auth | Manual |

### Threat Model & Mitigations

| Threat | Mitigation |
|--------|-----------|
| MITM Attack | TLS + E2E encryption via atPlatform |
| Data Breach (atServer) | All data encrypted, keys never on server |
| Compromised Agent | User data still encrypted, can't decrypt |
| API Key Leakage | Only sanitized queries sent, no personal data |
| Local Device Compromise | Keychain protection, encrypted storage |
| Replay Attacks | Timestamps, unique message IDs |

## 🔍 Query Analysis Algorithm

### Decision Tree

```mermaid
graph TD
    Q[Query Received] --> OM{Ollama-Only<br/>Mode?}
    
    OM -->|Yes| FULL[Process 100%<br/>with Ollama]
    OM -->|No| ANALYZE[Analyze Query<br/>with Ollama]
    
    ANALYZE --> CONF{Confidence<br/>Level}
    
    CONF -->|High >0.7| LOCAL[Process Locally<br/>with Ollama]
    CONF -->|Medium| HYBRID[Hybrid Processing]
    CONF -->|Low <0.3| EXTERNAL[Need External Data]
    
    EXTERNAL --> SANITIZE[Sanitize Query]
    SANITIZE --> CLAUDE[Query Claude API]
    CLAUDE --> COMBINE[Combine with<br/>Local Context]
    
    HYBRID --> SANITIZE
    
    LOCAL --> RESPONSE[Return Response]
    FULL --> RESPONSE
    COMBINE --> RESPONSE
    
    style FULL fill:#4CAF50
    style LOCAL fill:#4CAF50
    style HYBRID fill:#FF9800
    style EXTERNAL fill:#F44336
```

### Example Classifications

| Query Type | Confidence | Processing | External API |
|------------|-----------|------------|--------------|
| "What's my schedule today?" | High (0.95) | Local | ❌ |
| "Should I buy this stock?" | Low (0.30) | Hybrid | ✅ Sanitized |
| "Summarize my notes" | High (0.90) | Local | ❌ |
| "Latest news on AI?" | Low (0.20) | Hybrid | ✅ Generic |
| "Calculate 15% tip on $45" | High (1.00) | Local | ❌ |
| "Compare job offers" | Medium (0.60) | Hybrid | ✅ Market data |

## 📊 System Performance

### Latency Breakdown

```mermaid
gantt
    title Query Processing Time (Typical)
    dateFormat X
    axisFormat %L ms

    section Local Only
    App to atServer     :0, 100
    atServer to Agent   :100, 50
    Agent Analysis      :150, 200
    Ollama Processing   :350, 1500
    Response to User    :1850, 150
    
    section Hybrid Mode
    App to atServer     :0, 100
    atServer to Agent   :100, 50
    Agent Analysis      :150, 200
    Ollama Analysis     :350, 800
    Claude API Call     :1150, 1500
    Ollama Synthesis    :2650, 800
    Response to User    :3450, 150
```

### Resource Usage

| Component | CPU | Memory | Network | Storage |
|-----------|-----|--------|---------|---------|
| Flutter App | Low | 100-200 MB | Minimal | 10-50 MB |
| Agent Service | Low-Med | 200-400 MB | Minimal | 50-100 MB |
| Ollama | High | 4-8 GB | None | 4-7 GB (model) |
| Total | Med | 4-9 GB | <1 MB/query | 5-8 GB |

## 🚀 Deployment Architecture

### Development Setup

```mermaid
graph LR
    subgraph "Developer Machine"
        APP[Flutter App<br/>Hot Reload]
        AGENT[Agent Service<br/>dart run]
        OLLAMA[Ollama<br/>Docker/Local]
    end
    
    subgraph "atPlatform Cloud"
        ATS[atServer<br/>Dev Environment]
    end
    
    subgraph "External"
        CLAUDE[Claude API<br/>Development Tier]
    end
    
    APP <--> ATS
    AGENT <--> ATS
    AGENT --> OLLAMA
    AGENT --> CLAUDE
```

### Production Deployment

```mermaid
graph TB
    subgraph "User Devices"
        IOS[iOS App]
        AND[Android App]
        WEB[Web App]
        DESK[Desktop App]
    end
    
    subgraph "atPlatform Cloud"
        ATS[atServer<br/>Production]
    end
    
    subgraph "Agent Infrastructure"
        LB[Load Balancer]
        A1[Agent Instance 1]
        A2[Agent Instance 2]
        A3[Agent Instance N]
        
        LB --> A1
        LB --> A2
        LB --> A3
    end
    
    subgraph "LLM Services"
        OLL[Ollama Cluster]
        CL[Claude API<br/>Production]
    end
    
    IOS <--> ATS
    AND <--> ATS
    WEB <--> ATS
    DESK <--> ATS
    
    ATS <--> LB
    
    A1 --> OLL
    A2 --> OLL
    A3 --> OLL
    
    A1 --> CL
    A2 --> CL
    A3 --> CL
```

## 📈 Scalability Considerations

### Horizontal Scaling

- **Agent Service**: Stateless, can run multiple instances
- **Ollama**: Can be clustered or use GPU instances
- **atPlatform**: Handles distribution and routing

### Performance Optimization

1. **Caching**: Frequently asked generic questions
2. **Model Selection**: Different Ollama models for different query types
3. **Batch Processing**: Multiple queries from same user
4. **Connection Pooling**: Reuse atPlatform connections

## 🔄 Future Architecture Enhancements

### Planned Improvements

```mermaid
graph TD
    V1[Current: v1.0<br/>Basic Hybrid Processing]
    V2[v2.0: Multi-Model Support<br/>GPT-4, Gemini, etc.]
    V3[v3.0: Context Clustering<br/>Smart Memory Management]
    V4[v4.0: Voice I/O<br/>Speech Recognition]
    V5[v5.0: Autonomous Agents<br/>Background Tasks]
    
    V1 --> V2
    V2 --> V3
    V3 --> V4
    V4 --> V5
```

### Extension Points

- **Plugin System**: Third-party integrations
- **Custom Models**: User-provided Ollama models
- **Context Adapters**: Different storage backends
- **Response Filters**: Custom sanitization rules
- **Analytics**: Privacy-preserving usage insights

---

## 📚 Related Documentation

- [README.md](README.md) - Getting started and overview
- [ATSIGN_ARCHITECTURE.md](ATSIGN_ARCHITECTURE.md) - atPlatform integration details
- [OLLAMA_ONLY_MODE.md](OLLAMA_ONLY_MODE.md) - Privacy feature documentation
- [agent/README.md](agent/README.md) - Agent service details
- [app/README.md](app/README.md) - Flutter app details

---

**Architecture Version**: 1.0  
**Last Updated**: October 14, 2025  
**Maintainer**: [@cconstab](https://github.com/cconstab)
