import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Comprehensive image cache manager for optimizing memory usage and performance.
/// Handles automatic cache cleanup, memory pressure monitoring, and efficient asset management.
class ImageCacheManager {
  static final ImageCacheManager _instance = ImageCacheManager._internal();
  factory ImageCacheManager() => _instance;
  ImageCacheManager._internal();

  // Cache size limits (in MB)
  static const int _maxCacheSizeMB = 50;
  static const int _targetCacheSizeMB = 30;
  
  // Cache cleanup thresholds
  static const int _maxCacheEntries = 100;
  static const Duration _cacheEntryMaxAge = Duration(hours: 2);
  
  // Track cache usage
  static final Map<String, _CacheEntry> _imageCache = {};
  static int _currentCacheSizeBytes = 0;
  static DateTime _lastCleanup = DateTime.now();
  
  /// Initialize the image cache manager
  static void initialize() {
    // Configure Flutter's image cache
    PaintingBinding.instance.imageCache.maximumSize = _maxCacheEntries;
    PaintingBinding.instance.imageCache.maximumSizeBytes = _maxCacheSizeMB * 1024 * 1024;
    
    // Schedule periodic cleanup
    _schedulePeriodicCleanup();
  }

  /// Schedule periodic cache cleanup
  static void _schedulePeriodicCleanup() {
    // Clean up cache every 30 minutes
    Future.delayed(const Duration(minutes: 30), () {
      cleanupCache();
      _schedulePeriodicCleanup();
    });
  }

  /// Add an entry to the cache tracking
  static void _addCacheEntry(String key, int sizeBytes) {
    _imageCache[key] = _CacheEntry(
      key: key,
      sizeBytes: sizeBytes,
      accessTime: DateTime.now(),
      accessCount: 1,
    );
    _currentCacheSizeBytes += sizeBytes;
  }

  /// Update cache entry access
  static void _updateCacheAccess(String key) {
    final entry = _imageCache[key];
    if (entry != null) {
      entry.accessTime = DateTime.now();
      entry.accessCount++;
    }
  }

  /// Remove cache entry
  static void _removeCacheEntry(String key) {
    final entry = _imageCache.remove(key);
    if (entry != null) {
      _currentCacheSizeBytes -= entry.sizeBytes;
    }
  }

  /// Preload an image asset efficiently
  static Future<void> preloadImage(BuildContext context, String assetPath) async {
    try {
      // Check if already in our tracking cache
      if (_imageCache.containsKey(assetPath)) {
        _updateCacheAccess(assetPath);
        return;
      }

      // Load the image
      final imageProvider = AssetImage(assetPath);
      await precacheImage(imageProvider, context);
      
      // Estimate size (rough approximation)
      final estimatedSize = await _estimateImageSize(assetPath);
      _addCacheEntry(assetPath, estimatedSize);
      
      // Check if cleanup is needed
      if (_shouldCleanupCache()) {
        await _performCacheCleanup();
      }
    } catch (e) {
      debugPrint('Failed to preload image $assetPath: $e');
    }
  }

  /// Estimate image size for cache tracking
  static Future<int> _estimateImageSize(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      return byteData.lengthInBytes;
    } catch (e) {
      // Return a default estimate if we can't load the asset
      return 50 * 1024; // 50KB default estimate
    }
  }

  /// Check if cache cleanup is needed
  static bool _shouldCleanupCache() {
    return _currentCacheSizeBytes > (_maxCacheSizeMB * 1024 * 1024) ||
           _imageCache.length > _maxCacheEntries ||
           DateTime.now().difference(_lastCleanup) > const Duration(hours: 1);
  }

  /// Perform cache cleanup
  static Future<void> _performCacheCleanup() async {
    final now = DateTime.now();
    final entriesToRemove = <String>[];
    
    // Remove old entries
    for (final entry in _imageCache.values) {
      if (now.difference(entry.accessTime) > _cacheEntryMaxAge) {
        entriesToRemove.add(entry.key);
      }
    }
    
    // If still over limit, remove least recently used entries
    if (_currentCacheSizeBytes > (_targetCacheSizeMB * 1024 * 1024)) {
      final sortedEntries = _imageCache.values.toList()
        ..sort((a, b) => a.accessTime.compareTo(b.accessTime));
      
      for (final entry in sortedEntries) {
        if (_currentCacheSizeBytes <= (_targetCacheSizeMB * 1024 * 1024)) {
          break;
        }
        entriesToRemove.add(entry.key);
      }
    }
    
    // Remove entries from both our tracking and Flutter's cache
    for (final key in entriesToRemove) {
      _removeCacheEntry(key);
      PaintingBinding.instance.imageCache.evict(AssetImage(key));
    }
    
    _lastCleanup = now;
    
    if (entriesToRemove.isNotEmpty) {
      debugPrint('ImageCacheManager: Cleaned up ${entriesToRemove.length} cache entries');
    }
  }

  /// Clean up cache manually
  static Future<void> cleanupCache() async {
    await _performCacheCleanup();
  }

  /// Clear all cache
  static void clearAllCache() {
    _imageCache.clear();
    _currentCacheSizeBytes = 0;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'tracked_entries': _imageCache.length,
      'cache_size_mb': (_currentCacheSizeBytes / (1024 * 1024)).toStringAsFixed(2),
      'max_cache_size_mb': _maxCacheSizeMB,
      'flutter_cache_size': PaintingBinding.instance.imageCache.currentSize,
      'flutter_cache_size_bytes': PaintingBinding.instance.imageCache.currentSizeBytes,
      'last_cleanup': _lastCleanup.toIso8601String(),
      'most_accessed_images': _getMostAccessedImages(),
    };
  }

  /// Get most accessed images for debugging
  static List<Map<String, dynamic>> _getMostAccessedImages() {
    final sortedEntries = _imageCache.values.toList()
      ..sort((a, b) => b.accessCount.compareTo(a.accessCount));
    
    return sortedEntries.take(5).map((entry) => {
      'path': entry.key,
      'access_count': entry.accessCount,
      'size_kb': (entry.sizeBytes / 1024).toStringAsFixed(1),
      'last_access': entry.accessTime.toIso8601String(),
    }).toList();
  }

  /// Handle memory pressure by aggressively cleaning cache
  static void handleMemoryPressure() {
    debugPrint('ImageCacheManager: Handling memory pressure');
    
    // Clear half of the cache, starting with least recently used
    final sortedEntries = _imageCache.values.toList()
      ..sort((a, b) => a.accessTime.compareTo(b.accessTime));
    
    final entriesToRemove = sortedEntries.take(sortedEntries.length ~/ 2);
    
    for (final entry in entriesToRemove) {
      _removeCacheEntry(entry.key);
      PaintingBinding.instance.imageCache.evict(AssetImage(entry.key));
    }
    
    // Also clear Flutter's live images
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Check if an image is cached
  static bool isImageCached(String assetPath) {
    return _imageCache.containsKey(assetPath);
  }

  /// Get cache entry info
  static Map<String, dynamic>? getCacheEntryInfo(String assetPath) {
    final entry = _imageCache[assetPath];
    if (entry == null) return null;
    
    return {
      'path': entry.key,
      'size_bytes': entry.sizeBytes,
      'access_count': entry.accessCount,
      'last_access': entry.accessTime.toIso8601String(),
    };
  }
}

/// Cache entry tracking class
class _CacheEntry {
  final String key;
  final int sizeBytes;
  DateTime accessTime;
  int accessCount;
  
  _CacheEntry({
    required this.key,
    required this.sizeBytes,
    required this.accessTime,
    required this.accessCount,
  });
}

/// Mixin for widgets that need image cache management
mixin ImageCacheMixin {
  /// Preload images used by this widget
  Future<void> preloadWidgetImages(BuildContext context, List<String> imagePaths) async {
    final futures = imagePaths.map((path) => ImageCacheManager.preloadImage(context, path));
    await Future.wait(futures);
  }
  
  /// Handle memory pressure in the widget
  void handleWidgetMemoryPressure() {
    ImageCacheManager.handleMemoryPressure();
  }
}

/// Widget that automatically manages image caching
class CachedAssetImage extends StatefulWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? errorWidget;
  final Widget? loadingWidget;
  final bool preload;
  
  const CachedAssetImage(
    this.assetPath, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorWidget,
    this.loadingWidget,
    this.preload = true,
  });
  
  @override
  State<CachedAssetImage> createState() => _CachedAssetImageState();
}

class _CachedAssetImageState extends State<CachedAssetImage> with ImageCacheMixin {
  bool _isPreloaded = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.preload) {
      _preloadImage();
    }
  }
  
  Future<void> _preloadImage() async {
    if (!mounted) return;
    
    await ImageCacheManager.preloadImage(context, widget.assetPath);
    
    if (mounted) {
      setState(() {
        _isPreloaded = true;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.preload && !_isPreloaded) {
      return widget.loadingWidget ??
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
    }
    
    return Image.asset(
      widget.assetPath,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        return widget.errorWidget ??
            Icon(
              Icons.broken_image,
              size: widget.width ?? widget.height ?? 24,
              color: Theme.of(context).colorScheme.error,
            );
      },
    );
  }
}