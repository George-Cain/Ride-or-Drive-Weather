import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'logging_utils.dart';

/// Request deduplication system to prevent duplicate API calls
class RequestDeduplicator {
  static final Map<String, Completer<dynamic>> _pendingRequests = {};
  static final Map<String, DateTime> _requestTimestamps = {};
  static const Duration _requestTimeout = Duration(seconds: 30);
  
  /// Generate unique key for request
  static String _generateRequestKey(String url, [Map<String, dynamic>? params]) {
    final combined = url + (params != null ? jsonEncode(params) : '');
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
  
  /// Execute request with deduplication
  static Future<T> executeRequest<T>(
    String url,
    Future<T> Function() requestFunction, {
    Map<String, dynamic>? params,
    Duration? timeout,
  }) async {
    final requestKey = _generateRequestKey(url, params);
    final requestTimeout = timeout ?? _requestTimeout;
    
    // Check if request is already pending
    if (_pendingRequests.containsKey(requestKey)) {
      LoggingUtils.logDebug('Deduplicating request for key: $requestKey');
      
      // Check if pending request has timed out
      final timestamp = _requestTimestamps[requestKey];
      if (timestamp != null && DateTime.now().difference(timestamp) > requestTimeout) {
        LoggingUtils.logWarning('Pending request timed out, creating new request: $requestKey');
        _cleanupRequest(requestKey);
      } else {
        // Wait for existing request to complete
        try {
          return await _pendingRequests[requestKey]!.future as T;
        } catch (e) {
          LoggingUtils.logError('Deduplicated request failed', e);
          _cleanupRequest(requestKey);
          rethrow;
        }
      }
    }
    
    // Create new request
    final completer = Completer<T>();
    _pendingRequests[requestKey] = completer as Completer<dynamic>;
    _requestTimestamps[requestKey] = DateTime.now();
    
    LoggingUtils.logDebug('Starting new request for key: $requestKey');
    
    try {
      // Execute the actual request with timeout
      final result = await requestFunction().timeout(requestTimeout);
      
      // Complete all waiting requests
      if (!completer.isCompleted) {
        completer.complete(result);
      }
      
      LoggingUtils.logDebug('Request completed successfully for key: $requestKey');
      return result;
    } catch (e) {
      // Fail all waiting requests
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      
      LoggingUtils.logError('Request failed for key: $requestKey', e);
      rethrow;
    } finally {
      // Clean up request tracking
      _cleanupRequest(requestKey);
    }
  }
  
  /// Clean up completed or failed request
  static void _cleanupRequest(String requestKey) {
    _pendingRequests.remove(requestKey);
    _requestTimestamps.remove(requestKey);
  }
  
  /// Cancel all pending requests
  static void cancelAllRequests() {
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Request cancelled'));
      }
    }
    
    _pendingRequests.clear();
    _requestTimestamps.clear();
    
    LoggingUtils.logDebug('All pending requests cancelled');
  }
  
  /// Get statistics about pending requests
  static Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final activeRequests = _pendingRequests.length;
    final oldRequests = _requestTimestamps.values
        .where((timestamp) => now.difference(timestamp) > _requestTimeout)
        .length;
    
    return {
      'activeRequests': activeRequests,
      'oldRequests': oldRequests,
      'totalTracked': _requestTimestamps.length,
    };
  }
  
  /// Clean up old request tracking data
  static void cleanup() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    for (final entry in _requestTimestamps.entries) {
      if (now.difference(entry.value) > _requestTimeout * 2) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _cleanupRequest(key);
    }
    
    if (keysToRemove.isNotEmpty) {
      LoggingUtils.logDebug('Cleaned up ${keysToRemove.length} old request entries');
    }
  }
}