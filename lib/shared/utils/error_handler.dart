/// Centralized error handling utilities
/// Provides consistent error handling patterns across the application
library;

import 'logging_utils.dart';

/// Utility class for consistent error handling
class ErrorHandler {
  /// Execute an async operation with standardized error handling
  static Future<T?> executeAsync<T>({
    required Future<T> Function() operation,
    required String operationName,
    Function(String)? onError,
    Function(String)? onSuccess,
    bool logStackTrace = false,
  }) async {
    try {
      final result = await operation();
      if (onSuccess != null) {
        onSuccess('$operationName completed successfully');
      }
      return result;
    } catch (e, stackTrace) {
      final errorMessage = '$operationName failed: $e';
      
      // Log error to centralized logging system
      LoggingUtils.logError(errorMessage, logStackTrace ? stackTrace : null);

      if (onError != null) {
        onError(errorMessage);
      }

      return null;
    }
  }

  /// Execute a sync operation with standardized error handling
  static T? executeSync<T>({
    required T Function() operation,
    required String operationName,
    Function(String)? onError,
    Function(String)? onSuccess,
  }) {
    try {
      final result = operation();
      if (onSuccess != null) {
        onSuccess('$operationName completed successfully');
      }
      return result;
    } catch (e) {
      final errorMessage = '$operationName failed: $e';
      
      // Log error to centralized logging system
      LoggingUtils.logError(errorMessage);

      if (onError != null) {
        onError(errorMessage);
      }

      return null;
    }
  }
}

/// Mixin for classes that need consistent error handling
mixin ErrorHandlingMixin {
  /// Execute async operation with error handling
  Future<T?> handleAsync<T>({
    required Future<T> Function() operation,
    required String operationName,
    Function(String)? onError,
    Function(String)? onSuccess,
    bool logStackTrace = false,
  }) {
    return ErrorHandler.executeAsync<T>(
      operation: operation,
      operationName: operationName,
      onError: onError,
      onSuccess: onSuccess,
      logStackTrace: logStackTrace,
    );
  }

  /// Execute sync operation with error handling
  T? handleSync<T>({
    required T Function() operation,
    required String operationName,
    Function(String)? onError,
    Function(String)? onSuccess,
  }) {
    return ErrorHandler.executeSync<T>(
      operation: operation,
      operationName: operationName,
      onError: onError,
      onSuccess: onSuccess,
    );
  }

  /// Log debug message
  void logDebug(String message) => LoggingUtils.logDebug(message);

  /// Log error message
  void logError(String message, [Object? error, StackTrace? stackTrace]) {
    LoggingUtils.logError(message, error, stackTrace);
  }
}
