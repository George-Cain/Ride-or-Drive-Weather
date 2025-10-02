/// Centralized logging utilities
/// Provides consistent logging patterns across the application
library;

import 'package:flutter/foundation.dart';

/// Utility class for consistent logging operations
class LoggingUtils {
  // Private constructor to prevent instantiation
  const LoggingUtils._();

  /// Log debug information with timestamp
  static void logDebug(String message) {
    if (kDebugMode) {
      debugPrint('DEBUG: $message');
    }
  }

  /// Log error information with optional error details and stack trace
  static void logError(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('ERROR: $message');
      if (error != null) {
        debugPrint('Error details: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Log warning information
  static void logWarning(String message) {
    if (kDebugMode) {
      debugPrint('WARNING: $message');
    }
  }

  /// Log section headers with consistent formatting
  static void logSection(String sectionName) {
    if (kDebugMode) {
      debugPrint('=== $sectionName ===');
    }
  }

  /// Log timestamped events
  static void logTimestamp(String message) {
    if (kDebugMode) {
      debugPrint('$message - Timestamp: ${DateTime.now().toIso8601String()}');
    }
  }

  /// Log initialization events
  static void logInitialization(String serviceName) {
    if (kDebugMode) {
      logSection('INITIALIZING ${serviceName.toUpperCase()}');
      logTimestamp('$serviceName initialization started');
    }
  }

  /// Log completion events
  static void logCompletion(String operationName) {
    if (kDebugMode) {
      debugPrint('$operationName completed successfully');
    }
  }

  /// Log critical errors with section formatting
  static void logCriticalError(String operation, Object error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      logSection('CRITICAL ERROR IN ${operation.toUpperCase()}');
      debugPrint('Error: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Log task execution with details
  static void logTaskExecution(String taskName, Map<String, dynamic>? inputData) {
    if (kDebugMode) {
      logSection('EXECUTING ${taskName.toUpperCase()}');
      debugPrint('Task: $taskName');
      if (inputData != null) {
        debugPrint('Input Data: $inputData');
      }
      logTimestamp('Task execution started');
    }
  }

  /// Log permission status
  static void logPermissionStatus(String permissionType, bool granted) {
    if (kDebugMode) {
      debugPrint('$permissionType permission: ${granted ? "GRANTED" : "DENIED"}');
    }
  }

  /// Log weather data
  static void logWeatherData(String context, double temperature, String weatherCode) {
    if (kDebugMode) {
      debugPrint('$context: $temperature°C, code: $weatherCode');
    }
  }
}