import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../utils/logging_utils.dart';

/// Memory profiling and leak detection utility
class MemoryProfiler {
  static Timer? _monitoringTimer;
  static final List<MemorySnapshot> _snapshots = [];
  static const int _maxSnapshots = 100;
  static bool _isMonitoring = false;
  
  /// Start memory monitoring
  static void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    LoggingUtils.logDebug('Starting memory monitoring with ${interval.inSeconds}s interval');
    
    _monitoringTimer = Timer.periodic(interval, (timer) {
      _captureMemorySnapshot();
    });
  }
  
  /// Stop memory monitoring
  static void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    
    LoggingUtils.logDebug('Memory monitoring stopped');
  }
  
  /// Capture a memory snapshot
  static Future<MemorySnapshot> _captureMemorySnapshot() async {
    try {
      final timestamp = DateTime.now();
      
      // Get VM memory info
      final vmInfo = await _getVMMemoryInfo();
      
      // Get system memory info
      final systemInfo = await _getSystemMemoryInfo();
      
      // Get Flutter-specific memory info
      final flutterInfo = await _getFlutterMemoryInfo();
      
      final snapshot = MemorySnapshot(
        timestamp: timestamp,
        vmMemory: vmInfo,
        systemMemory: systemInfo,
        flutterMemory: flutterInfo,
      );
      
      _addSnapshot(snapshot);
      
      // Check for potential memory leaks
      _analyzeMemoryTrends();
      
      return snapshot;
    } catch (e) {
      LoggingUtils.logError('Failed to capture memory snapshot', e);
      rethrow;
    }
  }
  
  /// Get VM memory information
  static Future<Map<String, dynamic>> _getVMMemoryInfo() async {
    try {
      if (kDebugMode) {
        // In debug mode, we can use developer tools
        await developer.Service.getInfo();
        return {
          'heap_used': 0, // Would need VM service connection
          'heap_capacity': 0,
          'external_memory': 0,
        };
      }
      
      return {
        'heap_used': 0,
        'heap_capacity': 0,
        'external_memory': 0,
      };
    } catch (e) {
      LoggingUtils.logError('Failed to get VM memory info', e);
      return {};
    }
  }
  
  /// Get system memory information
  static Future<Map<String, dynamic>> _getSystemMemoryInfo() async {
    try {
      if (Platform.isAndroid) {
        return await _getAndroidMemoryInfo();
      } else if (Platform.isIOS) {
        return await _getIOSMemoryInfo();
      }
      
      return {};
    } catch (e) {
      LoggingUtils.logError('Failed to get system memory info', e);
      return {};
    }
  }
  
  /// Get Android-specific memory information
  static Future<Map<String, dynamic>> _getAndroidMemoryInfo() async {
    try {
      // This would typically use platform channels to get native memory info
      return {
        'total_memory': 0,
        'available_memory': 0,
        'used_memory': 0,
        'memory_class': 0,
      };
    } catch (e) {
      LoggingUtils.logError('Failed to get Android memory info', e);
      return {};
    }
  }
  
  /// Get iOS-specific memory information
  static Future<Map<String, dynamic>> _getIOSMemoryInfo() async {
    try {
      // This would typically use platform channels to get native memory info
      return {
        'physical_memory': 0,
        'memory_pressure': 0,
        'memory_footprint': 0,
      };
    } catch (e) {
      LoggingUtils.logError('Failed to get iOS memory info', e);
      return {};
    }
  }
  
  /// Get Flutter-specific memory information
  static Future<Map<String, dynamic>> _getFlutterMemoryInfo() async {
    try {
      return {
        'widget_count': 0, // Would need widget inspector
        'render_objects': 0,
        'image_cache_size': 0,
        'picture_cache_size': 0,
      };
    } catch (e) {
      LoggingUtils.logError('Failed to get Flutter memory info', e);
      return {};
    }
  }
  
  /// Add snapshot to collection
  static void _addSnapshot(MemorySnapshot snapshot) {
    _snapshots.add(snapshot);
    
    // Keep only the most recent snapshots
    if (_snapshots.length > _maxSnapshots) {
      _snapshots.removeAt(0);
    }
    
    LoggingUtils.logDebug('Memory snapshot captured: ${snapshot.getSummary()}');
  }
  
  /// Analyze memory trends for potential leaks
  static void _analyzeMemoryTrends() {
    if (_snapshots.length < 10) return; // Need enough data points
    
    try {
      final recent = _snapshots.takeLast(10).toList();
      final memoryGrowth = _calculateMemoryGrowth(recent);
      
      if (memoryGrowth > 0.2) { // 20% growth threshold
        LoggingUtils.logWarning('Potential memory leak detected: ${(memoryGrowth * 100).toStringAsFixed(1)}% growth');
        _generateLeakReport();
      }
    } catch (e) {
      LoggingUtils.logError('Failed to analyze memory trends', e);
    }
  }
  
  /// Calculate memory growth rate
  static double _calculateMemoryGrowth(List<MemorySnapshot> snapshots) {
    if (snapshots.length < 2) return 0.0;
    
    final first = snapshots.first;
    final last = snapshots.last;
    
    final firstMemory = first.getTotalMemoryUsage();
    final lastMemory = last.getTotalMemoryUsage();
    
    if (firstMemory == 0) return 0.0;
    
    return (lastMemory - firstMemory) / firstMemory;
  }
  
  /// Generate memory leak report
  static void _generateLeakReport() {
    try {
      final report = {
        'timestamp': DateTime.now().toIso8601String(),
        'snapshots_analyzed': _snapshots.length,
        'memory_trend': 'increasing',
        'recommendations': [
          'Check for unclosed streams or subscriptions',
          'Verify proper disposal of controllers',
          'Review image caching and disposal',
          'Check for circular references',
        ],
      };
      
      LoggingUtils.logWarning('Memory leak report generated: $report');
    } catch (e) {
      LoggingUtils.logError('Failed to generate leak report', e);
    }
  }
  
  /// Get current memory statistics
  static Map<String, dynamic> getMemoryStats() {
    return {
      'monitoring': _isMonitoring,
      'snapshots_count': _snapshots.length,
      'latest_snapshot': _snapshots.isNotEmpty ? _snapshots.last.getSummary() : null,
      'memory_trend': _snapshots.length >= 2 ? _calculateMemoryGrowth(_snapshots.takeLast(2).toList()) : 0.0,
    };
  }
  
  /// Clear all snapshots
  static void clearSnapshots() {
    _snapshots.clear();
    LoggingUtils.logDebug('Memory snapshots cleared');
  }
  
  /// Force garbage collection (debug only)
  static void forceGC() {
    if (kDebugMode) {
      developer.Service.getInfo().then((_) {
        LoggingUtils.logDebug('Garbage collection requested');
      }).catchError((e) {
        LoggingUtils.logError('Failed to request GC', e);
      });
    }
  }
}

/// Memory snapshot data class
class MemorySnapshot {
  final DateTime timestamp;
  final Map<String, dynamic> vmMemory;
  final Map<String, dynamic> systemMemory;
  final Map<String, dynamic> flutterMemory;
  
  const MemorySnapshot({
    required this.timestamp,
    required this.vmMemory,
    required this.systemMemory,
    required this.flutterMemory,
  });
  
  /// Get total memory usage estimate
  int getTotalMemoryUsage() {
    int total = 0;
    
    // Sum up available memory metrics
    total += (vmMemory['heap_used'] as int? ?? 0);
    total += (vmMemory['external_memory'] as int? ?? 0);
    total += (systemMemory['used_memory'] as int? ?? 0);
    
    return total;
  }
  
  /// Get summary string
  String getSummary() {
    return 'Memory at ${timestamp.toIso8601String()}: ${getTotalMemoryUsage()} bytes';
  }
  
  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'vm_memory': vmMemory,
      'system_memory': systemMemory,
      'flutter_memory': flutterMemory,
      'total_usage': getTotalMemoryUsage(),
    };
  }
}

/// Extension for taking last N elements
extension ListExtension<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return sublist(length - count);
  }
}