# Markdown Support in Agent Responses

The app now supports rich markdown formatting in agent responses, making them more readable and structured.

## Supported Markdown Features

### Text Formatting
- **Bold text**: `**bold**` → **bold**
- *Italic text*: `*italic*` → *italic*
- `Code`: `` `code` `` → `code`

### Headers
```markdown
# Heading 1
## Heading 2
### Heading 3
```

### Lists
**Bullet lists:**
```markdown
- Item 1
- Item 2
- Item 3
```

**Numbered lists:**
```markdown
1. First
2. Second
3. Third
```

### Code Blocks
````markdown
```python
def hello():
    print("Hello, world!")
```
````

### Links
```markdown
[Link text](https://example.com)
```

### Blockquotes
```markdown
> This is a quote
```

## Example Agent Response

When the agent responds with markdown like this:

```markdown
**Lancashire**: As I mentioned earlier, Lancashire is a crumbly, white cheese with a mild, creamy flavor.

**Wensleydale**: Wensleydale is another white English cheese, but it's quite different from Lancashire.
```

It will be rendered with:
- **Lancashire** and **Wensleydale** in bold
- Proper spacing and formatting
- Selectable text for copying

## How It Works

### Agent Side
The agent (using Ollama/Claude) naturally produces markdown-formatted responses. No special configuration needed.

### App Side
- **Agent messages**: Rendered using `MarkdownBody` widget with custom styling
- **User messages**: Plain text with `SelectableText` (no markdown rendering)
- **Selectable**: All text is selectable for copying
- **Links**: Clickable and open in external browser
- **Theme-aware**: Markdown styling matches the app's color scheme

## Benefits

1. **Better Readability**: Headers, bold text, and lists make responses clearer
2. **Code Display**: Code blocks are properly formatted with monospace font
3. **Professional Look**: Responses look more polished and organized
4. **Interactive**: Links are clickable, text is selectable

## Customization

The markdown styling is defined in `chat_bubble.dart` and respects:
- App theme colors
- Dark/light mode
- Color scheme for user/agent/error messages
- Accessibility settings

## Tips for Better Responses

When prompting the agent, you can request specific formats:

```
"Can you list the differences between these cheeses? Use bullet points."
"Explain this concept. Use headers to organize your answer."
"Show me code examples with proper formatting."
```

The agent will naturally use markdown formatting to structure its responses appropriately.
