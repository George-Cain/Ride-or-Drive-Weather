/// Async operation optimization utilities
/// Provides patterns for efficient async/await handling and Future management
library;

import 'dart:async';
import 'logging_utils.dart';

/// Utility class for optimizing async operations
class AsyncUtils {
  /// Execute multiple async operations with timeout and error handling
  static Future<List<T?>> executeParallel<T>({
    required List<Future<T> Function()> operations,
    Duration timeout = const Duration(seconds: 30),
    bool failFast = false,
    String? operationName,
  }) async {
    try {
      final futures = operations.map((op) => op().timeout(timeout)).toList();
      
      if (failFast) {
        // Fail fast - if any operation fails, all fail
        final results = await Future.wait(futures);
        return results;
      } else {
        // Settle all - collect both successes and failures
        final results = await Future.wait(
            futures.map((future) => future.then<T?>((value) => value).catchError((error, stackTrace) {
              LoggingUtils.logError('Operation failed', error, stackTrace);
              return null;
            })),
          );
        return results;
      }
    } catch (e) {
      if (operationName != null) {
        LoggingUtils.logError('Parallel execution failed for $operationName', e);
      }
      rethrow;
    }
  }

  /// Execute async operation with retry logic and exponential backoff
  static Future<T?> executeWithRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    Duration? timeout,
    String? operationName,
  }) async {
    int attempt = 0;
    Duration currentDelay = initialDelay;

    while (attempt <= maxRetries) {
      try {
        final future = operation();
        final result = timeout != null ? await future.timeout(timeout) : await future;
        
        if (operationName != null && attempt > 0) {
          LoggingUtils.logDebug('$operationName succeeded on attempt ${attempt + 1}');
        }
        
        return result;
      } catch (e) {
        attempt++;
        
        if (attempt > maxRetries) {
          if (operationName != null) {
            LoggingUtils.logError('$operationName failed after $maxRetries retries', e);
          }
          return null;
        }
        
        if (operationName != null) {
          LoggingUtils.logWarning('$operationName failed on attempt $attempt, retrying in ${currentDelay.inMilliseconds}ms');
        }
        
        await Future.delayed(currentDelay);
        currentDelay = Duration(
          milliseconds: (currentDelay.inMilliseconds * backoffMultiplier).round(),
        );
      }
    }
    
    return null;
  }

  /// Execute async operation with circuit breaker pattern
  static Future<T?> executeWithCircuitBreaker<T>({
    required Future<T> Function() operation,
    required String circuitName,
    int failureThreshold = 5,
    Duration resetTimeout = const Duration(minutes: 1),
    String? operationName,
  }) async {
    final circuit = _CircuitBreaker.getInstance(circuitName, failureThreshold, resetTimeout);
    
    if (circuit.isOpen) {
      if (operationName != null) {
        LoggingUtils.logWarning('Circuit breaker is open for $operationName');
      }
      return null;
    }
    
    try {
      final result = await operation();
      circuit.recordSuccess();
      return result;
    } catch (e) {
      circuit.recordFailure();
      if (operationName != null) {
        LoggingUtils.logError('$operationName failed, circuit breaker updated', e);
      }
      rethrow;
    }
  }

  /// Batch async operations to reduce overhead
  static Future<List<T>> executeBatch<T>({
    required List<Future<T> Function()> operations,
    int batchSize = 5,
    Duration delayBetweenBatches = const Duration(milliseconds: 100),
    String? operationName,
  }) async {
    final results = <T>[];
    
    for (int i = 0; i < operations.length; i += batchSize) {
      final batch = operations.skip(i).take(batchSize).toList();
      final batchFutures = batch.map((op) => op()).toList();
      
      try {
        final batchResults = await Future.wait(batchFutures);
        results.addAll(batchResults);
        
        if (operationName != null) {
          LoggingUtils.logDebug('$operationName: completed batch ${(i ~/ batchSize) + 1}');
        }
        
        // Add delay between batches to prevent overwhelming the system
        if (i + batchSize < operations.length) {
          await Future.delayed(delayBetweenBatches);
        }
      } catch (e) {
        if (operationName != null) {
          LoggingUtils.logError('$operationName: batch ${(i ~/ batchSize) + 1} failed', e);
        }
        rethrow;
      }
    }
    
    return results;
  }

  /// Create a debounced async operation
  static Future<T?> Function() debounceAsync<T>(
    Future<T> Function() operation,
    Duration delay,
  ) {
    Timer? timer;
    Completer<T?>? completer;
    
    return () {
      timer?.cancel();
      completer?.complete(null);
      
      completer = Completer<T?>();
      timer = Timer(delay, () async {
        try {
          final result = await operation();
          if (!completer!.isCompleted) {
            completer!.complete(result);
          }
        } catch (e) {
          if (!completer!.isCompleted) {
            completer!.complete(null);
          }
        }
      });
      
      return completer!.future;
    };
  }

  /// Create a throttled async operation
  static Future<T?> Function() throttleAsync<T>(
    Future<T> Function() operation,
    Duration interval,
  ) {
    DateTime? lastExecution;
    
    return () async {
      final now = DateTime.now();
      
      if (lastExecution != null && 
          now.difference(lastExecution!).inMilliseconds < interval.inMilliseconds) {
        return null;
      }
      
      lastExecution = now;
      return await operation();
    };
  }
}

/// Circuit breaker implementation for async operations
class _CircuitBreaker {
  static final Map<String, _CircuitBreaker> _instances = {};
  
  final String name;
  final int failureThreshold;
  final Duration resetTimeout;
  
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  bool _isOpen = false;
  
  _CircuitBreaker._(this.name, this.failureThreshold, this.resetTimeout);
  
  static _CircuitBreaker getInstance(String name, int failureThreshold, Duration resetTimeout) {
    return _instances.putIfAbsent(
      name,
      () => _CircuitBreaker._(name, failureThreshold, resetTimeout),
    );
  }
  
  bool get isOpen {
    if (_isOpen && _lastFailureTime != null) {
      final now = DateTime.now();
      if (now.difference(_lastFailureTime!).compareTo(resetTimeout) >= 0) {
        _isOpen = false;
        _failureCount = 0;
        LoggingUtils.logDebug('Circuit breaker $name reset after timeout');
      }
    }
    return _isOpen;
  }
  
  void recordSuccess() {
    _failureCount = 0;
    _isOpen = false;
  }
  
  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    
    if (_failureCount >= failureThreshold) {
      _isOpen = true;
      LoggingUtils.logWarning('Circuit breaker $name opened after $failureThreshold failures');
    }
  }
}

/// Mixin for classes that need optimized async operations
mixin AsyncOptimizationMixin {
  /// Execute multiple async operations in parallel with error handling
  Future<List<T?>> executeParallel<T>({
    required List<Future<T> Function()> operations,
    Duration timeout = const Duration(seconds: 30),
    bool failFast = false,
    String? operationName,
  }) {
    return AsyncUtils.executeParallel<T>(
      operations: operations,
      timeout: timeout,
      failFast: failFast,
      operationName: operationName,
    );
  }

  /// Execute async operation with retry logic
  Future<T?> executeWithRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    Duration? timeout,
    String? operationName,
  }) {
    return AsyncUtils.executeWithRetry<T>(
      operation: operation,
      maxRetries: maxRetries,
      initialDelay: initialDelay,
      backoffMultiplier: backoffMultiplier,
      timeout: timeout,
      operationName: operationName,
    );
  }

  /// Execute async operation with circuit breaker
  Future<T?> executeWithCircuitBreaker<T>({
    required Future<T> Function() operation,
    required String circuitName,
    int failureThreshold = 5,
    Duration resetTimeout = const Duration(minutes: 1),
    String? operationName,
  }) {
    return AsyncUtils.executeWithCircuitBreaker<T>(
      operation: operation,
      circuitName: circuitName,
      failureThreshold: failureThreshold,
      resetTimeout: resetTimeout,
      operationName: operationName,
    );
  }
}