# Model Display in Chat Window

**Date**: October 15, 2025  
**Status**: Implemented ✅

## Feature Request

Display the AI model being used in the chat window after the agent's @sign.

## Implementation

### 1. Added Model Getter to AgentProvider ✅

**File**: `app/lib/providers/agent_provider.dart`

Added a computed property that returns the current model based on the `useOllamaOnly` setting:

```dart
/// Get the current model being used by the agent
String get currentModel => _useOllamaOnly ? 'Llama 3.2' : 'Claude 3.5 Sonnet';
```

**Logic**:
- If `useOllamaOnly == true` → Shows "Llama 3.2"
- If `useOllamaOnly == false` → Shows "Claude 3.5 Sonnet"

### 2. Updated Home Screen UI ✅

**File**: `app/lib/screens/home_screen.dart`

Modified the subtitle text to include the model name:

```dart
// BEFORE:
Text(
  '→ ${agent.agentAtSign}',
  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
),

// AFTER:
Text(
  '→ ${agent.agentAtSign} • ${agent.currentModel}',
  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
),
```

## Visual Result

### Before:
```
@cconstab
→ @llama
```

### After:
```
@cconstab
→ @llama • Claude 3.5 Sonnet
```

Or with Ollama-only mode enabled:
```
@cconstab
→ @llama • Llama 3.2
```

## Model Names

### Claude Mode (Default)
- **Model**: Claude 3.5 Sonnet
- **Display**: `Claude 3.5 Sonnet`
- **When**: `useOllamaOnly = false`

### Ollama-Only Mode
- **Model**: Llama 3.2
- **Display**: `Llama 3.2`
- **When**: `useOllamaOnly = true`

## Configuration

Users can toggle between models in **Settings**:
- Settings → "Use Ollama Only" switch
- Toggles between Claude and Llama
- Model display updates automatically

## Files Modified

1. **`app/lib/providers/agent_provider.dart`**
   - Added `currentModel` getter (+3 lines)

2. **`app/lib/screens/home_screen.dart`**
   - Updated subtitle to include model (~1 line)

## Summary

Users can now see which AI model is handling their queries directly in the chat window title bar! 🎉

**Format**: `→ @agentSign • Model Name`
