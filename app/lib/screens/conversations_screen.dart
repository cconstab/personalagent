import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/agent_provider.dart';
import '../models/conversation.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
      ),
      body: Consumer<AgentProvider>(
        builder: (context, agent, _) {
          if (agent.conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a new conversation to begin',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.3),
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: agent.conversations.length,
            itemBuilder: (context, index) {
              final conversation = agent.conversations[index];
              final isActive = agent.currentConversation?.id == conversation.id;

              return _ConversationTile(
                conversation: conversation,
                isActive: isActive,
                onTap: () {
                  agent.switchConversation(conversation.id);
                  Navigator.pop(context);
                },
                onDelete: () {
                  _showDeleteConfirmation(context, agent, conversation);
                },
                onRename: () {
                  _showRenameDialog(context, agent, conversation);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.read<AgentProvider>().createNewConversation();
          Navigator.pop(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    AgentProvider agent,
    Conversation conversation,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text(
          'Are you sure you want to delete "${conversation.title}"?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await agent.deleteConversation(conversation.id);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    AgentProvider agent,
    Conversation conversation,
  ) {
    final controller = TextEditingController(text: conversation.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Conversation'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) async {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context);
              await agent.renameConversation(conversation.id, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context);
                await agent.renameConversation(
                    conversation.id, controller.text.trim());
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _ConversationTile({
    required this.conversation,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final messageCount = conversation.messages.length;
    final lastMessageTime = conversation.updatedAt;
    final timeAgo = _formatTimeAgo(lastMessageTime);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isActive ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            Icons.chat,
            color: isActive
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(
          conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          '$messageCount message${messageCount == 1 ? '' : 's'} • $timeAgo',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'rename':
                onRename();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Rename'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat.MMMd().format(dateTime);
    }
  }
}
