# Contributing to Private AI Agent

Thank you for your interest in contributing to this project! This document provides guidelines and instructions for contributing.

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code. Please be respectful and constructive in all interactions.

## How Can I Contribute?

### Reporting Bugs

- Use the GitHub issue tracker
- Include detailed steps to reproduce
- Include system information (OS, Dart/Flutter version, etc.)
- Include relevant logs and error messages

### Suggesting Enhancements

- Use the GitHub issue tracker with the "enhancement" label
- Clearly describe the feature and its benefits
- Provide examples of how it would work

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Add tests if applicable
5. Ensure all tests pass (`dart test` and `flutter test`)
6. Commit with clear messages
7. Push to your fork
8. Open a Pull Request

## Development Setup

See the main [README.md](README.md) for setup instructions.

### Agent Service (Dart)

```bash
cd agent
dart pub get
dart run build_runner watch  # For code generation
dart test                    # Run tests
```

### Flutter App

```bash
cd app
flutter pub get
flutter test
flutter run -d <device>
```

## Code Style

### Dart

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `dart format` before committing
- Run `dart analyze` to check for issues
- Add documentation comments for public APIs

### Flutter

- Follow [Flutter Best Practices](https://flutter.dev/docs/development/ui/layout/best-practices)
- Use Material Design 3 components
- Ensure accessibility (screen readers, contrast, etc.)
- Test on multiple screen sizes

## Testing

- Write unit tests for all new functionality
- Maintain or improve code coverage
- Test privacy features thoroughly
- Include integration tests where appropriate

## Documentation

- Update README.md if adding new features
- Add inline code documentation
- Update API documentation
- Include examples for complex features

## Privacy Considerations

Since this is a privacy-focused project:

- Never log sensitive user data
- Always use encrypted storage for user context
- Document privacy implications of new features
- Include privacy tests for new features

## Questions?

Feel free to open an issue with the "question" label, or start a discussion in GitHub Discussions.

Thank you for contributing! 🎉
