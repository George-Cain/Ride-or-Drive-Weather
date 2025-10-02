import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../service_manager.dart';
import 'logging_utils.dart';

/// Advanced network caching system with intelligent cache management
class NetworkCache {
  static const String _cachePrefix = 'network_cache_';
  static const Duration _defaultCacheDuration = Duration(minutes: 15);
  static const Duration _weatherCacheDuration = Duration(minutes: 10);
  static const Duration _forecastCacheDuration = Duration(minutes: 30);
  static const int _maxCacheSize = 50; // Maximum number of cached entries
  
  // Cache statistics for monitoring
  static int _cacheHits = 0;
  static int _cacheMisses = 0;
  static int _cacheEvictions = 0;
  
  /// Generate cache key from URL and parameters
  static String generateCacheKey(String url, [Map<String, dynamic>? params]) {
    final combined = url + (params != null ? jsonEncode(params) : '');
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return '$_cachePrefix${digest.toString().substring(0, 16)}';
  }
  
  /// Get cached data if available and not expired
  static Future<Map<String, dynamic>?> getCachedData(String url, [Map<String, dynamic>? params]) async {
    try {
      final cacheKey = generateCacheKey(url, params);
      final prefsService = ServiceManager.instance.preferencesService;
      
      // Get cached data and timestamp
      final cachedJson = await prefsService.getString('${cacheKey}_data');
      final cachedTimestamp = await prefsService.getInt('${cacheKey}_timestamp');
      
      if (cachedJson == null || cachedTimestamp == null) {
        _cacheMisses++;
        LoggingUtils.logDebug('Cache miss for key: $cacheKey');
        return null;
      }
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
      final cacheDuration = _getCacheDurationForUrl(url);
      
      if (DateTime.now().difference(cacheTime) > cacheDuration) {
        _cacheMisses++;
        LoggingUtils.logDebug('Cache expired for key: $cacheKey');
        // Clean up expired cache
        await _removeCacheEntry(cacheKey);
        return null;
      }
      
      _cacheHits++;
      LoggingUtils.logDebug('Cache hit for key: $cacheKey');
      return jsonDecode(cachedJson) as Map<String, dynamic>;
    } catch (e) {
      LoggingUtils.logError('Error reading from cache', e);
      _cacheMisses++;
      return null;
    }
  }
  
  /// Cache data with intelligent size management
  static Future<void> setCachedData(String url, Map<String, dynamic> data, [Map<String, dynamic>? params]) async {
    try {
      final cacheKey = generateCacheKey(url, params);
      final prefsService = ServiceManager.instance.preferencesService;
      
      // Check cache size and evict if necessary
      await _manageCacheSize();
      
      // Store data and timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await Future.wait([
        prefsService.setString('${cacheKey}_data', jsonEncode(data)),
        prefsService.setInt('${cacheKey}_timestamp', timestamp),
      ]);
      
      // Update cache index
      await _updateCacheIndex(cacheKey, timestamp);
      
      LoggingUtils.logDebug('Data cached for key: $cacheKey');
    } catch (e) {
      LoggingUtils.logError('Error writing to cache', e);
    }
  }
  
  /// Get appropriate cache duration based on URL type
  static Duration _getCacheDurationForUrl(String url) {
    if (url.contains('current=')) {
      return _weatherCacheDuration;
    } else if (url.contains('hourly=')) {
      return _forecastCacheDuration;
    }
    return _defaultCacheDuration;
  }
  
  /// Manage cache size by evicting oldest entries
  static Future<void> _manageCacheSize() async {
    try {
      final prefsService = ServiceManager.instance.preferencesService;
      final cacheIndexJson = await prefsService.getString('cache_index');
      
      if (cacheIndexJson == null) return;
      
      final cacheIndex = Map<String, int>.from(jsonDecode(cacheIndexJson));
      
      if (cacheIndex.length >= _maxCacheSize) {
        // Sort by timestamp and remove oldest entries
        final sortedEntries = cacheIndex.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));
        
        final entriesToRemove = sortedEntries.take(cacheIndex.length - _maxCacheSize + 5);
        
        for (final entry in entriesToRemove) {
          await _removeCacheEntry(entry.key);
          cacheIndex.remove(entry.key);
          _cacheEvictions++;
        }
        
        // Update cache index
        await prefsService.setString('cache_index', jsonEncode(cacheIndex));
        LoggingUtils.logDebug('Evicted ${entriesToRemove.length} cache entries');
      }
    } catch (e) {
      LoggingUtils.logError('Error managing cache size', e);
    }
  }
  
  /// Update cache index with new entry
  static Future<void> _updateCacheIndex(String cacheKey, int timestamp) async {
    try {
      final prefsService = ServiceManager.instance.preferencesService;
      final cacheIndexJson = await prefsService.getString('cache_index') ?? '{}';
      final cacheIndex = Map<String, int>.from(jsonDecode(cacheIndexJson));
      
      cacheIndex[cacheKey] = timestamp;
      await prefsService.setString('cache_index', jsonEncode(cacheIndex));
    } catch (e) {
      LoggingUtils.logError('Error updating cache index', e);
    }
  }
  
  /// Remove specific cache entry
  static Future<void> _removeCacheEntry(String cacheKey) async {
    try {
      final prefsService = ServiceManager.instance.preferencesService;
      await Future.wait([
        prefsService.remove('${cacheKey}_data'),
        prefsService.remove('${cacheKey}_timestamp'),
      ]);
    } catch (e) {
      LoggingUtils.logError('Error removing cache entry', e);
    }
  }
  
  /// Clear all cached data
  static Future<void> clearCache() async {
    try {
      final prefsService = ServiceManager.instance.preferencesService;
      final cacheIndexJson = await prefsService.getString('cache_index');
      
      if (cacheIndexJson != null) {
        final cacheIndex = Map<String, int>.from(jsonDecode(cacheIndexJson));
        
        for (final cacheKey in cacheIndex.keys) {
          await _removeCacheEntry(cacheKey);
        }
        
        await prefsService.remove('cache_index');
      }
      
      _cacheHits = 0;
      _cacheMisses = 0;
      _cacheEvictions = 0;
      
      LoggingUtils.logDebug('Cache cleared successfully');
    } catch (e) {
      LoggingUtils.logError('Error clearing cache', e);
    }
  }
  
  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    final totalRequests = _cacheHits + _cacheMisses;
    final hitRate = totalRequests > 0 ? (_cacheHits / totalRequests * 100) : 0.0;
    
    return {
      'hits': _cacheHits,
      'misses': _cacheMisses,
      'evictions': _cacheEvictions,
      'hitRate': hitRate.toStringAsFixed(1),
      'totalRequests': totalRequests,
    };
  }
  
  /// Cleanup old cache entries
  static Future<void> cleanup() async {
    try {
      final prefsService = ServiceManager.instance.preferencesService;
      final cacheIndexJson = await prefsService.getString('cache_index');
      
      if (cacheIndexJson == null) return;
      
      final cacheIndex = Map<String, int>.from(jsonDecode(cacheIndexJson));
      final now = DateTime.now();
      final keysToRemove = <String>[];
      
      for (final entry in cacheIndex.entries) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(entry.value);
        final cacheDuration = _defaultCacheDuration;
        
        if (now.difference(cacheTime) > cacheDuration) {
          keysToRemove.add(entry.key);
        }
      }
      
      for (final key in keysToRemove) {
        await _removeCacheEntry(key);
        cacheIndex.remove(key);
      }
      
      if (keysToRemove.isNotEmpty) {
        await prefsService.setString('cache_index', jsonEncode(cacheIndex));
      }
      
      LoggingUtils.logDebug('Cache cleanup completed: removed ${keysToRemove.length} expired entries');
    } catch (e) {
      LoggingUtils.logError('Cache cleanup failed', e);
    }
  }
  
  /// Check if device is online
  static Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('api.open-meteo.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      LoggingUtils.logDebug('Network connectivity check failed: $e');
      return false;
    }
  }
}