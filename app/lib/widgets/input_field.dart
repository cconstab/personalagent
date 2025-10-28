import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Custom Intent for adding a new line with Shift+Enter
class NewLineIntent extends Intent {
  const NewLineIntent();
}

// Custom Action for handling NewLineIntent
class NewLineAction extends Action<NewLineIntent> {
  final TextEditingController controller;

  NewLineAction(this.controller);

  @override
  Object? invoke(covariant NewLineIntent intent) {
    final text = controller.text;
    final selection = controller.selection;

    // Insert newline at the current cursor position
    final newText = text.replaceRange(selection.start, selection.end, '\n');
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + 1),
    );
    return null;
  }
}

class InputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;

  const InputField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSend,
  });

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  int _lineCount = 1;
  static const int _maxLines = 6;
  static const int _minLines = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateLineCount);
    widget.controller.addListener(_scrollToEnd);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateLineCount);
    widget.controller.removeListener(_scrollToEnd);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    // Scroll to the end when text changes (paste, type, etc.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _updateLineCount() {
    // Count the number of newlines in the text
    final text = widget.controller.text;
    final newLineCount = '\n'.allMatches(text).length + 1;

    if (newLineCount != _lineCount) {
      setState(() {
        _lineCount = newLineCount.clamp(_minLines, _maxLines);
      });
    }
  }

  void _handleSubmit(String value) {
    if (widget.controller.text.trim().isNotEmpty) {
      widget.onSend();
      setState(() {
        _lineCount = 1; // Reset to single line after sending
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Shortcuts(
                shortcuts: <LogicalKeySet, Intent>{
                  LogicalKeySet(LogicalKeyboardKey.shiftLeft,
                      LogicalKeyboardKey.enter): const NewLineIntent(),
                  LogicalKeySet(LogicalKeyboardKey.shiftRight,
                      LogicalKeyboardKey.enter): const NewLineIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    NewLineIntent: NewLineAction(widget.controller),
                  },
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    scrollController: _scrollController,
                    scrollPhysics: const ClampingScrollPhysics(),
                    decoration: InputDecoration(
                      hintText: 'Ask me anything... (Shift+Enter for new line)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    minLines: _minLines,
                    maxLines: _maxLines,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _handleSubmit,
                    enableInteractiveSelection: true,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _handleSubmit(''),
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(16),
              ),
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
