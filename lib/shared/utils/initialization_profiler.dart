import 'dart:async';
import 'logging_utils.dart';

/// Utility class for profiling service initialization times
class InitializationProfiler {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, int> _durations = {};
  static bool _isEnabled = true;

  /// Start timing a service initialization
  static void startTiming(String serviceName) {
    if (!_isEnabled) return;
    _startTimes[serviceName] = DateTime.now();
    LoggingUtils.logDebug('⏱️ Starting initialization: $serviceName');
  }

  /// End timing and log the duration
  static void endTiming(String serviceName) {
    if (!_isEnabled || !_startTimes.containsKey(serviceName)) return;

    final startTime = _startTimes[serviceName]!;
    final duration = DateTime.now().difference(startTime).inMilliseconds;
    _durations[serviceName] = duration;

    LoggingUtils.logDebug(
        '✅ Completed initialization: $serviceName (${duration}ms)');
    _startTimes.remove(serviceName);
  }

  /// Time a future and automatically log the result
  static Future<T> timeAsync<T>(
      String serviceName, Future<T> Function() operation) async {
    startTiming(serviceName);
    try {
      final result = await operation();
      endTiming(serviceName);
      return result;
    } catch (e) {
      LoggingUtils.logError('❌ Failed initialization: $serviceName', e);
      _startTimes.remove(serviceName);
      rethrow;
    }
  }

  /// Get initialization summary
  static Map<String, int> getInitializationSummary() {
    return Map.from(_durations);
  }

  /// Log a summary of all initialization times
  static void logSummary() {
    if (_durations.isEmpty) {
      LoggingUtils.logDebug('📊 No initialization data available');
      return;
    }

    final totalTime =
        _durations.values.fold(0, (sum, duration) => sum + duration);
    final sortedEntries = _durations.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    LoggingUtils.logDebug('📊 Initialization Performance Summary:');
    LoggingUtils.logDebug('   Total time: ${totalTime}ms');
    LoggingUtils.logDebug('   Service breakdown:');

    for (final entry in sortedEntries) {
      final percentage = ((entry.value / totalTime) * 100).toStringAsFixed(1);
      LoggingUtils.logDebug(
          '   • ${entry.key}: ${entry.value}ms ($percentage%)');
    }
  }

  /// Clear all timing data
  static void reset() {
    _startTimes.clear();
    _durations.clear();
  }

  /// Enable or disable profiling
  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Check if profiling is enabled
  static bool get isEnabled => _isEnabled;
}
