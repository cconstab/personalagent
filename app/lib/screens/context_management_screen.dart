import 'package:flutter/material.dart';
import '../services/at_client_service.dart';

/// Context management screen to view and delete stored context
class ContextManagementScreen extends StatefulWidget {
  const ContextManagementScreen({super.key});

  @override
  State<ContextManagementScreen> createState() =>
      _ContextManagementScreenState();
}

class _ContextManagementScreenState extends State<ContextManagementScreen> {
  final AtClientService _atClientService = AtClientService();
  Map<String, Map<String, dynamic>> _contextMapWithStatus = {};
  bool _isLoading = true;
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContextKeys();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _loadContextKeys() async {
    setState(() => _isLoading = true);
    try {
      final contextMap = await _atClientService.getContextMapWithStatus();
      setState(() {
        _contextMapWithStatus = contextMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load context: $e')));
      }
    }
  }

  Future<void> _deleteContext(String key) async {
    try {
      final success = await _atClientService.deleteContext(key);
      if (success) {
        setState(() {
          _contextMapWithStatus.remove(key);
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Deleted: $key')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  Future<void> _addContext() async {
    if (_keyController.text.isEmpty || _valueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields')),
      );
      return;
    }

    try {
      await _atClientService.storeContext(
        _keyController.text.trim(),
        _valueController.text.trim(),
        enabled: true, // New context items are enabled by default
      );

      setState(() {
        _contextMapWithStatus[_keyController.text.trim()] = {
          'value': _valueController.text.trim(),
          'enabled': true,
        };
      });

      _keyController.clear();
      _valueController.clear();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Context added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add context: $e')));
      }
    }
  }

  void _showEditContextDialog(String key, String currentValue) {
    _keyController.text = key;
    _valueController.text = currentValue;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Context'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: 'Key',
                border: OutlineInputBorder(),
              ),
              enabled: false, // Don't allow changing the key
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _keyController.clear();
              _valueController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (_valueController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Value cannot be empty')),
                );
                return;
              }

              try {
                // Get current enabled status and preserve it
                final currentEnabled =
                    _contextMapWithStatus[key]?['enabled'] as bool? ?? true;

                await _atClientService.storeContext(
                  key,
                  _valueController.text.trim(),
                  enabled: currentEnabled,
                );

                setState(() {
                  _contextMapWithStatus[key] = {
                    'value': _valueController.text.trim(),
                    'enabled': currentEnabled,
                  };
                });

                _keyController.clear();
                _valueController.clear();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Context updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update context: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddContextDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Context'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: 'Key',
                hintText: 'e.g., work_schedule',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Value',
                hintText: 'e.g., Monday-Friday 9am-5pm',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: _addContext, child: const Text('Add')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Context'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContextKeys,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contextMapWithStatus.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.storage_outlined,
                        size: 64,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No context stored',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.5),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add context to personalize your agent',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.3),
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _contextMapWithStatus.length,
                  itemBuilder: (context, index) {
                    final key = _contextMapWithStatus.keys.elementAt(index);
                    final data = _contextMapWithStatus[key]!;
                    final value = data['value'] as String;
                    final enabled = data['enabled'] as bool;

                    return ListTile(
                      leading: Checkbox(
                        value: enabled,
                        onChanged: (bool? newValue) async {
                          try {
                            await _atClientService.toggleContextEnabled(key);
                            setState(() {
                              _contextMapWithStatus[key]!['enabled'] =
                                  newValue ?? true;
                            });
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to toggle: $e')),
                              );
                            }
                          }
                        },
                      ),
                      title: Text(
                        key,
                        style: enabled
                            ? null
                            : TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              ),
                      ),
                      subtitle: Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: enabled
                            ? null
                            : TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.4),
                              ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit',
                            onPressed: () => _showEditContextDialog(key, value),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Context'),
                                  content: Text(
                                    'Are you sure you want to delete "$key"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteContext(key);
                                      },
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      onTap: () => _showEditContextDialog(key, value),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddContextDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Context'),
      ),
    );
  }
}
