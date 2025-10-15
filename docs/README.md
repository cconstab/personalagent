# 📚 Documentation

Welcome to the Private AI Agent documentation!

## 📖 Quick Navigation

### Getting Started
- **[Main README](../README.md)** - Start here! Setup, features, and quick start
- **[Architecture](../ARCHITECTURE.md)** - How the system works (with diagrams)
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions

### User Guides
- **[atPlatform Integration](guides/ATSIGN_ARCHITECTURE.md)** - How we use atPlatform for E2E encryption
- **[Ollama-Only Mode](guides/OLLAMA_ONLY_MODE.md)** - 100% local privacy mode
- **[Keychain Authentication](guides/KEYCHAIN_AUTH.md)** - Seamless OS authentication

### Development
- **[Testing Checklist](development/TESTING_CHECKLIST.md)** - QA and testing procedures
- **[macOS Permissions](development/MACOS_PERMISSIONS.md)** - macOS-specific setup

### Component Documentation
- **[Agent Service](../agent/README.md)** - Dart backend documentation
- **[Flutter App](../app/README.md)** - Mobile/desktop app documentation

## 🗂️ Documentation Structure

```
docs/
├── README.md (you are here)
├── TROUBLESHOOTING.md          # Common issues & solutions
├── guides/                      # User guides
│   ├── ATSIGN_ARCHITECTURE.md
│   ├── OLLAMA_ONLY_MODE.md
│   └── KEYCHAIN_AUTH.md
├── development/                 # For contributors
│   ├── TESTING_CHECKLIST.md
│   └── MACOS_PERMISSIONS.md
└── archive/                     # Historical documentation
    ├── bug-fixes/              # Historical bug fixes
    ├── development-notes/      # Old development notes
    └── logs/                   # Old status logs
```

## 🎯 Documentation by Task

### I want to...

**...get started quickly**
→ [Main README](../README.md) → Quick Start section

**...understand the architecture**
→ [ARCHITECTURE.md](../ARCHITECTURE.md) - Complete technical overview with diagrams

**...fix a problem**
→ [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Solutions for common issues

**...enable privacy mode**
→ [Ollama-Only Mode Guide](guides/OLLAMA_ONLY_MODE.md)

**...understand authentication**
→ [Keychain Auth Guide](guides/KEYCHAIN_AUTH.md)

**...learn about atPlatform integration**
→ [atSign Architecture](guides/ATSIGN_ARCHITECTURE.md)

**...contribute to development**
→ [CONTRIBUTING.md](../CONTRIBUTING.md) + [development/](development/)

**...deploy in production**
→ [ARCHITECTURE.md](../ARCHITECTURE.md) → Deployment Section

## 📊 Documentation Status

| Document | Status | Last Updated |
|----------|--------|--------------|
| README.md | ✅ Current | Oct 14, 2025 |
| ARCHITECTURE.md | ✅ Current | Oct 14, 2025 |
| TROUBLESHOOTING.md | ✅ Current | Oct 14, 2025 |
| ATSIGN_ARCHITECTURE.md | ✅ Current | Oct 13, 2025 |
| OLLAMA_ONLY_MODE.md | ✅ Current | Oct 14, 2025 |
| KEYCHAIN_AUTH.md | ✅ Current | Oct 13, 2025 |

## 🔄 Updating Documentation

When making changes to the system:

1. **README.md** - Update if features/setup changes
2. **ARCHITECTURE.md** - Update if architecture changes
3. **Component READMEs** - Update agent/app READMEs for component changes
4. **Guides** - Update relevant guides if behavior changes
5. **TROUBLESHOOTING.md** - Add new common issues as discovered

## 📝 Writing Style Guide

- Use emojis for visual navigation 🎯
- Include code examples where helpful
- Provide Mermaid diagrams for complex flows
- Keep language clear and concise
- Test all commands before documenting
- Link to related documentation

## 🗄️ Archive

Historical documentation is preserved in `archive/` for reference:
- **bug-fixes/** - Documentation of past bugs and their fixes
- **development-notes/** - Old development process notes
- **logs/** - Historical status logs

These are kept for:
- Understanding past decisions
- Learning from previous issues
- Historical reference
- Git history preservation

## 🆘 Need Help?

- 📖 Can't find what you need? [Open an issue](https://github.com/cconstab/personalagent/issues)
- 💬 Have questions? [Start a discussion](https://github.com/cconstab/personalagent/discussions)
- 🐛 Found a bug? [Report it](https://github.com/cconstab/personalagent/issues/new)

---

**Maintained by**: [@cconstab](https://github.com/cconstab)  
**Last Updated**: October 14, 2025
