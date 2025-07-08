import 'package:flutter/material.dart';

/// Simple in-app logging system for debugging P2P connections
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  final List<LogEntry> _logs = [];
  final int maxLogs = 100;

  // Callbacks for UI updates
  Function()? onLogAdded;

  void log(String message, [LogLevel level = LogLevel.info]) {
    final entry = LogEntry(
      message: message,
      level: level,
      timestamp: DateTime.now(),
    );

    _logs.insert(0, entry); // Add to front

    // Keep only the latest logs
    if (_logs.length > maxLogs) {
      _logs.removeRange(maxLogs, _logs.length);
    }

    // Print to console as well
    final prefix = _getLevelPrefix(level);
    print('$prefix $message');

    // Notify UI listeners
    onLogAdded?.call();
  }

  void info(String message) => log(message, LogLevel.info);
  void warning(String message) => log(message, LogLevel.warning);
  void error(String message) => log(message, LogLevel.error);
  void debug(String message) => log(message, LogLevel.debug);
  void success(String message) => log(message, LogLevel.success);

  String _getLevelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return '📄';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.debug:
        return '🐛';
      case LogLevel.success:
        return '✅';
    }
  }

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void clear() {
    _logs.clear();
    onLogAdded?.call();
  }
}

enum LogLevel {
  info,
  warning,
  error,
  debug,
  success,
}

class LogEntry {
  final String message;
  final LogLevel level;
  final DateTime timestamp;

  LogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
  });

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  Color get color {
    switch (level) {
      case LogLevel.info:
        return Colors.blue.shade700;
      case LogLevel.warning:
        return Colors.orange.shade700;
      case LogLevel.error:
        return Colors.red.shade700;
      case LogLevel.debug:
        return Colors.purple.shade700;
      case LogLevel.success:
        return Colors.green.shade700;
    }
  }

  String get prefix {
    switch (level) {
      case LogLevel.info:
        return '📄';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.debug:
        return '🐛';
      case LogLevel.success:
        return '✅';
    }
  }
}
