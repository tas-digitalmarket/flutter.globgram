import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/app_logger.dart';

class LogViewPage extends StatefulWidget {
  const LogViewPage({super.key});

  @override
  State<LogViewPage> createState() => _LogViewPageState();
}

class _LogViewPageState extends State<LogViewPage> {
  final AppLogger _logger = AppLogger();

  @override
  void initState() {
    super.initState();
    _logger.onLogAdded = () {
      if (mounted) {
        setState(() {});
      }
    };
  }

  @override
  void dispose() {
    _logger.onLogAdded = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐛 Debug Logs'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyAllLogs,
            tooltip: 'Copy All Logs',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearLogs,
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.blue.shade200),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📊 Log Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Total Logs: ${_logger.logs.length}'),
                Text(
                    'Last Update: ${DateTime.now().toString().substring(11, 19)}'),
              ],
            ),
          ),

          // Logs List
          Expanded(
            child: _logger.logs.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _logger.logs.length,
                    itemBuilder: (context, index) {
                      final log = _logger.logs[index];
                      return _buildLogItem(log);
                    },
                  ),
          ),

          // Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addTestLog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Test Log'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _logger.logs.isNotEmpty ? _exportLogs : null,
                    icon: const Icon(Icons.download),
                    label: const Text('Export'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No logs yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the app to generate debug logs',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(LogEntry log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: log.color.withOpacity(0.05),
        border: Border.all(
          color: log.color.withOpacity(0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: log.color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              log.prefix,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        title: Text(
          log.message,
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            color: log.color,
          ),
        ),
        subtitle: Text(
          log.formattedTime,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        onTap: () => _showLogDetails(log),
      ),
    );
  }

  void _showLogDetails(LogEntry log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${log.prefix} Log Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time: ${log.timestamp.toString()}'),
            const SizedBox(height: 8),
            Text('Level: ${log.level.name.toUpperCase()}'),
            const SizedBox(height: 8),
            const Text('Message:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.message,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: log.message));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _addTestLog() {
    final messages = [
      'Test log entry added manually',
      'Connection attempt initiated',
      'Peer discovery started',
      'WebRTC offer created',
      'Data channel established',
    ];
    final levels = [
      LogLevel.info,
      LogLevel.success,
      LogLevel.warning,
      LogLevel.debug
    ];

    final message = messages[DateTime.now().millisecond % messages.length];
    final level = levels[DateTime.now().second % levels.length];

    _logger.log(message, level);
  }

  void _copyAllLogs() {
    if (_logger.logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs to copy')),
      );
      return;
    }

    final logText = _logger.logs
        .map((log) =>
            '[${log.formattedTime}] ${log.level.name.toUpperCase()}: ${log.message}')
        .join('\n');

    Clipboard.setData(ClipboardData(text: logText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${_logger.logs.length} logs copied to clipboard')),
    );
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _logger.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _exportLogs() {
    // Simple export simulation
    final logText = _logger.logs
        .map((log) =>
            '[${log.timestamp.toIso8601String()}] ${log.level.name.toUpperCase()}: ${log.message}')
        .join('\n');

    Clipboard.setData(ClipboardData(text: logText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Logs exported to clipboard (ready for file save)')),
    );
  }
}
