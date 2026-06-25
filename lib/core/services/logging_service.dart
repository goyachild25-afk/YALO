import 'package:flutter/foundation.dart';

/// Centralized logging service for error tracking and debugging
class LoggingService {
  static const String _prefix = '[ServiciosYa]';

  /// Log info messages
  static void info(String message, [dynamic error]) {
    final timestamp = DateTime.now().toIso8601String();
    final log = '$_prefix ℹ️  [$timestamp] $message';
    if (kDebugMode) {
      print(log);
    }
    if (error != null) {
      print('  └─ Details: $error');
    }
  }

  /// Log warning messages
  static void warning(String message, [dynamic error]) {
    final timestamp = DateTime.now().toIso8601String();
    final log = '$_prefix ⚠️  [$timestamp] $message';
    if (kDebugMode) {
      print(log);
    }
    if (error != null) {
      print('  └─ Details: $error');
    }
    // TODO: Send to Sentry or Firebase Crashlytics
  }

  /// Log error messages (CRITICAL)
  static void error(String message, dynamic error, [StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    final log = '$_prefix ❌ [$timestamp] $message';
    if (kDebugMode) {
      print(log);
      print('  └─ Error: $error');
      if (stackTrace != null) {
        print('  └─ StackTrace:\n$stackTrace');
      }
    }
    // TODO: Send to Sentry or Firebase Crashlytics with full context
  }

  /// Log success messages
  static void success(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final log = '$_prefix ✅ [$timestamp] $message';
    if (kDebugMode) {
      print(log);
    }
  }

  /// Log network requests
  static void network(String method, String endpoint, {int? statusCode, dynamic error}) {
    final timestamp = DateTime.now().toIso8601String();
    if (error == null) {
      final log = '$_prefix 🌐 [$timestamp] $method $endpoint → $statusCode';
      if (kDebugMode) print(log);
    } else {
      final log = '$_prefix 🌐 [$timestamp] $method $endpoint ❌ $statusCode';
      if (kDebugMode) {
        print(log);
        print('  └─ Error: $error');
      }
    }
  }

  /// Log performance metrics
  static void performance(String operation, Duration duration) {
    final ms = duration.inMilliseconds;
    final log = '$_prefix ⏱️  [$operation] ${ms}ms';
    if (kDebugMode) print(log);

    // Warn if slow
    if (ms > 1000) {
      warning('$operation took ${ms}ms (slow)', null);
    }
  }

  /// Log app lifecycle events
  static void lifecycle(String event) {
    final timestamp = DateTime.now().toIso8601String();
    final log = '$_prefix 🔄 [$timestamp] Lifecycle: $event';
    if (kDebugMode) print(log);
  }

  /// Batch errors for reporting
  static final List<ErrorReport> _errorBatch = [];

  static void addError(String context, dynamic error, [StackTrace? stackTrace]) {
    _errorBatch.add(
      ErrorReport(
        timestamp: DateTime.now(),
        context: context,
        message: error.toString(),
        stackTrace: stackTrace?.toString(),
      ),
    );

    // Auto-flush if batch gets too large
    if (_errorBatch.length > 50) {
      flushErrors();
    }
  }

  static Future<void> flushErrors() async {
    if (_errorBatch.isEmpty) return;

    // TODO: Send batch to backend/Sentry
    _errorBatch.clear();
  }
}

/// Error report model
class ErrorReport {
  final DateTime timestamp;
  final String context;
  final String message;
  final String? stackTrace;

  ErrorReport({
    required this.timestamp,
    required this.context,
    required this.message,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'context': context,
    'message': message,
    'stackTrace': stackTrace,
  };
}
