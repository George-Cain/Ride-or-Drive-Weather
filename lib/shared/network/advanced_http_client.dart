import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/logging_utils.dart';
import '../utils/network_cache.dart';
import '../utils/request_deduplicator.dart';
import '../service_manager.dart';

/// Advanced HTTP client with enhanced caching, connection pooling, and performance optimizations
class AdvancedHttpClient {
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _retryDelay = Duration(milliseconds: 500);
  static const int _maxRetries = 3;
  static const int _maxConcurrentRequests = 10;

  // Connection pool management
  static final Map<String, http.Client> _connectionPool = {};
  static final Map<String, DateTime> _connectionLastUsed = {};
  static const Duration _connectionTimeout = Duration(minutes: 5);

  // Request queue management
  static final List<_QueuedRequest> _requestQueue = [];
  static int _activeRequests = 0;
  static final StreamController<Map<String, dynamic>> _metricsController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Performance metrics
  static int _totalRequests = 0;
  static int _successfulRequests = 0;
  static int _failedRequests = 0;
  static int _cachedRequests = 0;
  static int _queuedRequests = 0;
  static final List<int> _responseTimes = [];

  /// Enhanced GET request with advanced caching and connection pooling
  static Future<Map<String, dynamic>> get(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
    bool useCache = true,
    bool allowOffline = true,
    CachePriority cachePriority = CachePriority.normal,
    bool bypassQueue = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    _totalRequests++;

    try {
      final result = await _executeRequest(
        url: url,
        headers: headers,
        queryParams: queryParams,
        timeout: timeout ?? _defaultTimeout,
        useCache: useCache,
        allowOffline: allowOffline,
        cachePriority: cachePriority,
        bypassQueue: bypassQueue,
      );

      _successfulRequests++;
      _recordResponseTime(stopwatch.elapsedMilliseconds);
      _emitMetrics();

      return result;
    } catch (e) {
      _failedRequests++;
      _emitMetrics();
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Execute request with queue management
  static Future<Map<String, dynamic>> _executeRequest({
    required String url,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    required Duration timeout,
    required bool useCache,
    required bool allowOffline,
    required CachePriority cachePriority,
    required bool bypassQueue,
  }) async {
    // Check cache first if enabled
    if (useCache) {
      final cachedData = await NetworkCache.getCachedData(url, queryParams);
      if (cachedData != null) {
        _cachedRequests++;
        LoggingUtils.logDebug('Cache hit for: $url');
        return cachedData;
      }
    }

    // Check for duplicate requests
    final deduplicatedResult =
        await RequestDeduplicator.executeRequest<Map<String, dynamic>>(
      url,
      () => _performHttpRequest(
        url: url,
        headers: headers,
        queryParams: queryParams,
        timeout: timeout,
        useCache: useCache,
        allowOffline: allowOffline,
        cachePriority: cachePriority,
        bypassQueue: bypassQueue,
      ),
      params: queryParams,
      timeout: timeout,
    );

    return deduplicatedResult;
  }

  /// Perform the actual HTTP request with connection pooling
  static Future<Map<String, dynamic>> _performHttpRequest({
    required String url,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    required Duration timeout,
    required bool useCache,
    required bool allowOffline,
    required CachePriority cachePriority,
    required bool bypassQueue,
  }) async {
    // Queue management for non-priority requests
    if (!bypassQueue && _activeRequests >= _maxConcurrentRequests) {
      return await _queueRequest(
        url: url,
        headers: headers,
        queryParams: queryParams,
        timeout: timeout,
        useCache: useCache,
        allowOffline: allowOffline,
        cachePriority: cachePriority,
      );
    }

    _activeRequests++;

    try {
      final uri = _buildUri(url, queryParams);
      final client = _getOrCreateClient(uri.host);

      final defaultHeaders = {
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'User-Agent': 'RideOrDrive/1.0 (Advanced HTTP Client)',
        ...?headers,
      };

      Exception? lastException;

      for (int attempt = 1; attempt <= _maxRetries; attempt++) {
        try {
          LoggingUtils.logDebug('HTTP GET attempt $attempt: $uri');

          final response =
              await client.get(uri, headers: defaultHeaders).timeout(timeout);

          if (response.statusCode == 200) {
            final responseData =
                jsonDecode(response.body) as Map<String, dynamic>;

            // Cache successful response
            if (useCache) {
              await NetworkCache.setCachedData(
                url,
                responseData,
                queryParams,
              );
            }

            LoggingUtils.logDebug('HTTP GET successful: $uri');
            return responseData;
          } else if (response.statusCode >= 400 && response.statusCode < 500) {
            throw HttpException(
                'HTTP ${response.statusCode}: ${response.reasonPhrase}');
          } else {
            throw HttpException(
                'HTTP ${response.statusCode}: ${response.reasonPhrase}');
          }
        } catch (e) {
          lastException = e is Exception ? e : Exception(e.toString());
          LoggingUtils.logWarning('HTTP GET attempt $attempt failed: $e');

          if (e is HttpException && e.message.contains('4')) {
            break;
          }

          if (attempt < _maxRetries) {
            await Future.delayed(_retryDelay * attempt);
          }
        }
      }

      // Try stale cache as fallback
      if (allowOffline && useCache) {
        final staleData = await _getStaleCache(url, queryParams);
        if (staleData != null) {
          LoggingUtils.logWarning('Returning stale cache data: $url');
          return staleData;
        }
      }

      throw lastException ??
          Exception('Request failed after $_maxRetries attempts');
    } finally {
      _activeRequests--;
      _processQueue();
    }
  }

  /// Queue request when at capacity
  static Future<Map<String, dynamic>> _queueRequest({
    required String url,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    required Duration timeout,
    required bool useCache,
    required bool allowOffline,
    required CachePriority cachePriority,
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    final queuedRequest = _QueuedRequest(
      url: url,
      headers: headers,
      queryParams: queryParams,
      timeout: timeout,
      useCache: useCache,
      allowOffline: allowOffline,
      cachePriority: cachePriority,
      completer: completer,
    );

    _requestQueue.add(queuedRequest);
    _queuedRequests++;

    LoggingUtils.logDebug(
        'Request queued: $url (queue size: ${_requestQueue.length})');

    return completer.future;
  }

  /// Process queued requests
  static void _processQueue() {
    while (
        _requestQueue.isNotEmpty && _activeRequests < _maxConcurrentRequests) {
      final request = _requestQueue.removeAt(0);

      _performHttpRequest(
        url: request.url,
        headers: request.headers,
        queryParams: request.queryParams,
        timeout: request.timeout,
        useCache: request.useCache,
        allowOffline: request.allowOffline,
        cachePriority: request.cachePriority,
        bypassQueue: true,
      ).then((result) {
        request.completer.complete(result);
      }).catchError((error) {
        request.completer.completeError(error);
      });
    }
  }

  /// Get or create HTTP client for connection pooling
  static http.Client _getOrCreateClient(String host) {
    final now = DateTime.now();

    // Clean up old connections
    _connectionLastUsed.removeWhere((key, lastUsed) {
      if (now.difference(lastUsed) > _connectionTimeout) {
        _connectionPool[key]?.close();
        _connectionPool.remove(key);
        return true;
      }
      return false;
    });

    // Get or create client for host
    if (!_connectionPool.containsKey(host)) {
      _connectionPool[host] = http.Client();
      LoggingUtils.logDebug('Created new HTTP client for: $host');
    }

    _connectionLastUsed[host] = now;
    return _connectionPool[host]!;
  }

  /// Build URI with query parameters
  static Uri _buildUri(String url, Map<String, dynamic>? queryParams) {
    final uri = Uri.parse(url);

    if (queryParams == null || queryParams.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...queryParams.map((key, value) => MapEntry(key, value.toString())),
    });
  }

  /// Get stale cache data
  static Future<Map<String, dynamic>?> _getStaleCache(
    String url,
    Map<String, dynamic>? params,
  ) async {
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

  /// Record response time for metrics
  static void _recordResponseTime(int milliseconds) {
    _responseTimes.add(milliseconds);

    // Keep only last 100 response times
    if (_responseTimes.length > 100) {
      _responseTimes.removeAt(0);
    }
  }

  /// Emit performance metrics
  static void _emitMetrics() {
    final metrics = getPerformanceMetrics();
    _metricsController.add(metrics);
  }

  /// Get performance metrics stream
  static Stream<Map<String, dynamic>> get metricsStream =>
      _metricsController.stream;

  /// Get comprehensive performance metrics
  static Map<String, dynamic> getPerformanceMetrics() {
    final avgResponseTime = _responseTimes.isNotEmpty
        ? _responseTimes.reduce((a, b) => a + b) / _responseTimes.length
        : 0.0;

    final successRate =
        _totalRequests > 0 ? (_successfulRequests / _totalRequests * 100) : 0.0;

    final cacheHitRate =
        _totalRequests > 0 ? (_cachedRequests / _totalRequests * 100) : 0.0;

    return {
      'requests': {
        'total': _totalRequests,
        'successful': _successfulRequests,
        'failed': _failedRequests,
        'cached': _cachedRequests,
        'queued': _queuedRequests,
        'active': _activeRequests,
      },
      'performance': {
        'avgResponseTime': avgResponseTime.round(),
        'successRate': successRate.toStringAsFixed(1),
        'cacheHitRate': cacheHitRate.toStringAsFixed(1),
      },
      'connections': {
        'poolSize': _connectionPool.length,
        'queueSize': _requestQueue.length,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Preload data for better performance
  static Future<void> preloadData(List<String> urls) async {
    final futures = urls.map((url) => get(
          url,
          cachePriority: CachePriority.high,
          bypassQueue: false,
        ).catchError((e) {
          LoggingUtils.logWarning('Preload failed for $url: $e');
          return <String, dynamic>{}; // Return empty map on error
        }));

    await Future.wait(futures);
    LoggingUtils.logDebug('Preloaded ${urls.length} URLs');
  }

  /// Warm up connections to hosts
  static Future<void> warmupConnections(List<String> hosts) async {
    for (final host in hosts) {
      _getOrCreateClient(host);
    }
    LoggingUtils.logDebug('Warmed up connections to ${hosts.length} hosts');
  }

  /// Clear all resources
  static Future<void> dispose() async {
    // Close all connections
    for (final client in _connectionPool.values) {
      client.close();
    }
    _connectionPool.clear();
    _connectionLastUsed.clear();

    // Clear queue
    for (final request in _requestQueue) {
      request.completer.completeError(Exception('Client disposed'));
    }
    _requestQueue.clear();

    // Close metrics stream
    await _metricsController.close();

    // Clear cache and deduplicator
    await NetworkCache.clearCache();
    RequestDeduplicator.cancelAllRequests();

    LoggingUtils.logDebug('Advanced HTTP client disposed');
  }

  /// Reset metrics
  static void resetMetrics() {
    _totalRequests = 0;
    _successfulRequests = 0;
    _failedRequests = 0;
    _cachedRequests = 0;
    _queuedRequests = 0;
    _responseTimes.clear();
    LoggingUtils.logDebug('HTTP client metrics reset');
  }
}

/// Cache priority levels
enum CachePriority {
  low,
  normal,
  high,
}

/// Queued request data structure
class _QueuedRequest {
  final String url;
  final Map<String, String>? headers;
  final Map<String, dynamic>? queryParams;
  final Duration timeout;
  final bool useCache;
  final bool allowOffline;
  final CachePriority cachePriority;
  final Completer<Map<String, dynamic>> completer;

  _QueuedRequest({
    required this.url,
    this.headers,
    this.queryParams,
    required this.timeout,
    required this.useCache,
    required this.allowOffline,
    required this.cachePriority,
    required this.completer,
  });
}

/// Extension for NetworkCache to support cache priorities
extension NetworkCacheExtension on NetworkCache {
  static Future<void> setCachedData(
    String url,
    Map<String, dynamic>? params,
    Map<String, dynamic> data, {
    CachePriority priority = CachePriority.normal,
  }) async {
    await NetworkCache.setCachedData(url, data, params);
  }
}
