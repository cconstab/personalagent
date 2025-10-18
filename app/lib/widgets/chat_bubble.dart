import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message.dart';

class ChatBubble extends StatefulWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _isHovering = false;

  Future<void> _copyToClipboard(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.message.content));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Copied to clipboard'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 100,
              left: 10,
              right: 10,
            ),
          ),
        );
      }
    } catch (e) {
      // Silently fail - clipboard operations can fail in some contexts
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to copy to clipboard'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 100,
              left: 10,
              right: 10,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              CircleAvatar(
                backgroundColor: widget.message.isError
                    ? colorScheme.error
                    : colorScheme.primaryContainer,
                child: Icon(
                  widget.message.isError
                      ? Icons.error_outline
                      : Icons.smart_toy,
                  color: widget.message.isError
                      ? colorScheme.onError
                      : colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser
                              ? colorScheme.primaryContainer
                              : widget.message.isError
                                  ? colorScheme.errorContainer
                                  : colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isUser ? 16 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser &&
                                widget.message.agentName != null) ...[
                              Row(
                                children: [
                                  Text(
                                    widget.message.agentName ?? '',
                                    style: (Theme.of(context)
                                                .textTheme
                                                .labelSmall ??
                                            const TextStyle())
                                        .copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (widget.message.model != null) ...[
                                    Text(
                                      ' • ',
                                      style: (Theme.of(context)
                                                  .textTheme
                                                  .labelSmall ??
                                              const TextStyle())
                                          .copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        widget.message.model ?? '',
                                        style: (Theme.of(context)
                                                    .textTheme
                                                    .labelSmall ??
                                                const TextStyle())
                                            .copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            // Use Markdown for agent responses, SelectableText for user messages
                            if (!isUser)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MarkdownBody(
                                    data: widget.message.content,
                                    selectable: false,
                                    styleSheet: MarkdownStyleSheet.fromTheme(
                                            Theme.of(context))
                                        .copyWith(
                                      p: (Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium ??
                                              const TextStyle())
                                          .copyWith(
                                        color: widget.message.isError
                                            ? colorScheme.onErrorContainer
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                      strong: (Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium ??
                                              const TextStyle())
                                          .copyWith(
                                        color: widget.message.isError
                                            ? colorScheme.onErrorContainer
                                            : colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      em: (Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium ??
                                              const TextStyle())
                                          .copyWith(
                                        color: widget.message.isError
                                            ? colorScheme.onErrorContainer
                                            : colorScheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      listBullet: (Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium ??
                                              const TextStyle())
                                          .copyWith(
                                        color: widget.message.isError
                                            ? colorScheme.onErrorContainer
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                      code: (Theme.of(context)
                                                  .textTheme
                                                  .bodySmall ??
                                              const TextStyle())
                                          .copyWith(
                                        color: widget.message.isError
                                            ? colorScheme.onErrorContainer
                                            : colorScheme.onSurfaceVariant,
                                        fontFamily: 'monospace',
                                        backgroundColor: colorScheme.surface
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    onTapLink: (text, href, title) {
                                      if (href != null) {
                                        launchUrl(Uri.parse(href),
                                            mode:
                                                LaunchMode.externalApplication);
                                      }
                                    },
                                  ),
                                  // Show streaming indicator for partial messages
                                  if (widget.message.isPartial) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.primary
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.message.content.isEmpty
                                              ? 'Thinking...'
                                              : 'Streaming...',
                                          style: (Theme.of(context)
                                                      .textTheme
                                                      .bodySmall ??
                                                  const TextStyle())
                                              .copyWith(
                                            color: colorScheme.onSurfaceVariant
                                                .withOpacity(0.7),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              )
                            else
                              SelectableText(
                                widget.message.content,
                                style:
                                    (Theme.of(context).textTheme.bodyMedium ??
                                            const TextStyle())
                                        .copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            if (!isUser && widget.message.source != null) ...[
                              const SizedBox(height: 8),
                              _buildSourceBadge(context),
                            ],
                          ],
                        ),
                      ),
                      // Copy button for non-user messages
                      if (!isUser &&
                          _isHovering &&
                          widget.message.content.isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            elevation: 2,
                            child: IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              iconSize: 16,
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: () => _copyToClipboard(context),
                              tooltip: 'Copy to clipboard',
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(widget.message.timestamp),
                    style: (Theme.of(context).textTheme.bodySmall ??
                            const TextStyle())
                        .copyWith(
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: colorScheme.primary,
                child: Icon(Icons.person, color: colorScheme.onPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourceBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final source = widget.message.source;

    IconData icon;
    String label;
    Color color;

    switch (source) {
      case ResponseSource.ollama:
        icon = Icons.computer;
        label = 'Local (Private)';
        color = Colors.green;
        break;
      case ResponseSource.claude:
        icon = Icons.cloud;
        label = 'Claude (Sanitized)';
        color = Colors.orange;
        break;
      case ResponseSource.hybrid:
        icon = Icons.merge_type;
        label = 'Hybrid';
        color = Colors.blue;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle())
              .copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (widget.message.wasPrivacyFiltered) ...[
          const SizedBox(width: 8),
          Icon(Icons.shield_outlined, size: 12, color: colorScheme.primary),
          const SizedBox(width: 2),
          Text(
            'Privacy Filtered',
            style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle())
                .copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return DateFormat.jm().format(time);
    } else {
      return DateFormat.MMMd().add_jm().format(time);
    }
  }
}
