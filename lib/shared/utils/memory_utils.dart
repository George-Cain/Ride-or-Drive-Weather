/// Memory management utilities for Flutter applications
/// Provides tools for monitoring memory usage and preventing memory leaks
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'logging_utils.dart';

/// Utility class for memory management and leak prevention
class MemoryUtils {
  // Private constructor to prevent instantiation
  const MemoryUtils._();

  /// Track active resources for debugging
  static final Map<String, int> _resourceCounts = {};
  static final Set<String> _activeResources = {};

  /// Register a resource for tracking
  static void registerResource(String resourceType, String resourceId) {
    if (kDebugMode) {
      _resourceCounts[resourceType] = (_resourceCounts[resourceType] ?? 0) + 1;
      _activeResources.add('$resourceType:$resourceId');
      LoggingUtils.logDebug('Resource registered: $resourceType:$resourceId (total $resourceType: ${_resourceCounts[resourceType]})');
    }
  }

  /// Unregister a resource
  static void unregisterResource(String resourceType, String resourceId) {
    if (kDebugMode) {
      _resourceCounts[resourceType] = (_resourceCounts[resourceType] ?? 1) - 1;
      _activeResources.remove('$resourceType:$resourceId');
      LoggingUtils.logDebug('Resource unregistered: $resourceType:$resourceId (total $resourceType: ${_resourceCounts[resourceType]})');
    }
  }

  /// Get current resource counts
  static Map<String, int> getResourceCounts() {
    return Map.unmodifiable(_resourceCounts);
  }

  /// Get active resources
  static Set<String> getActiveResources() {
    return Set.unmodifiable(_activeResources);
  }

  /// Check for potential memory leaks
  static void checkForLeaks() {
    if (kDebugMode) {
      final suspiciousResources = <String>[];
      
      _resourceCounts.forEach((type, count) {
        if (count > 10) { // Threshold for suspicious resource count
          suspiciousResources.add('$type: $count instances');
        }
      });

      if (suspiciousResources.isNotEmpty) {
        LoggingUtils.logWarning('Potential memory leaks detected: ${suspiciousResources.join(', ')}');
      }
    }
  }

  /// Clear all resource tracking (for testing)
  static void clearTracking() {
    if (kDebugMode) {
      _resourceCounts.clear();
      _activeResources.clear();
    }
  }
}

/// Mixin for widgets that need proper resource cleanup
mixin ResourceCleanupMixin<T extends StatefulWidget> on State<T> {
  final List<StreamSubscription> _subscriptions = [];
  final List<Timer> _timers = [];
  final Set<String> _registeredResources = {};

  /// Add a subscription to be cleaned up on dispose
  void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
    MemoryUtils.registerResource('StreamSubscription', subscription.hashCode.toString());
    _registeredResources.add('StreamSubscription:${subscription.hashCode}');
  }

  /// Add a timer to be cleaned up on dispose
  void addTimer(Timer timer) {
    _timers.add(timer);
    MemoryUtils.registerResource('Timer', timer.hashCode.toString());
    _registeredResources.add('Timer:${timer.hashCode}');
  }

  /// Register a custom resource
  void registerResource(String type, String id) {
    MemoryUtils.registerResource(type, id);
    _registeredResources.add('$type:$id');
  }

  /// Unregister a custom resource
  void unregisterResource(String type, String id) {
    MemoryUtils.unregisterResource(type, id);
    _registeredResources.remove('$type:$id');
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
      MemoryUtils.unregisterResource('StreamSubscription', subscription.hashCode.toString());
    }
    _subscriptions.clear();

    // Cancel all timers
    for (final timer in _timers) {
      timer.cancel();
      MemoryUtils.unregisterResource('Timer', timer.hashCode.toString());
    }
    _timers.clear();

    // Unregister all custom resources
    for (final resource in _registeredResources) {
      final parts = resource.split(':');
      if (parts.length == 2) {
        MemoryUtils.unregisterResource(parts[0], parts[1]);
      }
    }
    _registeredResources.clear();

    super.dispose();
  }
}

/// Mixin for services that need proper resource cleanup
mixin ServiceResourceMixin {
  final List<StreamSubscription> _subscriptions = [];
  final List<Timer> _timers = [];
  final Set<String> _registeredResources = {};
  bool _isDisposed = false;

  /// Add a subscription to be cleaned up on dispose
  void addSubscription(StreamSubscription subscription) {
    if (_isDisposed) return;
    _subscriptions.add(subscription);
    MemoryUtils.registerResource('ServiceSubscription', subscription.hashCode.toString());
    _registeredResources.add('ServiceSubscription:${subscription.hashCode}');
  }

  /// Add a timer to be cleaned up on dispose
  void addTimer(Timer timer) {
    if (_isDisposed) return;
    _timers.add(timer);
    MemoryUtils.registerResource('ServiceTimer', timer.hashCode.toString());
    _registeredResources.add('ServiceTimer:${timer.hashCode}');
  }

  /// Register a custom resource
  void registerResource(String type, String id) {
    if (_isDisposed) return;
    MemoryUtils.registerResource(type, id);
    _registeredResources.add('$type:$id');
  }

  /// Dispose of all resources
  void disposeResources() {
    if (_isDisposed) return;
    _isDisposed = true;

    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
      MemoryUtils.unregisterResource('ServiceSubscription', subscription.hashCode.toString());
    }
    _subscriptions.clear();

    // Cancel all timers
    for (final timer in _timers) {
      timer.cancel();
      MemoryUtils.unregisterResource('ServiceTimer', timer.hashCode.toString());
    }
    _timers.clear();

    // Unregister all custom resources
    for (final resource in _registeredResources) {
      final parts = resource.split(':');
      if (parts.length == 2) {
        MemoryUtils.unregisterResource(parts[0], parts[1]);
      }
    }
    _registeredResources.clear();
  }

  /// Check if service is disposed
  bool get isDisposed => _isDisposed;
}