import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asset preloader utility for optimizing app startup and runtime performance.
/// Handles preloading of critical assets and implements lazy loading strategies.
class AssetPreloader {
  static final AssetPreloader _instance = AssetPreloader._internal();
  factory AssetPreloader() => _instance;
  AssetPreloader._internal();

  // Track preloaded assets to avoid duplicate loading
  static final Set<String> _preloadedAssets = {};
  static final Map<String, Future<void>> _preloadingFutures = {};

  // Critical assets that should be preloaded during app initialization
  static const List<String> _criticalAssets = [
    'assets/icon2.png',
  ];

  // Audio assets for lazy loading
  static const List<String> _audioAssets = [
    'assets/audio/alarm.mp3',
  ];

  /// Initialize the asset preloader with fast startup strategy
  static Future<void> initialize(BuildContext context) async {
    // Only preload absolutely essential assets synchronously
    await _preloadEssentialAssets(context);

    // Schedule remaining critical assets for background loading
    _scheduleBackgroundAssetLoading(context);
  }

  /// Preload only essential assets needed for immediate app launch
  static Future<void> _preloadEssentialAssets(BuildContext context) async {
    // For now, skip all asset preloading during startup for maximum speed
    // Assets will be loaded on-demand when actually needed
    return;
  }

  /// Schedule background loading of critical assets
  static void _scheduleBackgroundAssetLoading(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 300), () async {
      await preloadCriticalAssets(context);
    });
  }

  /// Preload critical assets in background
  static Future<void> preloadCriticalAssets(BuildContext context) async {
    final futures = <Future<void>>[];

    for (final asset in _criticalAssets) {
      if (!_preloadedAssets.contains(asset)) {
        futures.add(_preloadAsset(context, asset));
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  /// Preload a specific asset with error handling
  static Future<void> _preloadAsset(
      BuildContext context, String assetPath) async {
    if (_preloadedAssets.contains(assetPath)) {
      return;
    }

    // Check if already preloading
    if (_preloadingFutures.containsKey(assetPath)) {
      return _preloadingFutures[assetPath]!;
    }

    final future = _doPreloadAsset(context, assetPath);
    _preloadingFutures[assetPath] = future;

    try {
      await future;
      _preloadedAssets.add(assetPath);
    } catch (e) {
      debugPrint('Failed to preload asset $assetPath: $e');
    } finally {
      _preloadingFutures.remove(assetPath);
    }
  }

  /// Actual asset preloading implementation
  static Future<void> _doPreloadAsset(
      BuildContext context, String assetPath) async {
    if (assetPath.endsWith('.png') ||
        assetPath.endsWith('.jpg') ||
        assetPath.endsWith('.jpeg')) {
      await precacheImage(AssetImage(assetPath), context);
    } else if (assetPath.endsWith('.svg')) {
      // For SVG assets, we can preload them as byte data
      await rootBundle.load(assetPath);
    } else {
      // For other assets (audio, etc.), preload as byte data
      await rootBundle.load(assetPath);
    }
  }

  /// Lazy load an asset when needed
  static Future<void> lazyLoadAsset(
      BuildContext context, String assetPath) async {
    if (_preloadedAssets.contains(assetPath)) {
      return; // Already loaded
    }

    await _preloadAsset(context, assetPath);
  }

  /// Preload audio assets for notification sounds
  static Future<void> preloadAudioAssets() async {
    final futures = <Future<void>>[];

    for (final asset in _audioAssets) {
      if (!_preloadedAssets.contains(asset)) {
        futures.add(_preloadAudioAsset(asset));
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  /// Preload a specific audio asset
  static Future<void> _preloadAudioAsset(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      _preloadedAssets.add(assetPath);
    } catch (e) {
      debugPrint('Failed to preload audio asset $assetPath: $e');
    }
  }

  /// Check if an asset is preloaded
  static bool isAssetPreloaded(String assetPath) {
    return _preloadedAssets.contains(assetPath);
  }

  /// Get preloader statistics for debugging
  static Map<String, dynamic> getStats() {
    return {
      'preloaded_assets': _preloadedAssets.length,
      'currently_preloading': _preloadingFutures.length,
      'critical_assets': _criticalAssets.length,
      'audio_assets': _audioAssets.length,
      'preloaded_list': _preloadedAssets.toList(),
    };
  }

  /// Clear preloaded assets cache (useful for memory management)
  static void clearCache() {
    _preloadedAssets.clear();
    _preloadingFutures.clear();
  }

  /// Preload assets in background after app startup
  static Future<void> preloadNonCriticalAssets(BuildContext context) async {
    // Delay to avoid interfering with app startup
    await Future.delayed(const Duration(seconds: 2));

    // Preload audio assets
    await preloadAudioAssets();
  }
}

/// Widget that ensures assets are preloaded before displaying content
class AssetPreloadWrapper extends StatefulWidget {
  final Widget child;
  final List<String> requiredAssets;
  final Widget? loadingWidget;
  final Duration timeout;

  const AssetPreloadWrapper({
    super.key,
    required this.child,
    this.requiredAssets = const [],
    this.loadingWidget,
    this.timeout = const Duration(seconds: 5),
  });

  @override
  State<AssetPreloadWrapper> createState() => _AssetPreloadWrapperState();
}

class _AssetPreloadWrapperState extends State<AssetPreloadWrapper> {
  bool _assetsLoaded = false;

  @override
  void initState() {
    super.initState();
    _preloadRequiredAssets();
  }

  Future<void> _preloadRequiredAssets() async {
    if (widget.requiredAssets.isEmpty) {
      setState(() {
        _assetsLoaded = true;
      });
      return;
    }

    try {
      final futures = widget.requiredAssets
          .map((asset) => AssetPreloader.lazyLoadAsset(context, asset))
          .toList();

      await Future.wait(futures).timeout(widget.timeout);

      if (mounted) {
        setState(() {
          _assetsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to preload required assets: $e');
      if (mounted) {
        setState(() {
          _assetsLoaded = true; // Show content even if preloading failed
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_assetsLoaded) {
      return widget.loadingWidget ??
          const Center(
            child: CircularProgressIndicator(),
          );
    }

    return widget.child;
  }
}

/// Optimized image widget with lazy loading and error handling
class OptimizedAssetImage extends StatelessWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? errorWidget;
  final Widget? loadingWidget;

  const OptimizedAssetImage(
    this.assetPath, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorWidget,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Failed to load asset image $assetPath: $error');
        return errorWidget ??
            Icon(
              Icons.broken_image,
              size: width ?? height ?? 24,
              color: Theme.of(context).colorScheme.error,
            );
      },
    );
  }
}
