/// Advanced performance monitoring service with comprehensive metrics collection
/// and optimization recommendations
library;

import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:isolate';

import '../shared/utils/logging_utils.dart';
import '../shared/utils/enhanced_memory_manager.dart';
import '../shared/utils/memory_profiler.dart';
import '../shared/utils/platform_optimizer.dart';
import '../shared/network/advanced_http_client.dart';
import 'background_service.dart';

/// Comprehensive performance monitoring and optimization service
class AdvancedPerformanceMonitor {
  static AdvancedPerformanceMonitor? _instance;
  static AdvancedPerformanceMonitor get instance =>
      _instance ??= AdvancedPerformanceMonitor._();

  AdvancedPerformanceMonitor._();

  // Monitoring configuration
  static const Duration _monitoringInterval = Duration(seconds: 10);
  static const Duration _reportingInterval = Duration(minutes: 5);
  static const int _maxMetricHistory = 1000;

  // Monitoring state
  bool _isMonitoring = false;
  Timer? _monitoringTimer;
  Timer? _reportingTimer;
  DateTime? _monitoringStartTime;

  // Performance metrics storage
  final Queue<PerformanceSnapshot> _performanceHistory = Queue();
  final Map<String, List<double>> _metricTrends = {};
  final List<PerformanceIssue> _detectedIssues = [];
  final Map<String, int> _issueFrequency = {};

  // Performance counters
  int _totalSnapshots = 0;
  int _performanceWarnings = 0;
  int _criticalIssues = 0;
  DateTime? _lastOptimizationRun;

  // Stream controllers for real-time monitoring
  final StreamController<PerformanceSnapshot> _snapshotController =
      StreamController.broadcast();
  final StreamController<List<OptimizationRecommendation>>
      _recommendationController = StreamController.broadcast();
  final StreamController<PerformanceAlert> _alertController =
      StreamController.broadcast();

  /// Start comprehensive performance monitoring
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _monitoringStartTime = DateTime.now();

    LoggingUtils.logDebug('Starting advanced performance monitoring');

    // Initialize platform optimizer
    await PlatformOptimizer.initialize();

    // Start memory monitoring if not already active
    EnhancedMemoryManager.startMonitoring();
    MemoryProfiler.startMonitoring(interval: _monitoringInterval);

    // Start periodic monitoring
    _monitoringTimer = Timer.periodic(_monitoringInterval, (_) {
      _capturePerformanceSnapshot();
    });

    // Start periodic reporting
    _reportingTimer = Timer.periodic(_reportingInterval, (_) {
      _generatePerformanceReport();
    });

    LoggingUtils.logDebug('Advanced performance monitoring started');
  }

  /// Stop performance monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _reportingTimer?.cancel();
    _monitoringTimer = null;
    _reportingTimer = null;

    LoggingUtils.logDebug('Advanced performance monitoring stopped');
  }

  /// Capture comprehensive performance snapshot
  void _capturePerformanceSnapshot() {
    try {
      final snapshot = PerformanceSnapshot(
        timestamp: DateTime.now(),
        memoryMetrics: _captureMemoryMetrics(),
        networkMetrics: _captureNetworkMetrics(),
        backgroundServiceMetrics: _captureBackgroundServiceMetrics(),
        platformMetrics: _capturePlatformMetrics(),
        uiMetrics: _captureUIMetrics(),
      );

      _performanceHistory.add(snapshot);
      _totalSnapshots++;

      // Maintain history size
      if (_performanceHistory.length > _maxMetricHistory) {
        _performanceHistory.removeFirst();
      }

      // Update metric trends
      _updateMetricTrends(snapshot);

      // Analyze for performance issues
      _analyzePerformanceIssues(snapshot);

      // Emit snapshot to stream
      _snapshotController.add(snapshot);
    } catch (e, stackTrace) {
      LoggingUtils.logError(
          'Failed to capture performance snapshot', e, stackTrace);
    }
  }

  /// Capture memory-related metrics
  Map<String, dynamic> _captureMemoryMetrics() {
    final memoryStats = EnhancedMemoryManager.getMemoryStatistics();
    final profilerStats = MemoryProfiler.getMemoryStats();

    return {
      'enhanced_memory': memoryStats,
      'profiler': profilerStats,
      'dart_heap_size': _getDartHeapSize(),
      'native_heap_size': _getNativeHeapSize(),
    };
  }

  /// Capture network-related metrics
  Map<String, dynamic> _captureNetworkMetrics() {
    return AdvancedHttpClient.getPerformanceMetrics();
  }

  /// Capture background service metrics
  Map<String, dynamic> _captureBackgroundServiceMetrics() {
    return WeatherMonitoringManager().getStatistics();
  }

  /// Capture platform-specific metrics
  Map<String, dynamic> _capturePlatformMetrics() {
    return PlatformOptimizer.getPlatformMetrics();
  }

  /// Capture UI performance metrics
  Map<String, dynamic> _captureUIMetrics() {
    return {
      'frame_rate': _getCurrentFrameRate(),
      'ui_thread_usage': _getUIThreadUsage(),
      'render_time': _getRenderTime(),
    };
  }

  /// Update metric trends for analysis
  void _updateMetricTrends(PerformanceSnapshot snapshot) {
    final metrics = {
      'memory_usage': snapshot.memoryMetrics['enhanced_memory']
                  ?['current_resources']
              ?.toDouble() ??
          0.0,
      'network_success_rate': double.tryParse(snapshot
                  .networkMetrics['performance']?['successRate']
                  ?.toString()
                  .replaceAll('%', '') ??
              '0') ??
          0.0,
      'avg_response_time': snapshot.networkMetrics['performance']
                  ?['avgResponseTime']
              ?.toDouble() ??
          0.0,
      'frame_rate': snapshot.uiMetrics['frame_rate']?.toDouble() ?? 60.0,
    };

    metrics.forEach((key, value) {
      _metricTrends[key] ??= [];
      _metricTrends[key]!.add(value);

      // Keep only recent trends
      if (_metricTrends[key]!.length > 100) {
        _metricTrends[key]!.removeAt(0);
      }
    });
  }

  /// Analyze performance issues and generate alerts
  void _analyzePerformanceIssues(PerformanceSnapshot snapshot) {
    final issues = <PerformanceIssue>[];

    // Memory analysis
    final memoryResources =
        snapshot.memoryMetrics['enhanced_memory']?['current_resources'] ?? 0;
    if (memoryResources > 100) {
      issues.add(PerformanceIssue(
        type: PerformanceIssueType.memory,
        severity: memoryResources > 200
            ? IssueSeverity.critical
            : IssueSeverity.warning,
        description: 'High memory resource count: $memoryResources',
        recommendation:
            'Consider implementing more aggressive resource cleanup',
        timestamp: DateTime.now(),
      ));
    }

    // Network analysis
    final successRate = double.tryParse(snapshot.networkMetrics['performance']
                    ?['successRate']
                ?.toString()
                .replaceAll('%', '') ??
            '100') ??
        100.0;
    if (successRate < 90) {
      issues.add(PerformanceIssue(
        type: PerformanceIssueType.network,
        severity:
            successRate < 70 ? IssueSeverity.critical : IssueSeverity.warning,
        description:
            'Low network success rate: ${successRate.toStringAsFixed(1)}%',
        recommendation: 'Review network error handling and retry logic',
        timestamp: DateTime.now(),
      ));
    }

    // Response time analysis
    final avgResponseTime =
        snapshot.networkMetrics['performance']?['avgResponseTime'] ?? 0;
    if (avgResponseTime > 5000) {
      // 5 seconds
      issues.add(PerformanceIssue(
        type: PerformanceIssueType.network,
        severity: avgResponseTime > 10000
            ? IssueSeverity.critical
            : IssueSeverity.warning,
        description: 'High average response time: ${avgResponseTime}ms',
        recommendation: 'Optimize API calls and consider request caching',
        timestamp: DateTime.now(),
      ));
    }

    // Frame rate analysis
    final frameRate = snapshot.uiMetrics['frame_rate'] ?? 60.0;
    if (frameRate < 45) {
      issues.add(PerformanceIssue(
        type: PerformanceIssueType.ui,
        severity:
            frameRate < 30 ? IssueSeverity.critical : IssueSeverity.warning,
        description: 'Low frame rate: ${frameRate.toStringAsFixed(1)} FPS',
        recommendation: 'Optimize widget rebuilds and use RepaintBoundary',
        timestamp: DateTime.now(),
      ));
    }

    // Process detected issues
    for (final issue in issues) {
      _processPerformanceIssue(issue);
    }
  }

  /// Process and track performance issues
  void _processPerformanceIssue(PerformanceIssue issue) {
    _detectedIssues.add(issue);

    // Update issue frequency
    final key = '${issue.type.name}_${issue.severity.name}';
    _issueFrequency[key] = (_issueFrequency[key] ?? 0) + 1;

    // Update counters
    if (issue.severity == IssueSeverity.warning) {
      _performanceWarnings++;
    } else if (issue.severity == IssueSeverity.critical) {
      _criticalIssues++;
    }

    // Emit alert
    _alertController.add(PerformanceAlert(
      issue: issue,
      frequency: _issueFrequency[key] ?? 1,
      timestamp: DateTime.now(),
    ));

    // Log issue
    final logMessage =
        'Performance ${issue.severity.name}: ${issue.description}';
    if (issue.severity == IssueSeverity.critical) {
      LoggingUtils.logCriticalError('Performance Monitoring', logMessage);
    } else {
      LoggingUtils.logWarning(logMessage);
    }
  }

  /// Generate comprehensive performance report
  void _generatePerformanceReport() {
    try {
      final recommendations = _generateOptimizationRecommendations();
      _recommendationController.add(recommendations);

      LoggingUtils.logSection('Performance Report Generated');
      LoggingUtils.logDebug('Total snapshots: $_totalSnapshots');
      LoggingUtils.logDebug('Performance warnings: $_performanceWarnings');
      LoggingUtils.logDebug('Critical issues: $_criticalIssues');
      LoggingUtils.logDebug('Recommendations: ${recommendations.length}');
    } catch (e, stackTrace) {
      LoggingUtils.logError(
          'Failed to generate performance report', e, stackTrace);
    }
  }

  /// Generate optimization recommendations based on collected data
  List<OptimizationRecommendation> _generateOptimizationRecommendations() {
    final recommendations = <OptimizationRecommendation>[];

    // Memory optimization recommendations
    if (_metricTrends['memory_usage']?.isNotEmpty == true) {
      final memoryTrend = _calculateTrend(_metricTrends['memory_usage']!);
      if (memoryTrend > 0.1) {
        // 10% increase trend
        recommendations.add(OptimizationRecommendation(
          category: OptimizationCategory.memory,
          priority: RecommendationPriority.high,
          title: 'Memory Usage Increasing',
          description:
              'Memory usage has been trending upward by ${(memoryTrend * 100).toStringAsFixed(1)}%',
          actionItems: [
            'Review resource cleanup in dispose methods',
            'Check for memory leaks using MemoryProfiler',
            'Implement more aggressive caching strategies',
            'Consider using WeakReference for large objects',
          ],
          estimatedImpact: 'Reduce memory usage by 15-30%',
        ));
      }
    }

    // Network optimization recommendations
    if (_metricTrends['avg_response_time']?.isNotEmpty == true) {
      final avgResponseTime = _metricTrends['avg_response_time']!.last;
      if (avgResponseTime > 3000) {
        // 3 seconds
        recommendations.add(OptimizationRecommendation(
          category: OptimizationCategory.network,
          priority: avgResponseTime > 5000
              ? RecommendationPriority.high
              : RecommendationPriority.medium,
          title: 'High Network Response Times',
          description:
              'Average response time is ${avgResponseTime.toStringAsFixed(0)}ms',
          actionItems: [
            'Implement request caching for frequently accessed data',
            'Use connection pooling for HTTP requests',
            'Consider request deduplication',
            'Optimize API payload sizes',
            'Implement progressive data loading',
          ],
          estimatedImpact: 'Reduce response times by 40-60%',
        ));
      }
    }

    // UI performance recommendations
    if (_metricTrends['frame_rate']?.isNotEmpty == true) {
      final avgFrameRate =
          _metricTrends['frame_rate']!.fold(0.0, (a, b) => a + b) /
              _metricTrends['frame_rate']!.length;
      if (avgFrameRate < 50) {
        recommendations.add(OptimizationRecommendation(
          category: OptimizationCategory.ui,
          priority: avgFrameRate < 30
              ? RecommendationPriority.high
              : RecommendationPriority.medium,
          title: 'Low Frame Rate Performance',
          description:
              'Average frame rate is ${avgFrameRate.toStringAsFixed(1)} FPS',
          actionItems: [
            'Add RepaintBoundary widgets around expensive widgets',
            'Use const constructors for static widgets',
            'Implement widget caching for complex layouts',
            'Optimize image loading and caching',
            'Review setState usage and consider more granular updates',
          ],
          estimatedImpact: 'Improve frame rate by 20-40%',
        ));
      }
    }

    // Background service optimization
    final backgroundStats = WeatherMonitoringManager().getStatistics();
    final backgroundSuccessRate = _parseSuccessRate(
        backgroundStats['background_service']?['success_rate']);
    if (backgroundSuccessRate < 90) {
      recommendations.add(OptimizationRecommendation(
        category: OptimizationCategory.background,
        priority: backgroundSuccessRate < 70
            ? RecommendationPriority.high
            : RecommendationPriority.medium,
        title: 'Background Service Issues',
        description:
            'Background service success rate is ${backgroundSuccessRate.toStringAsFixed(1)}%',
        actionItems: [
          'Review background task error handling',
          'Implement exponential backoff for failed tasks',
          'Check battery optimization settings',
          'Optimize background task frequency',
          'Add more robust connectivity checks',
        ],
        estimatedImpact: 'Improve background reliability by 25-50%',
      ));
    }

    // Platform-specific recommendations
    final platformMetrics = PlatformOptimizer.getPlatformMetrics();
    if (platformMetrics['hardware_acceleration'] == false) {
      recommendations.add(OptimizationRecommendation(
        category: OptimizationCategory.platform,
        priority: RecommendationPriority.low,
        title: 'Hardware Acceleration Unavailable',
        description: 'Platform does not support hardware acceleration',
        actionItems: [
          'Optimize software rendering paths',
          'Use simpler animations and transitions',
          'Consider platform-specific UI optimizations',
          'Implement fallback rendering strategies',
        ],
        estimatedImpact: 'Improve rendering performance by 10-20%',
      ));
    }

    return recommendations;
  }

  /// Calculate trend from metric values
  double _calculateTrend(List<double> values) {
    if (values.length < 2) return 0.0;

    final first = values.first;
    final last = values.last;

    if (first == 0) return 0.0;

    return (last - first) / first;
  }

  /// Parse success rate string to double
  double _parseSuccessRate(dynamic value) {
    if (value == null) return 100.0;
    final str = value.toString().replaceAll('%', '');
    return double.tryParse(str) ?? 100.0;
  }

  /// Get Dart heap size (mock implementation)
  int _getDartHeapSize() {
    try {
      return developer.Service.getIsolateId(Isolate.current).hashCode;
    } catch (e) {
      return 0;
    }
  }

  /// Get native heap size (mock implementation)
  int _getNativeHeapSize() {
    // This would require platform-specific implementation
    return 0;
  }

  /// Get current frame rate (mock implementation)
  double _getCurrentFrameRate() {
    // This would require integration with Flutter's performance overlay
    return 60.0; // Default assumption
  }

  /// Get UI thread usage (mock implementation)
  double _getUIThreadUsage() {
    // This would require platform-specific implementation
    return 0.5; // 50% usage assumption
  }

  /// Get render time (mock implementation)
  double _getRenderTime() {
    // This would require integration with Flutter's rendering pipeline
    return 16.67; // 60 FPS = 16.67ms per frame
  }

  // =============================================================================
  // PUBLIC API
  // =============================================================================

  /// Check if monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// Get monitoring duration
  Duration? get monitoringDuration {
    if (_monitoringStartTime == null) return null;
    return DateTime.now().difference(_monitoringStartTime!);
  }

  /// Get performance snapshot stream
  Stream<PerformanceSnapshot> get snapshotStream => _snapshotController.stream;

  /// Get optimization recommendation stream
  Stream<List<OptimizationRecommendation>> get recommendationStream =>
      _recommendationController.stream;

  /// Get performance alert stream
  Stream<PerformanceAlert> get alertStream => _alertController.stream;

  /// Get current performance summary
  Map<String, dynamic> getPerformanceSummary() {
    final latestSnapshot =
        _performanceHistory.isNotEmpty ? _performanceHistory.last : null;

    return {
      'monitoring_active': _isMonitoring,
      'monitoring_duration': monitoringDuration?.inMinutes,
      'total_snapshots': _totalSnapshots,
      'performance_warnings': _performanceWarnings,
      'critical_issues': _criticalIssues,
      'latest_snapshot': latestSnapshot?.toMap(),
      'metric_trends': _metricTrends.map((key, values) => MapEntry(key, {
            'current': values.isNotEmpty ? values.last : 0.0,
            'trend': _calculateTrend(values),
            'samples': values.length,
          })),
      'issue_frequency': _issueFrequency,
      'last_optimization_run': _lastOptimizationRun?.toIso8601String(),
    };
  }

  /// Get detailed performance history
  List<Map<String, dynamic>> getPerformanceHistory({int? limit}) {
    final snapshots = limit != null
        ? _performanceHistory.take(limit).toList()
        : _performanceHistory.toList();

    return snapshots.map((snapshot) => snapshot.toMap()).toList();
  }

  /// Get recent performance issues
  List<PerformanceIssue> getRecentIssues({Duration? since}) {
    final cutoff = since != null ? DateTime.now().subtract(since) : null;

    return _detectedIssues.where((issue) {
      return cutoff == null || issue.timestamp.isAfter(cutoff);
    }).toList();
  }

  /// Force performance analysis and recommendations
  List<OptimizationRecommendation> generateImmediateRecommendations() {
    _lastOptimizationRun = DateTime.now();
    return _generateOptimizationRecommendations();
  }

  /// Clear performance history and reset counters
  void clearHistory() {
    _performanceHistory.clear();
    _metricTrends.clear();
    _detectedIssues.clear();
    _issueFrequency.clear();
    _totalSnapshots = 0;
    _performanceWarnings = 0;
    _criticalIssues = 0;

    LoggingUtils.logDebug('Performance history cleared');
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _snapshotController.close();
    _recommendationController.close();
    _alertController.close();
    clearHistory();

    LoggingUtils.logDebug('AdvancedPerformanceMonitor disposed');
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

/// Performance snapshot containing all metrics at a point in time
class PerformanceSnapshot {
  final DateTime timestamp;
  final Map<String, dynamic> memoryMetrics;
  final Map<String, dynamic> networkMetrics;
  final Map<String, dynamic> backgroundServiceMetrics;
  final Map<String, dynamic> platformMetrics;
  final Map<String, dynamic> uiMetrics;

  const PerformanceSnapshot({
    required this.timestamp,
    required this.memoryMetrics,
    required this.networkMetrics,
    required this.backgroundServiceMetrics,
    required this.platformMetrics,
    required this.uiMetrics,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'memory_metrics': memoryMetrics,
      'network_metrics': networkMetrics,
      'background_service_metrics': backgroundServiceMetrics,
      'platform_metrics': platformMetrics,
      'ui_metrics': uiMetrics,
    };
  }
}

/// Performance issue detected during monitoring
class PerformanceIssue {
  final PerformanceIssueType type;
  final IssueSeverity severity;
  final String description;
  final String recommendation;
  final DateTime timestamp;

  const PerformanceIssue({
    required this.type,
    required this.severity,
    required this.description,
    required this.recommendation,
    required this.timestamp,
  });
}

/// Performance alert with issue and frequency information
class PerformanceAlert {
  final PerformanceIssue issue;
  final int frequency;
  final DateTime timestamp;

  const PerformanceAlert({
    required this.issue,
    required this.frequency,
    required this.timestamp,
  });
}

/// Optimization recommendation with actionable items
class OptimizationRecommendation {
  final OptimizationCategory category;
  final RecommendationPriority priority;
  final String title;
  final String description;
  final List<String> actionItems;
  final String estimatedImpact;

  const OptimizationRecommendation({
    required this.category,
    required this.priority,
    required this.title,
    required this.description,
    required this.actionItems,
    required this.estimatedImpact,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category.name,
      'priority': priority.name,
      'title': title,
      'description': description,
      'action_items': actionItems,
      'estimated_impact': estimatedImpact,
    };
  }
}

// =============================================================================
// ENUMS
// =============================================================================

enum PerformanceIssueType {
  memory,
  network,
  ui,
  background,
  platform,
}

enum IssueSeverity {
  info,
  warning,
  critical,
}

enum OptimizationCategory {
  memory,
  network,
  ui,
  background,
  platform,
}

enum RecommendationPriority {
  low,
  medium,
  high,
  critical,
}
