import 'dart:async';
import 'dart:collection';

import 'logging_utils.dart';
import 'memory_utils.dart';
import 'enhanced_memory_manager.dart';

/// Advanced memory leak detector with pattern recognition
/// and automated remediation suggestions
class MemoryLeakDetector {
  static final MemoryLeakDetector _instance = MemoryLeakDetector._internal();
  factory MemoryLeakDetector() => _instance;
  MemoryLeakDetector._internal();

  // Detection configuration
  static const Duration _detectionInterval = Duration(minutes: 2);
  static const int _historySize = 50;
  static const double _growthThreshold = 0.3; // 30% growth
  static const int _minSamplesForDetection = 5;
  
  // Leak patterns and thresholds
  static final Map<String, _LeakPattern> _leakPatterns = {
    'timer': _LeakPattern(
      threshold: 5,
      growthRate: 0.2,
      description: 'Uncanceled timers',
      remediation: 'Ensure all timers are canceled in dispose() methods',
    ),
    'streamsubscription': _LeakPattern(
      threshold: 8,
      growthRate: 0.25,
      description: 'Unclosed stream subscriptions',
      remediation: 'Cancel all stream subscriptions in dispose() methods',
    ),
    'httprequest': _LeakPattern(
      threshold: 15,
      growthRate: 0.4,
      description: 'Hanging HTTP requests',
      remediation: 'Implement request timeouts and proper connection cleanup',
    ),
    'widget': _LeakPattern(
      threshold: 50,
      growthRate: 0.5,
      description: 'Widget instances not being disposed',
      remediation: 'Check for circular references and ensure proper widget disposal',
    ),
    'cacheentry': _LeakPattern(
      threshold: 200,
      growthRate: 0.6,
      description: 'Cache entries accumulating',
      remediation: 'Implement cache size limits and expiration policies',
    ),
  };
  
  // Detection state
  static Timer? _detectionTimer;
  static bool _isDetecting = false;
  static final Queue<_ResourceSnapshot> _resourceHistory = Queue();
  static final Map<String, _LeakInfo> _detectedLeaks = {};
  static final List<_LeakReport> _leakReports = [];
  
  // Statistics
  static int _totalDetectionRuns = 0;
  static int _totalLeaksFound = 0;
  static int _falsePositives = 0;
  
  /// Start leak detection
  static void startDetection() {
    if (_isDetecting) return;
    
    _isDetecting = true;
    LoggingUtils.logDebug('Starting memory leak detection');
    
    _detectionTimer = Timer.periodic(_detectionInterval, (_) {
      _performLeakDetection();
    });
  }
  
  /// Stop leak detection
  static void stopDetection() {
    if (!_isDetecting) return;
    
    _isDetecting = false;
    _detectionTimer?.cancel();
    _detectionTimer = null;
    
    LoggingUtils.logDebug('Memory leak detection stopped');
  }
  
  /// Perform leak detection analysis
  static void _performLeakDetection() {
    try {
      _totalDetectionRuns++;
      
      // Capture current resource snapshot
      final snapshot = _captureResourceSnapshot();
      _addResourceSnapshot(snapshot);
      
      // Analyze for leaks if we have enough history
      if (_resourceHistory.length >= _minSamplesForDetection) {
        _analyzeForLeaks();
      }
      
      // Clean up old data
      _cleanupOldData();
      
    } catch (e) {
      LoggingUtils.logError('Error during leak detection', e);
    }
  }
  
  /// Capture current resource snapshot
  static _ResourceSnapshot _captureResourceSnapshot() {
    final resourceCounts = MemoryUtils.getResourceCounts();
    final enhancedStats = EnhancedMemoryManager.getMemoryStatistics();
    
    return _ResourceSnapshot(
      timestamp: DateTime.now(),
      resourceCounts: Map.from(resourceCounts),
      totalResources: resourceCounts.values.fold(0, (sum, count) => sum + count),
      enhancedResourceCount: enhancedStats['current_resources'] as int? ?? 0,
    );
  }
  
  /// Add resource snapshot to history
  static void _addResourceSnapshot(_ResourceSnapshot snapshot) {
    _resourceHistory.add(snapshot);
    
    // Keep history within limits
    while (_resourceHistory.length > _historySize) {
      _resourceHistory.removeFirst();
    }
  }
  
  /// Analyze resource history for potential leaks
  static void _analyzeForLeaks() {
    final snapshots = _resourceHistory.toList();
    
    // Analyze each resource type
    final allResourceTypes = <String>{};
    for (final snapshot in snapshots) {
      allResourceTypes.addAll(snapshot.resourceCounts.keys);
    }
    
    for (final resourceType in allResourceTypes) {
      _analyzeResourceType(resourceType, snapshots);
    }
    
    // Analyze overall memory growth
    _analyzeOverallGrowth(snapshots);
  }
  
  /// Analyze specific resource type for leaks
  static void _analyzeResourceType(String resourceType, List<_ResourceSnapshot> snapshots) {
    final counts = snapshots
        .map((s) => s.resourceCounts[resourceType] ?? 0)
        .toList();
    
    if (counts.length < _minSamplesForDetection) return;
    
    // Calculate growth metrics
    final firstCount = counts.first;
    final lastCount = counts.last;
    final maxCount = counts.reduce((a, b) => a > b ? a : b);
    final avgCount = counts.reduce((a, b) => a + b) / counts.length;
    
    // Check for consistent growth
    final growthRate = firstCount > 0 ? (lastCount - firstCount) / firstCount : 0.0;
    final isGrowing = _isConsistentlyGrowing(counts);
    
    // Get pattern for this resource type
    final pattern = _getLeakPattern(resourceType);
    
    // Determine if this is a leak
    final isLeak = _isResourceLeak(
      resourceType: resourceType,
      currentCount: lastCount,
      maxCount: maxCount,
      avgCount: avgCount,
      growthRate: growthRate,
      isGrowing: isGrowing,
      pattern: pattern,
    );
    
    if (isLeak) {
      _reportLeak(resourceType, lastCount, growthRate, pattern);
    } else {
      // Remove from detected leaks if it was previously detected
      _detectedLeaks.remove(resourceType);
    }
  }
  
  /// Check if resource counts are consistently growing
  static bool _isConsistentlyGrowing(List<int> counts) {
    if (counts.length < 3) return false;
    
    int growthCount = 0;
    for (int i = 1; i < counts.length; i++) {
      if (counts[i] > counts[i - 1]) {
        growthCount++;
      }
    }
    
    // Consider it growing if more than 60% of samples show growth
    return growthCount > (counts.length * 0.6);
  }
  
  /// Get leak pattern for resource type
  static _LeakPattern _getLeakPattern(String resourceType) {
    final normalizedType = resourceType.toLowerCase();
    
    for (final entry in _leakPatterns.entries) {
      if (normalizedType.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Default pattern for unknown resource types
    return _LeakPattern(
      threshold: 10,
      growthRate: 0.3,
      description: 'Unknown resource type accumulation',
      remediation: 'Review resource disposal patterns for $resourceType',
    );
  }
  
  /// Determine if resource pattern indicates a leak
  static bool _isResourceLeak({
    required String resourceType,
    required int currentCount,
    required int maxCount,
    required double avgCount,
    required double growthRate,
    required bool isGrowing,
    required _LeakPattern pattern,
  }) {
    // Check absolute threshold
    if (currentCount > pattern.threshold) {
      return true;
    }
    
    // Check growth rate
    if (isGrowing && growthRate > pattern.growthRate) {
      return true;
    }
    
    // Check if current count is significantly above average
    if (currentCount > avgCount * 2 && currentCount > 5) {
      return true;
    }
    
    return false;
  }
  
  /// Report detected leak
  static void _reportLeak(String resourceType, int count, double growthRate, _LeakPattern pattern) {
    final existingLeak = _detectedLeaks[resourceType];
    final now = DateTime.now();
    
    if (existingLeak == null) {
      // New leak detected
      _detectedLeaks[resourceType] = _LeakInfo(
        resourceType: resourceType,
        firstDetected: now,
        lastDetected: now,
        peakCount: count,
        currentCount: count,
        growthRate: growthRate,
        pattern: pattern,
        reportCount: 1,
      );
      
      _totalLeaksFound++;
      _generateLeakReport(resourceType, count, growthRate, pattern, isNew: true);
      
    } else {
      // Update existing leak
      _detectedLeaks[resourceType] = existingLeak.copyWith(
        lastDetected: now,
        peakCount: count > existingLeak.peakCount ? count : existingLeak.peakCount,
        currentCount: count,
        growthRate: growthRate,
        reportCount: existingLeak.reportCount + 1,
      );
      
      // Report again if it's getting worse
      if (count > existingLeak.peakCount * 1.5) {
        _generateLeakReport(resourceType, count, growthRate, pattern, isNew: false);
      }
    }
  }
  
  /// Generate detailed leak report
  static void _generateLeakReport(String resourceType, int count, double growthRate, _LeakPattern pattern, {required bool isNew}) {
    final severity = _calculateLeakSeverity(count, growthRate, pattern);
    
    final report = _LeakReport(
      timestamp: DateTime.now(),
      resourceType: resourceType,
      count: count,
      growthRate: growthRate,
      severity: severity,
      pattern: pattern,
      isNew: isNew,
      recommendations: _generateRecommendations(resourceType, count, growthRate, pattern),
    );
    
    _leakReports.add(report);
    
    // Keep only recent reports
    if (_leakReports.length > 100) {
      _leakReports.removeAt(0);
    }
    
    // Log the report
    final statusText = isNew ? 'NEW LEAK DETECTED' : 'LEAK WORSENING';
    LoggingUtils.logWarning('$statusText: $resourceType - $count instances (${(growthRate * 100).toStringAsFixed(1)}% growth) - Severity: ${severity.name}');
    LoggingUtils.logWarning('Remediation: ${pattern.remediation}');
    
    // Log recommendations
    for (final recommendation in report.recommendations) {
      LoggingUtils.logWarning('Recommendation: $recommendation');
    }
  }
  
  /// Calculate leak severity
  static _LeakSeverity _calculateLeakSeverity(int count, double growthRate, _LeakPattern pattern) {
    final countRatio = count / pattern.threshold;
    final growthRatio = growthRate / pattern.growthRate;
    
    final severityScore = (countRatio * 0.6) + (growthRatio * 0.4);
    
    if (severityScore > 3.0) {
      return _LeakSeverity.critical;
    } else if (severityScore > 2.0) {
      return _LeakSeverity.high;
    } else if (severityScore > 1.5) {
      return _LeakSeverity.medium;
    } else {
      return _LeakSeverity.low;
    }
  }
  
  /// Generate specific recommendations for the leak
  static List<String> _generateRecommendations(String resourceType, int count, double growthRate, _LeakPattern pattern) {
    final recommendations = <String>[pattern.remediation];
    
    // Add specific recommendations based on resource type and severity
    final normalizedType = resourceType.toLowerCase();
    
    if (normalizedType.contains('timer')) {
      recommendations.addAll([
        'Use Timer.periodic with proper cancellation in dispose()',
        'Consider using addTimer() from ResourceCleanupMixin',
        'Check for timers created in build() methods',
      ]);
    } else if (normalizedType.contains('subscription')) {
      recommendations.addAll([
        'Use addSubscription() from ResourceCleanupMixin',
        'Ensure StreamController.close() is called',
        'Check for subscriptions in initState() without disposal',
      ]);
    } else if (normalizedType.contains('http')) {
      recommendations.addAll([
        'Implement connection pooling and reuse',
        'Set appropriate timeouts for requests',
        'Use request deduplication for identical requests',
      ]);
    } else if (normalizedType.contains('cache')) {
      recommendations.addAll([
        'Implement LRU or TTL-based cache eviction',
        'Set maximum cache size limits',
        'Use weak references for cached objects where appropriate',
      ]);
    }
    
    // Add severity-based recommendations
    if (count > pattern.threshold * 3) {
      recommendations.add('URGENT: Consider immediate cleanup or service restart');
    }
    
    if (growthRate > 0.5) {
      recommendations.add('High growth rate detected - investigate recent code changes');
    }
    
    return recommendations;
  }
  
  /// Analyze overall memory growth patterns
  static void _analyzeOverallGrowth(List<_ResourceSnapshot> snapshots) {
    final totalCounts = snapshots.map((s) => s.totalResources).toList();
    
    if (totalCounts.length < _minSamplesForDetection) return;
    
    final firstTotal = totalCounts.first;
    final lastTotal = totalCounts.last;
    
    if (firstTotal > 0) {
      final overallGrowth = (lastTotal - firstTotal) / firstTotal;
      
      if (overallGrowth > _growthThreshold) {
        LoggingUtils.logWarning('Overall memory growth detected: ${(overallGrowth * 100).toStringAsFixed(1)}% increase in total resources');
        LoggingUtils.logWarning('Total resources: $firstTotal → $lastTotal');
      }
    }
  }
  
  /// Clean up old detection data
  static void _cleanupOldData() {
    final cutoffTime = DateTime.now().subtract(const Duration(hours: 1));
    
    // Clean up old leak reports
    _leakReports.removeWhere((report) => report.timestamp.isBefore(cutoffTime));
    
    // Clean up resolved leaks
    final resolvedLeaks = <String>[];
    _detectedLeaks.forEach((type, leak) {
      if (leak.lastDetected.isBefore(cutoffTime)) {
        resolvedLeaks.add(type);
      }
    });
    
    for (final type in resolvedLeaks) {
      _detectedLeaks.remove(type);
      LoggingUtils.logDebug('Leak resolved: $type');
    }
  }
  
  /// Force immediate leak detection
  static void forceDetection() {
    LoggingUtils.logDebug('Forcing immediate leak detection');
    _performLeakDetection();
  }
  
  /// Get current leak detection statistics
  static Map<String, dynamic> getDetectionStatistics() {
    final activeLeaks = _detectedLeaks.values.map((leak) => {
      'type': leak.resourceType,
      'count': leak.currentCount,
      'growth_rate': leak.growthRate,
      'severity': leak.calculateSeverity().name,
      'first_detected': leak.firstDetected.toIso8601String(),
      'report_count': leak.reportCount,
    }).toList();
    
    return {
      'detection_active': _isDetecting,
      'total_detection_runs': _totalDetectionRuns,
      'total_leaks_found': _totalLeaksFound,
      'false_positives': _falsePositives,
      'active_leaks': activeLeaks,
      'recent_reports': _leakReports.length,
      'resource_history_size': _resourceHistory.length,
    };
  }
  
  /// Get detailed leak reports
  static List<Map<String, dynamic>> getLeakReports({int? limit}) {
    final reports = _leakReports.reversed.toList();
    final limitedReports = limit != null ? reports.take(limit) : reports;
    
    return limitedReports.map((report) => {
      'timestamp': report.timestamp.toIso8601String(),
      'resource_type': report.resourceType,
      'count': report.count,
      'growth_rate': report.growthRate,
      'severity': report.severity.name,
      'is_new': report.isNew,
      'recommendations': report.recommendations,
    }).toList();
  }
  
  /// Mark a leak as false positive
  static void markFalsePositive(String resourceType) {
    if (_detectedLeaks.containsKey(resourceType)) {
      _detectedLeaks.remove(resourceType);
      _falsePositives++;
      LoggingUtils.logDebug('Marked $resourceType as false positive');
    }
  }
  
  /// Clear all detection data
  static void clearDetectionData() {
    _resourceHistory.clear();
    _detectedLeaks.clear();
    _leakReports.clear();
    _totalDetectionRuns = 0;
    _totalLeaksFound = 0;
    _falsePositives = 0;
    
    LoggingUtils.logDebug('All leak detection data cleared');
  }
  
  /// Dispose the leak detector
  static void dispose() {
    stopDetection();
    clearDetectionData();
    LoggingUtils.logDebug('Memory leak detector disposed');
  }
}

/// Resource snapshot for leak detection
class _ResourceSnapshot {
  final DateTime timestamp;
  final Map<String, int> resourceCounts;
  final int totalResources;
  final int enhancedResourceCount;
  
  const _ResourceSnapshot({
    required this.timestamp,
    required this.resourceCounts,
    required this.totalResources,
    required this.enhancedResourceCount,
  });
}

/// Leak pattern definition
class _LeakPattern {
  final int threshold;
  final double growthRate;
  final String description;
  final String remediation;
  
  const _LeakPattern({
    required this.threshold,
    required this.growthRate,
    required this.description,
    required this.remediation,
  });
}

/// Leak information tracking
class _LeakInfo {
  final String resourceType;
  final DateTime firstDetected;
  final DateTime lastDetected;
  final int peakCount;
  final int currentCount;
  final double growthRate;
  final _LeakPattern pattern;
  final int reportCount;
  
  const _LeakInfo({
    required this.resourceType,
    required this.firstDetected,
    required this.lastDetected,
    required this.peakCount,
    required this.currentCount,
    required this.growthRate,
    required this.pattern,
    required this.reportCount,
  });
  
  _LeakInfo copyWith({
    String? resourceType,
    DateTime? firstDetected,
    DateTime? lastDetected,
    int? peakCount,
    int? currentCount,
    double? growthRate,
    _LeakPattern? pattern,
    int? reportCount,
  }) {
    return _LeakInfo(
      resourceType: resourceType ?? this.resourceType,
      firstDetected: firstDetected ?? this.firstDetected,
      lastDetected: lastDetected ?? this.lastDetected,
      peakCount: peakCount ?? this.peakCount,
      currentCount: currentCount ?? this.currentCount,
      growthRate: growthRate ?? this.growthRate,
      pattern: pattern ?? this.pattern,
      reportCount: reportCount ?? this.reportCount,
    );
  }
  
  _LeakSeverity calculateSeverity() {
    final countRatio = currentCount / pattern.threshold;
    final growthRatio = growthRate / pattern.growthRate;
    final severityScore = (countRatio * 0.6) + (growthRatio * 0.4);
    
    if (severityScore > 3.0) {
      return _LeakSeverity.critical;
    } else if (severityScore > 2.0) {
      return _LeakSeverity.high;
    } else if (severityScore > 1.5) {
      return _LeakSeverity.medium;
    } else {
      return _LeakSeverity.low;
    }
  }
}

/// Leak report
class _LeakReport {
  final DateTime timestamp;
  final String resourceType;
  final int count;
  final double growthRate;
  final _LeakSeverity severity;
  final _LeakPattern pattern;
  final bool isNew;
  final List<String> recommendations;
  
  const _LeakReport({
    required this.timestamp,
    required this.resourceType,
    required this.count,
    required this.growthRate,
    required this.severity,
    required this.pattern,
    required this.isNew,
    required this.recommendations,
  });
}

/// Leak severity levels
enum _LeakSeverity {
  low,
  medium,
  high,
  critical,
}