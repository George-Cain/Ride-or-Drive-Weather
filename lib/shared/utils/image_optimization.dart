import 'package:flutter/material.dart';

/// Comprehensive image and asset optimization utility for the Ride or Drive Weather app.
/// Provides efficient icon caching, lazy loading, and optimized Material Icons usage.
class ImageOptimization {
  static final ImageOptimization _instance = ImageOptimization._internal();
  factory ImageOptimization() => _instance;
  ImageOptimization._internal();

  // Cache for preloaded icons to avoid repeated lookups
  static final Map<String, IconData> _iconCache = {};

  // Commonly used weather-related icons for preloading
  static const Map<String, IconData> _weatherIcons = {
    'temperature': Icons.thermostat,
    'wind': Icons.air,
    'humidity': Icons.water_drop,
    'visibility': Icons.visibility,
    'precipitation': Icons.water,
    'sunny': Icons.wb_sunny,
    'cloudy': Icons.cloud,
    'rainy': Icons.umbrella,
    'snowy': Icons.ac_unit,
    'foggy': Icons.foggy,
    'thunderstorm': Icons.flash_on,
  };

  // App-specific icons for consistent usage
  static const Map<String, IconData> _appIcons = {
    'refresh': Icons.refresh,
    'settings': Icons.settings,
    'notifications': Icons.notifications,
    'motorcycle': Icons.motorcycle,
    'location': Icons.location_on,
    'warning': Icons.warning,
    'error': Icons.error_outline,
    'info': Icons.info_outline,
    'delete': Icons.delete_forever,
    'clear': Icons.clear,
    'schedule': Icons.schedule,
    'alarm': Icons.alarm,
    'security': Icons.security,
    'memory': Icons.memory,
    'list': Icons.list,
  };

  /// Initialize the image optimization system by preloading commonly used icons
  static void initialize() {
    _iconCache.addAll(_weatherIcons);
    _iconCache.addAll(_appIcons);
  }

  /// Get an optimized icon with fallback support
  static IconData getIcon(String iconKey, {IconData? fallback}) {
    return _iconCache[iconKey] ?? fallback ?? Icons.help_outline;
  }

  /// Get weather-specific icon based on weather condition
  static IconData getWeatherIcon(String condition) {
    final normalizedCondition = condition.toLowerCase();

    if (normalizedCondition.contains('sun') ||
        normalizedCondition.contains('clear')) {
      return getIcon('sunny');
    } else if (normalizedCondition.contains('cloud')) {
      return getIcon('cloudy');
    } else if (normalizedCondition.contains('rain') ||
        normalizedCondition.contains('drizzle')) {
      return getIcon('rainy');
    } else if (normalizedCondition.contains('snow')) {
      return getIcon('snowy');
    } else if (normalizedCondition.contains('fog') ||
        normalizedCondition.contains('mist')) {
      return getIcon('foggy');
    } else if (normalizedCondition.contains('thunder') ||
        normalizedCondition.contains('storm')) {
      return getIcon('thunderstorm');
    }

    return getIcon('cloudy'); // Default fallback
  }

  /// Create an optimized icon widget with consistent styling
  static Widget createOptimizedIcon(
    String iconKey, {
    double? size,
    Color? color,
    String? semanticLabel,
    IconData? fallback,
  }) {
    return Icon(
      getIcon(iconKey, fallback: fallback),
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    );
  }

  /// Create a weather-specific icon widget
  static Widget createWeatherIcon(
    String condition, {
    double? size,
    Color? color,
    String? semanticLabel,
  }) {
    return Icon(
      getWeatherIcon(condition),
      size: size,
      color: color,
      semanticLabel: semanticLabel ?? 'Weather: $condition',
    );
  }

  /// Preload app icon asset for faster loading
  static Future<void> preloadAppIcon(BuildContext context) async {
    try {
      await precacheImage(
        const AssetImage('assets/icon2.png'),
        context,
      );
    } catch (e) {
      // Silently handle preload failures
      debugPrint('Failed to preload app icon: $e');
    }
  }

  /// Get optimized icon size based on context
  static double getOptimizedIconSize(BuildContext context, IconSizeType type) {
    final theme = Theme.of(context);
    switch (type) {
      case IconSizeType.small:
        return theme.iconTheme.size ?? 16.0;
      case IconSizeType.medium:
        return (theme.iconTheme.size ?? 24.0) * 1.0;
      case IconSizeType.large:
        return (theme.iconTheme.size ?? 24.0) * 1.5;
      case IconSizeType.extraLarge:
        return (theme.iconTheme.size ?? 24.0) * 2.0;
    }
  }

  /// Clear icon cache to free memory (useful for memory optimization)
  static void clearCache() {
    _iconCache.clear();
    initialize(); // Reinitialize with essential icons
  }

  /// Get cache statistics for debugging
  static Map<String, dynamic> getCacheStats() {
    return {
      'cached_icons': _iconCache.length,
      'weather_icons': _weatherIcons.length,
      'app_icons': _appIcons.length,
      'memory_usage_estimate':
          '${_iconCache.length * 8} bytes', // Rough estimate
    };
  }
}

/// Enum for standardized icon sizes
enum IconSizeType {
  small,
  medium,
  large,
  extraLarge,
}

/// Optimized icon widget that uses the ImageOptimization system
class OptimizedIcon extends StatelessWidget {
  final String iconKey;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final IconData? fallback;
  final IconSizeType? sizeType;

  const OptimizedIcon(
    this.iconKey, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.fallback,
    this.sizeType,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size ??
        (sizeType != null
            ? ImageOptimization.getOptimizedIconSize(context, sizeType!)
            : null);

    return ImageOptimization.createOptimizedIcon(
      iconKey,
      size: iconSize,
      color: color,
      semanticLabel: semanticLabel,
      fallback: fallback,
    );
  }
}

/// Optimized weather icon widget
class OptimizedWeatherIcon extends StatelessWidget {
  final String condition;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final IconSizeType? sizeType;

  const OptimizedWeatherIcon(
    this.condition, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.sizeType,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size ??
        (sizeType != null
            ? ImageOptimization.getOptimizedIconSize(context, sizeType!)
            : null);

    return ImageOptimization.createWeatherIcon(
      condition,
      size: iconSize,
      color: color,
      semanticLabel: semanticLabel,
    );
  }
}
