/// Performance optimization utilities
/// Provides helpers for reducing widget rebuilds and improving app performance
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'memory_utils.dart';

/// Utility class for performance optimizations
class PerformanceUtils {
  // Private constructor to prevent instantiation
  const PerformanceUtils._();

  /// Debounce function calls to prevent excessive executions
  static final Map<String, Timer?> _debounceTimers = {};
  
  static void debounce(String key, Duration delay, VoidCallback callback) {
    // Cancel existing timer and unregister
    final existingTimer = _debounceTimers[key];
    if (existingTimer != null) {
      existingTimer.cancel();
      MemoryUtils.unregisterResource('PerformanceTimer', key);
    }
    
    // Create new timer and register
    final newTimer = Timer(delay, callback);
    _debounceTimers[key] = newTimer;
    MemoryUtils.registerResource('PerformanceTimer', key);
  }

  /// Throttle function calls to limit execution frequency
  static final Map<String, DateTime> _throttleTimestamps = {};
  
  static bool throttle(String key, Duration interval, VoidCallback callback) {
    final now = DateTime.now();
    final lastExecution = _throttleTimestamps[key];
    
    if (lastExecution == null || now.difference(lastExecution) >= interval) {
      _throttleTimestamps[key] = now;
      callback();
      return true;
    }
    return false;
  }

  /// Batch multiple setState calls into a single frame update
  static void batchStateUpdates(List<VoidCallback> updates) {
    if (updates.isEmpty) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final update in updates) {
        update();
      }
    });
  }

  /// Check if widget should rebuild based on data changes
  static bool shouldRebuild<T>(T? oldValue, T? newValue) {
    if (oldValue == null && newValue == null) return false;
    if (oldValue == null || newValue == null) return true;
    return oldValue != newValue;
  }

  /// Memoize expensive computations
  static final Map<String, dynamic> _memoCache = {};
  
  static T memoize<T>(String key, T Function() computation) {
    if (_memoCache.containsKey(key)) {
      return _memoCache[key] as T;
    }
    
    final result = computation();
    _memoCache[key] = result;
    return result;
  }

  /// Clear memoization cache
  static void clearMemoCache([String? key]) {
    if (key != null) {
      _memoCache.remove(key);
    } else {
      _memoCache.clear();
    }
  }

  /// Clean up performance utilities
  static void dispose() {
    // Cancel and unregister all timers
    for (final entry in _debounceTimers.entries) {
      final timer = entry.value;
      if (timer != null) {
        timer.cancel();
        MemoryUtils.unregisterResource('PerformanceTimer', entry.key);
      }
    }
    _debounceTimers.clear();
    _throttleTimestamps.clear();
    _memoCache.clear();
  }
}

/// Mixin for widgets that need performance optimizations
mixin PerformanceOptimizedMixin<T extends StatefulWidget> on State<T> {
  /// Debounced setState to prevent excessive rebuilds
  void debouncedSetState(VoidCallback fn, {Duration delay = const Duration(milliseconds: 100)}) {
    PerformanceUtils.debounce(
      '${widget.runtimeType}_setState',
      delay,
      () {
        if (mounted) {
          setState(fn);
        }
      },
    );
  }

  /// Throttled setState to limit rebuild frequency
  void throttledSetState(VoidCallback fn, {Duration interval = const Duration(milliseconds: 16)}) {
    PerformanceUtils.throttle(
      '${widget.runtimeType}_setState',
      interval,
      () {
        if (mounted) {
          setState(fn);
        }
      },
    );
  }

  @override
  void dispose() {
    // Clean up any performance-related resources
    PerformanceUtils.clearMemoCache('${widget.runtimeType}');
    
    // Unregister widget-specific resources
    MemoryUtils.unregisterResource('PerformanceWidget', widget.runtimeType.toString());
    
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Register widget for performance tracking
    MemoryUtils.registerResource('PerformanceWidget', widget.runtimeType.toString());
  }
}

// Timer is imported from dart:async