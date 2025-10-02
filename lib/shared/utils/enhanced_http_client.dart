import 'dart:convert';
import 'package:http/http.dart' as http;
import 'network_cache.dart';
import 'request_deduplicator.dart';
import 'logging_utils.dart';
import '../service_manager.dart';

/// Enhanced HTTP client with caching, deduplication, and offline support
class EnhancedHttpClient {
  static const Duration _defaultTimeout = Duration(seconds: 15);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  
  /// Make GET request with advanced optimizations
  static Future<Map<String, dynamic>> get(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
    bool useCache = true,
    bool allowOffline = true,
  }) async {
    final requestTimeout = timeout ?? _defaultTimeout;
    
    return await RequestDeduplicator.executeRequest<Map<String, dynamic>>(
      url,
      () => _performGetRequest(
        url,
        headers: headers,
        queryParams: queryParams,
        timeout: requestTimeout,
        useCache: useCache,
        allowOffline: allowOffline,
      ),
      params: queryParams,
      timeout: requestTimeout,
    );
  }
  
  /// Internal method to perform the actual GET request
  static Future<Map<String, dynamic>> _performGetRequest(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    required Duration timeout,
    required bool useCache,
    required bool allowOffline,
  }) async {
    // Build final URL with query parameters
    final uri = _buildUri(url, queryParams);
    final finalUrl = uri.toString();
    
    // Try cache first if enabled
    if (useCache) {
      final cachedData = await NetworkCache.getCachedData(finalUrl, queryParams);
      if (cachedData != null) {
        LoggingUtils.logDebug('Returning cached data for: $finalUrl');
        return cachedData;
      }
    }
    
    // Check network connectivity
    final isOnline = await NetworkCache.isOnline();
    if (!isOnline) {
      if (allowOffline) {
        // Try to return stale cache data in offline mode
        final staleData = await _getStaleCache(finalUrl, queryParams);
        if (staleData != null) {
          LoggingUtils.logDebug('Returning stale cache data (offline): $finalUrl');
          return staleData;
        }
      }
      throw Exception('No internet connection and no cached data available');
    }
    
    // Perform network request with retries
    Map<String, dynamic>? responseData;
    Exception? lastException;
    
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        LoggingUtils.logDebug('HTTP GET attempt $attempt/$_maxRetries: $finalUrl');
        
        final response = await http.get(
          uri,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'RideOrDrive/1.0',
            ...?headers,
          },
        ).timeout(timeout);
        
        if (response.statusCode == 200) {
          responseData = jsonDecode(response.body) as Map<String, dynamic>;
          
          // Cache successful response
          if (useCache) {
            await NetworkCache.setCachedData(finalUrl, responseData, queryParams);
          }
          
          LoggingUtils.logDebug('HTTP GET successful: $finalUrl');
          return responseData;
        } else if (response.statusCode >= 400 && response.statusCode < 500) {
          // Client errors - don't retry
          throw HttpException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
        } else {
          // Server errors - retry
          throw HttpException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        LoggingUtils.logWarning('HTTP GET attempt $attempt failed: $e');
        
        // Don't retry on client errors or timeout
        if (e is HttpException && e.message.contains('4')) {
          break;
        }
        
        // Wait before retry (except on last attempt)
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
        }
      }
    }
    
    // All retries failed - try stale cache as last resort
    if (allowOffline && useCache) {
      final staleData = await _getStaleCache(finalUrl, queryParams);
      if (staleData != null) {
        LoggingUtils.logWarning('Returning stale cache data after network failure: $finalUrl');
        return staleData;
      }
    }
    
    // No fallback available
    throw lastException ?? Exception('Request failed after $_maxRetries attempts');
  }
  
  /// Build URI with query parameters
  static Uri _buildUri(String url, Map<String, dynamic>? queryParams) {
    final uri = Uri.parse(url);
    
    if (queryParams == null || queryParams.isEmpty) {
      return uri;
    }
    
    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    
    final separator = uri.query.isEmpty ? '?' : '&';
    final finalUrl = '$url$separator$queryString';
    
    return Uri.parse(finalUrl);
  }
  
  /// Get stale cache data (ignoring expiration)
  static Future<Map<String, dynamic>?> _getStaleCache(String url, Map<String, dynamic>? params) async {
    try {
      final cacheKey = NetworkCache.generateCacheKey(url, params);
      final prefsService = ServiceManager.instance.preferencesService;
      
      final cachedJson = await prefsService.getString('${cacheKey}_data');
      if (cachedJson != null) {
        return jsonDecode(cachedJson) as Map<String, dynamic>;
      }
    } catch (e) {
      LoggingUtils.logError('Error reading stale cache', e);
    }
    return null;
  }
  
  /// Clear all caches and pending requests
  static Future<void> clearAll() async {
    await NetworkCache.clearCache();
    RequestDeduplicator.cancelAllRequests();
    LoggingUtils.logDebug('Enhanced HTTP client cleared');
  }
  
  /// Get comprehensive statistics
  static Future<Map<String, dynamic>> getStats() async {
    final cacheStats = NetworkCache.getCacheStats();
    final requestStats = RequestDeduplicator.getStats();
    final isOnline = await NetworkCache.isOnline();
    
    return {
      'cache': cacheStats,
      'requests': requestStats,
      'connectivity': {
        'isOnline': isOnline,
        'lastCheck': DateTime.now().toIso8601String(),
      },
    };
  }
  
  /// Perform cleanup of old data
  static void cleanup() {
    RequestDeduplicator.cleanup();
    LoggingUtils.logDebug('Enhanced HTTP client cleanup completed');
  }
}

/// HTTP exception with additional context
class HttpException implements Exception {
  final String message;
  
  const HttpException(this.message);
  
  @override
  String toString() => 'HttpException: $message';
}