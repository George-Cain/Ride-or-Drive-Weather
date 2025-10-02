import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'logging_utils.dart';
import 'memory_utils.dart';
import 'memory_profiler.dart';

/// Enhanced memory management system with advanced leak detection
/// and automated cleanup mechanisms
class EnhancedMemoryManager {
  static final EnhancedMemoryManager _instance =
      EnhancedMemoryManager._internal();
  factory EnhancedMemoryManager() => _instance;
  EnhancedMemoryManager._internal();

  // Memory monitoring configuration
  static const Duration _monitoringInterval = Duration(seconds: 15);
  static const Duration _cleanupInterval = Duration(minutes: 5);
  static const int _maxResourceAge = 300; // 5 minutes in seconds

  // Resource tracking with timestamps
  static final Map<String, _ResourceInfo> _trackedResources = {};
  static final Queue<_MemoryEvent> _memoryEvents = Queue();
  static const int _maxMemoryEvents = 1000;

  // Monitoring state
  static Timer? _monitoringTimer;
  static Timer? _cleanupTimer;
  static bool _isMonitoring = false;
  static bool _memoryPressureDetected = false;

  // Statistics
  static int _totalLeaksDetected = 0;
  static int _totalResourcesTracked = 0;
  static int _automaticCleanups = 0;

  /// Start enhanced memory monitoring
  static void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    LoggingUtils.logDebug('Starting enhanced memory monitoring');

    // Start memory profiler
    MemoryProfiler.startMonitoring(interval: _monitoringInterval);

    // Start resource monitoring
    _monitoringTimer = Timer.periodic(_monitoringInterval, (_) {
      _performMemoryCheck();
    });

    // Start periodic cleanup
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      _performAutomaticCleanup();
    });

    // Register memory pressure callback
    _registerMemoryPressureCallback();
  }

  /// Stop enhanced memory monitoring
  static void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _cleanupTimer?.cancel();
    _monitoringTimer = null;
    _cleanupTimer = null;

    MemoryProfiler.stopMonitoring();
    LoggingUtils.logDebug('Enhanced memory monitoring stopped');
  }

  /// Register a resource with enhanced tracking
  static void registerResource(
    String type,
    String id, {
    Map<String, dynamic>? metadata,
    Duration? maxAge,
  }) {
    final resourceKey = '$type:$id';
    final now = DateTime.now();

    _trackedResources[resourceKey] = _ResourceInfo(
      type: type,
      id: id,
      createdAt: now,
      lastAccessed: now,
      metadata: metadata ?? {},
      maxAge: maxAge ?? Duration(seconds: _maxResourceAge),
    );

    _totalResourcesTracked++;
    _addMemoryEvent(_MemoryEventType.resourceRegistered, resourceKey);

    // Also register with base MemoryUtils
    MemoryUtils.registerResource(type, id);

    LoggingUtils.logDebug('Enhanced resource registered: $resourceKey');
  }

  /// Unregister a resource
  static void unregisterResource(String type, String id) {
    final resourceKey = '$type:$id';

    if (_trackedResources.containsKey(resourceKey)) {
      _trackedResources.remove(resourceKey);
      _addMemoryEvent(_MemoryEventType.resourceUnregistered, resourceKey);
    }

    // Also unregister from base MemoryUtils
    MemoryUtils.unregisterResource(type, id);

    LoggingUtils.logDebug('Enhanced resource unregistered: $resourceKey');
  }

  /// Update resource access time
  static void touchResource(String type, String id) {
    final resourceKey = '$type:$id';
    final resource = _trackedResources[resourceKey];

    if (resource != null) {
      _trackedResources[resourceKey] = resource.copyWith(
        lastAccessed: DateTime.now(),
      );
    }
  }

  /// Perform comprehensive memory check
  static void _performMemoryCheck() {
    try {
      // Check for stale resources
      _checkForStaleResources();

      // Check for potential leaks
      _checkForMemoryLeaks();

      // Check memory pressure
      _checkMemoryPressure();

      // Analyze memory patterns
      _analyzeMemoryPatterns();
    } catch (e) {
      LoggingUtils.logError('Error during memory check', e);
    }
  }

  /// Check for stale resources that should be cleaned up
  static void _checkForStaleResources() {
    final now = DateTime.now();
    final staleResources = <String>[];

    _trackedResources.forEach((key, resource) {
      final age = now.difference(resource.lastAccessed);
      if (age > resource.maxAge) {
        staleResources.add(key);
      }
    });

    if (staleResources.isNotEmpty) {
      LoggingUtils.logWarning(
          'Found ${staleResources.length} stale resources: ${staleResources.take(5).join(", ")}');

      for (final resourceKey in staleResources) {
        _addMemoryEvent(_MemoryEventType.staleResourceDetected, resourceKey);
      }
    }
  }

  /// Check for potential memory leaks
  static void _checkForMemoryLeaks() {
    final resourceCounts = MemoryUtils.getResourceCounts();
    final suspiciousResources = <String>[];

    resourceCounts.forEach((type, count) {
      // Dynamic thresholds based on resource type
      int threshold = _getLeakThreshold(type);

      if (count > threshold) {
        suspiciousResources
            .add('$type: $count instances (threshold: $threshold)');
        _totalLeaksDetected++;
        _addMemoryEvent(_MemoryEventType.leakDetected, '$type:$count');
      }
    });

    if (suspiciousResources.isNotEmpty) {
      LoggingUtils.logWarning(
          'Potential memory leaks detected: ${suspiciousResources.join(", ")}');
      _generateEnhancedLeakReport(suspiciousResources);
    }
  }

  /// Get leak detection threshold for resource type
  static int _getLeakThreshold(String resourceType) {
    switch (resourceType.toLowerCase()) {
      case 'timer':
      case 'servicetimer':
        return 5;
      case 'streamsubscription':
      case 'servicesubscription':
        return 8;
      case 'performancewidget':
        return 20;
      case 'httprequest':
        return 15;
      case 'cacheentry':
        return 100;
      default:
        return 10;
    }
  }

  /// Check for memory pressure
  static void _checkMemoryPressure() {
    // This would ideally use platform channels for accurate memory info
    // For now, we'll use heuristics based on resource counts
    final totalResources = _trackedResources.length;
    final memoryEvents = _memoryEvents.length;

    final pressureScore = (totalResources * 0.1) + (memoryEvents * 0.05);
    final isUnderPressure = pressureScore > 50; // Arbitrary threshold

    if (isUnderPressure && !_memoryPressureDetected) {
      _memoryPressureDetected = true;
      _handleMemoryPressure();
      _addMemoryEvent(
          _MemoryEventType.memoryPressureDetected, 'score:$pressureScore');
    } else if (!isUnderPressure && _memoryPressureDetected) {
      _memoryPressureDetected = false;
      _addMemoryEvent(
          _MemoryEventType.memoryPressureRelieved, 'score:$pressureScore');
    }
  }

  /// Handle memory pressure situation
  static void _handleMemoryPressure() {
    LoggingUtils.logWarning(
        'Memory pressure detected - initiating emergency cleanup');

    // Force garbage collection
    MemoryProfiler.forceGC();

    // Clear old memory events
    while (_memoryEvents.length > _maxMemoryEvents ~/ 2) {
      _memoryEvents.removeFirst();
    }

    // Trigger aggressive cleanup
    _performAutomaticCleanup(aggressive: true);

    // Notify system components
    _notifyMemoryPressure();
  }

  /// Analyze memory usage patterns
  static void _analyzeMemoryPatterns() {
    if (_memoryEvents.length < 10) return;

    final recentEvents = _memoryEvents.toList().takeLast(50);
    final eventCounts = <_MemoryEventType, int>{};

    for (final event in recentEvents) {
      eventCounts[event.type] = (eventCounts[event.type] ?? 0) + 1;
    }

    // Look for concerning patterns
    final registrations = eventCounts[_MemoryEventType.resourceRegistered] ?? 0;
    final unregistrations =
        eventCounts[_MemoryEventType.resourceUnregistered] ?? 0;

    if (registrations > unregistrations * 2) {
      LoggingUtils.logWarning(
          'Memory pattern alert: High registration to unregistration ratio ($registrations:$unregistrations)');
    }
  }

  /// Perform automatic cleanup
  static void _performAutomaticCleanup({bool aggressive = false}) {
    try {
      final now = DateTime.now();
      final cleanupThreshold = aggressive
          ? Duration(seconds: _maxResourceAge ~/ 2)
          : Duration(seconds: _maxResourceAge);

      final resourcesToCleanup = <String>[];

      _trackedResources.forEach((key, resource) {
        final age = now.difference(resource.lastAccessed);
        if (age > cleanupThreshold) {
          resourcesToCleanup.add(key);
        }
      });

      for (final resourceKey in resourcesToCleanup) {
        final parts = resourceKey.split(':');
        if (parts.length == 2) {
          unregisterResource(parts[0], parts[1]);
        }
      }

      if (resourcesToCleanup.isNotEmpty) {
        _automaticCleanups++;
        LoggingUtils.logDebug(
            'Automatic cleanup removed ${resourcesToCleanup.length} stale resources');
      }

      // Clean up old memory events
      while (_memoryEvents.length > _maxMemoryEvents) {
        _memoryEvents.removeFirst();
      }
    } catch (e) {
      LoggingUtils.logError('Error during automatic cleanup', e);
    }
  }

  /// Generate enhanced leak report
  static void _generateEnhancedLeakReport(List<String> suspiciousResources) {
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'suspicious_resources': suspiciousResources,
      'total_tracked_resources': _trackedResources.length,
      'memory_events_count': _memoryEvents.length,
      'memory_pressure': _memoryPressureDetected,
      'recommendations': _generateRecommendations(suspiciousResources),
    };

    LoggingUtils.logWarning('Enhanced memory leak report: $report');
  }

  /// Generate cleanup recommendations
  static List<String> _generateRecommendations(
      List<String> suspiciousResources) {
    final recommendations = <String>[];

    for (final resource in suspiciousResources) {
      if (resource.contains('Timer')) {
        recommendations.add('Check for uncanceled timers in dispose methods');
      } else if (resource.contains('Subscription')) {
        recommendations
            .add('Verify all stream subscriptions are properly canceled');
      } else if (resource.contains('Http')) {
        recommendations
            .add('Review HTTP client connection pooling and cleanup');
      } else if (resource.contains('Cache')) {
        recommendations
            .add('Consider implementing cache size limits and expiration');
      }
    }

    if (recommendations.isEmpty) {
      recommendations
          .add('Review resource disposal patterns in affected components');
    }

    return recommendations.toSet().toList(); // Remove duplicates
  }

  /// Register memory pressure callback
  static void _registerMemoryPressureCallback() {
    if (kDebugMode) {
      // In a real implementation, this would use platform channels
      // to register for system memory pressure notifications
    }
  }

  /// Notify system components of memory pressure
  static void _notifyMemoryPressure() {
    // Notify image cache manager
    try {
      // This would call ImageCacheManager.handleMemoryPressure() if available
    } catch (e) {
      LoggingUtils.logError(
          'Error notifying image cache of memory pressure', e);
    }

    // Notify intelligent cache
    try {
      // This would call IntelligentCache methods if available
    } catch (e) {
      LoggingUtils.logError(
          'Error notifying intelligent cache of memory pressure', e);
    }
  }

  /// Add memory event to history
  static void _addMemoryEvent(_MemoryEventType type, String details) {
    _memoryEvents.add(_MemoryEvent(
      type: type,
      timestamp: DateTime.now(),
      details: details,
    ));

    // Keep events within limit
    while (_memoryEvents.length > _maxMemoryEvents) {
      _memoryEvents.removeFirst();
    }
  }

  /// Get comprehensive memory statistics
  static Map<String, dynamic> getMemoryStatistics() {
    final resourcesByType = <String, int>{};

    _trackedResources.forEach((key, resource) {
      resourcesByType[resource.type] =
          (resourcesByType[resource.type] ?? 0) + 1;
    });

    return {
      'monitoring_active': _isMonitoring,
      'total_resources_tracked': _totalResourcesTracked,
      'current_resources': _trackedResources.length,
      'resources_by_type': resourcesByType,
      'memory_events': _memoryEvents.length,
      'total_leaks_detected': _totalLeaksDetected,
      'automatic_cleanups': _automaticCleanups,
      'memory_pressure': _memoryPressureDetected,
      'base_memory_stats': MemoryUtils.getResourceCounts(),
      'profiler_stats': MemoryProfiler.getMemoryStats(),
    };
  }

  /// Force immediate cleanup
  static void forceCleanup() {
    LoggingUtils.logDebug('Forcing immediate memory cleanup');
    _performAutomaticCleanup(aggressive: true);
    MemoryUtils.checkForLeaks();
    MemoryProfiler.forceGC();
  }

  /// Clear all tracking data (for testing)
  static void clearAllTracking() {
    _trackedResources.clear();
    _memoryEvents.clear();
    _totalLeaksDetected = 0;
    _totalResourcesTracked = 0;
    _automaticCleanups = 0;
    _memoryPressureDetected = false;

    MemoryUtils.clearTracking();
    MemoryProfiler.clearSnapshots();

    LoggingUtils.logDebug('All memory tracking data cleared');
  }

  /// Dispose the enhanced memory manager
  static void dispose() {
    stopMonitoring();
    clearAllTracking();
    LoggingUtils.logDebug('Enhanced memory manager disposed');
  }
}

/// Resource information with enhanced tracking
class _ResourceInfo {
  final String type;
  final String id;
  final DateTime createdAt;
  final DateTime lastAccessed;
  final Map<String, dynamic> metadata;
  final Duration maxAge;

  const _ResourceInfo({
    required this.type,
    required this.id,
    required this.createdAt,
    required this.lastAccessed,
    required this.metadata,
    required this.maxAge,
  });

  _ResourceInfo copyWith({
    String? type,
    String? id,
    DateTime? createdAt,
    DateTime? lastAccessed,
    Map<String, dynamic>? metadata,
    Duration? maxAge,
  }) {
    return _ResourceInfo(
      type: type ?? this.type,
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      metadata: metadata ?? this.metadata,
      maxAge: maxAge ?? this.maxAge,
    );
  }
}

/// Memory event types for tracking
enum _MemoryEventType {
  resourceRegistered,
  resourceUnregistered,
  staleResourceDetected,
  leakDetected,
  memoryPressureDetected,
  memoryPressureRelieved,
}

/// Memory event data
class _MemoryEvent {
  final _MemoryEventType type;
  final DateTime timestamp;
  final String details;

  const _MemoryEvent({
    required this.type,
    required this.timestamp,
    required this.details,
  });
}

/// Extension for taking last N elements from iterable
extension IterableExtension<T> on Iterable<T> {
  List<T> takeLast(int count) {
    final list = toList();
    if (count >= list.length) return list;
    return list.sublist(list.length - count);
  }
}

/// Enhanced resource cleanup mixin with automatic registration
mixin EnhancedResourceCleanupMixin<T extends StatefulWidget> on State<T> {
  final List<StreamSubscription> _subscriptions = [];
  final List<Timer> _timers = [];
  final Set<String> _registeredResources = {};
  late final String _widgetId;

  @override
  void initState() {
    super.initState();
    _widgetId = '${widget.runtimeType}_$hashCode';
    EnhancedMemoryManager.registerResource('Widget', _widgetId);
  }

  /// Add a subscription with enhanced tracking
  void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
    final subscriptionId = '${_widgetId}_sub_${subscription.hashCode}';
    EnhancedMemoryManager.registerResource(
        'StreamSubscription', subscriptionId);
    _registeredResources.add('StreamSubscription:$subscriptionId');
  }

  /// Add a timer with enhanced tracking
  void addTimer(Timer timer) {
    _timers.add(timer);
    final timerId = '${_widgetId}_timer_${timer.hashCode}';
    EnhancedMemoryManager.registerResource('Timer', timerId);
    _registeredResources.add('Timer:$timerId');
  }

  /// Register a custom resource
  void registerResource(String type, String id) {
    final resourceId = '${_widgetId}_${type}_$id';
    EnhancedMemoryManager.registerResource(type, resourceId);
    _registeredResources.add('$type:$resourceId');
  }

  /// Touch widget resource to update access time
  void touchWidget() {
    EnhancedMemoryManager.touchResource('Widget', _widgetId);
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }

    // Cancel all timers
    for (final timer in _timers) {
      timer.cancel();
    }

    // Unregister all resources
    for (final resource in _registeredResources) {
      final parts = resource.split(':');
      if (parts.length == 2) {
        EnhancedMemoryManager.unregisterResource(parts[0], parts[1]);
      }
    }

    // Unregister widget
    EnhancedMemoryManager.unregisterResource('Widget', _widgetId);

    super.dispose();
  }
}

/// Enhanced service resource mixin
mixin EnhancedServiceResourceMixin {
  final List<StreamSubscription> _subscriptions = [];
  final List<Timer> _timers = [];
  final Set<String> _registeredResources = {};
  bool _isDisposed = false;
  late final String _serviceId;

  /// Initialize service with enhanced tracking
  void initializeService(String serviceName) {
    _serviceId = '${serviceName}_$hashCode';
    EnhancedMemoryManager.registerResource('Service', _serviceId);
  }

  /// Add a subscription with enhanced tracking
  void addSubscription(StreamSubscription subscription) {
    if (_isDisposed) return;
    _subscriptions.add(subscription);
    final subscriptionId = '${_serviceId}_sub_${subscription.hashCode}';
    EnhancedMemoryManager.registerResource(
        'ServiceSubscription', subscriptionId);
    _registeredResources.add('ServiceSubscription:$subscriptionId');
  }

  /// Add a timer with enhanced tracking
  void addTimer(Timer timer) {
    if (_isDisposed) return;
    _timers.add(timer);
    final timerId = '${_serviceId}_timer_${timer.hashCode}';
    EnhancedMemoryManager.registerResource('ServiceTimer', timerId);
    _registeredResources.add('ServiceTimer:$timerId');
  }

  /// Register a custom resource
  void registerResource(String type, String id) {
    if (_isDisposed) return;
    final resourceId = '${_serviceId}_${type}_$id';
    EnhancedMemoryManager.registerResource(type, resourceId);
    _registeredResources.add('$type:$resourceId');
  }

  /// Touch service resource to update access time
  void touchService() {
    if (!_isDisposed) {
      EnhancedMemoryManager.touchResource('Service', _serviceId);
    }
  }

  /// Dispose of all resources with enhanced cleanup
  void disposeResources() {
    if (_isDisposed) return;
    _isDisposed = true;

    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Cancel all timers
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();

    // Unregister all resources
    for (final resource in _registeredResources) {
      final parts = resource.split(':');
      if (parts.length == 2) {
        EnhancedMemoryManager.unregisterResource(parts[0], parts[1]);
      }
    }
    _registeredResources.clear();

    // Unregister service
    EnhancedMemoryManager.unregisterResource('Service', _serviceId);
  }

  /// Check if service is disposed
  bool get isDisposed => _isDisposed;
}
