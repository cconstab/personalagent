import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: message.isError
                  ? colorScheme.error
                  : colorScheme.primaryContainer,
              child: Icon(
                message.isError ? Icons.error_outline : Icons.smart_toy,
                color: message.isError
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? colorScheme.primaryContainer
                        : message.isError
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
                      if (!isUser && message.agentName != null) ...[
                        Text(
                          message.agentName!,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      // Use Markdown for agent responses, SelectableText for user messages
                      if (!isUser)
                        MarkdownBody(
                          data: message.content,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: message.isError
                                      ? colorScheme.onErrorContainer
                                      : colorScheme.onSurfaceVariant,
                                ),
                            strong: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: message.isError
                                      ? colorScheme.onErrorContainer
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                            em: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: message.isError
                                      ? colorScheme.onErrorContainer
                                      : colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                            listBullet: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: message.isError
                                      ? colorScheme.onErrorContainer
                                      : colorScheme.onSurfaceVariant,
                                ),
                            code:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: message.isError
                                          ? colorScheme.onErrorContainer
                                          : colorScheme.onSurfaceVariant,
                                      fontFamily: 'monospace',
                                      backgroundColor:
                                          colorScheme.surface.withOpacity(0.3),
                                    ),
                          ),
                          onTapLink: (text, href, title) {
                            if (href != null) {
                              launchUrl(Uri.parse(href),
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                        )
                      else
                        SelectableText(
                          message.content,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                        ),
                      if (!isUser && message.source != null) ...[
                        const SizedBox(height: 8),
                        _buildSourceBadge(context),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
    );
  }

  Widget _buildSourceBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final source = message.source;

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
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
        ),
        if (message.wasPrivacyFiltered) ...[
          const SizedBox(width: 8),
          Icon(Icons.shield_outlined, size: 12, color: colorScheme.primary),
          const SizedBox(width: 2),
          Text(
            'Privacy Filtered',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
