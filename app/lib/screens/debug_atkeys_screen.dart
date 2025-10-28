import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/at_client_service.dart' as app_service;

class DebugAtKeysScreen extends StatefulWidget {
  const DebugAtKeysScreen({super.key});

  @override
  State<DebugAtKeysScreen> createState() => _DebugAtKeysScreenState();
}

class _DebugAtKeysScreenState extends State<DebugAtKeysScreen> {
  List<app_service.AtKeyInfo> _keys = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final atClientService = app_service.AtClientService();
      final keys = await atClientService.getPersonalAgentKeys();

      setState(() {
        _keys = keys;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteKey(app_service.AtKeyInfo keyInfo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Key'),
        content: Text(
            'Are you sure you want to delete this key?\n\n${keyInfo.keyString}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final atClientService = app_service.AtClientService();
        await atClientService.deleteAtKey(keyInfo.atKey);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Key deleted')),
          );
          _loadKeys(); // Refresh list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Future<void> _viewKeyDetails(app_service.AtKeyInfo keyInfo) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Key Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(label: 'Key', value: keyInfo.keyString),
              const SizedBox(height: 8),
              _DetailRow(label: 'Type', value: keyInfo.type),
              const SizedBox(height: 8),
              _DetailRow(label: 'TTL', value: keyInfo.ttlDisplay),
              if (keyInfo.sharedWith != null) ...[
                const SizedBox(height: 8),
                _DetailRow(label: 'Shared With', value: keyInfo.sharedWith!),
              ],
              const SizedBox(height: 16),
              const Text('Content:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  keyInfo.value ?? '(empty)',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: keyInfo.value ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Content copied to clipboard')),
              );
            },
            child: const Text('Copy Content'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('atPlatform Keys'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadKeys,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadKeys,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_keys.isEmpty) {
      return const Center(
        child: Text('No keys found in personalagent namespace'),
      );
    }

    // Separate shared keys (suspicious) from self-owned keys
    final sharedKeys = _keys.where((k) => k.sharedWith != null).toList();
    final selfKeys = _keys.where((k) => k.sharedWith == null).toList();

    return ListView(
      children: [
        if (sharedKeys.isNotEmpty) ...[
          Container(
            color: Colors.orange[100],
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${sharedKeys.length} key(s) shared with another @sign. '
                    'These are likely old keys that should be deleted.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          ...sharedKeys.map((key) => _KeyTile(
                keyInfo: key,
                isShared: true,
                onTap: () => _viewKeyDetails(key),
                onDelete: () => _deleteKey(key),
              )),
          const Divider(thickness: 2),
        ],
        if (selfKeys.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Self-Owned Keys',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ...selfKeys.map((key) => _KeyTile(
                keyInfo: key,
                isShared: false,
                onTap: () => _viewKeyDetails(key),
                onDelete: () => _deleteKey(key),
              )),
        ],
      ],
    );
  }
}

class _KeyTile extends StatelessWidget {
  final app_service.AtKeyInfo keyInfo;
  final bool isShared;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _KeyTile({
    required this.keyInfo,
    required this.isShared,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isShared ? Colors.orange[50] : null,
      child: ListTile(
        leading: Icon(
          _getIconForType(keyInfo.type),
          color: isShared ? Colors.orange : Colors.blue,
        ),
        title: Text(
          keyInfo.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${keyInfo.type}'),
            Text('TTL: ${keyInfo.ttlDisplay}'),
            if (isShared) Text('⚠️ Shared with: ${keyInfo.sharedWith}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: onTap,
              tooltip: 'View',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onDelete,
              tooltip: 'Delete',
              color: Colors.red,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'conversation':
        return Icons.chat;
      case 'context':
        return Icons.person;
      case 'mapping':
        return Icons.link;
      default:
        return Icons.storage;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: SelectableText(value),
        ),
      ],
    );
  }
}
