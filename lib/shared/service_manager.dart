import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';
import '../services/optimized_weather_service.dart';
import '../services/preferences_service.dart';
import '../services/background_service.dart';
import '../services/scheduled_notification_service.dart';
import 'utils/logging_utils.dart';
import 'utils/memory_utils.dart';
import 'utils/memory_profiler.dart';
import 'utils/initialization_profiler.dart';

/// Centralized service manager for dependency injection and service lifecycle management
class ServiceManager {
  static ServiceManager? _instance;
  static ServiceManager get instance => _instance ??= ServiceManager._();

  ServiceManager._();

  // Initialization status
  static bool _isInitialized = false;
  static bool _isDisposed = false;

  // Service instances
  NotificationService? _notificationService;
  OptimizedWeatherService? _weatherService;
  PreferencesService? _preferencesService;
  WeatherMonitoringManager? _weatherMonitoringManager;
  ScheduledNotificationService? _scheduledNotificationService;

  // Getters for services with lazy initialization
  NotificationService get notificationService {
    return _notificationService ??= NotificationService();
  }

  OptimizedWeatherService get weatherService {
    return _weatherService ??= OptimizedWeatherService();
  }

  PreferencesService get preferencesService {
    return _preferencesService ??= PreferencesService();
  }

  WeatherMonitoringManager get weatherMonitoringManager {
    return _weatherMonitoringManager ??= WeatherMonitoringManager();
  }

  ScheduledNotificationService get scheduledNotificationService {
    return _scheduledNotificationService ??= ScheduledNotificationService();
  }

  // Generic service getter
  T getService<T>() {
    if (T == NotificationService) {
      return notificationService as T;
    } else if (T == OptimizedWeatherService) {
      return weatherService as T;
    } else if (T == PreferencesService) {
      return preferencesService as T;
    } else if (T == WeatherMonitoringManager) {
      return weatherMonitoringManager as T;
    } else if (T == ScheduledNotificationService) {
      return scheduledNotificationService as T;
    } else {
      throw ArgumentError('Service type $T is not registered');
    }
  }

  /// Dispose all services and clean up resources
  static Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    LoggingUtils.logDebug('Disposing ServiceManager and all services...');

    try {
      // Stop background monitoring
      if (_instance?._weatherMonitoringManager != null) {
        await _instance!._weatherMonitoringManager!.stopMonitoring();
      }

      // Cancel any scheduled notifications
      if (_instance?._scheduledNotificationService != null) {
        await _instance!._scheduledNotificationService!.cancelDailyAlarm();
        await _instance!._scheduledNotificationService!.cancelTestAlarm();
      }

      // Clear service instances
      _instance?._notificationService = null;
      _instance?._weatherService = null;
      _instance?._preferencesService = null;
      _instance?._weatherMonitoringManager = null;
      _instance?._scheduledNotificationService = null;

      // Clear singleton instance
      _instance = null;
      _isInitialized = false;

      // Stop memory profiler
      MemoryProfiler.stopMonitoring();

      // Check for memory leaks
      MemoryUtils.checkForLeaks();

      LoggingUtils.logDebug('ServiceManager disposed successfully');
    } catch (e) {
      LoggingUtils.logError('Error disposing ServiceManager', e);
    }
  }

  /// Check if ServiceManager is disposed
  static bool get isDisposed => _isDisposed;

  // Reset all services (useful for testing)
  void reset() {
    _notificationService = null;
    _weatherService = null;
    _preferencesService = null;
    _weatherMonitoringManager = null;
    _scheduledNotificationService = null;
    _isInitialized = false;
  }

  // Initialize only critical services for fast app launch
  Future<void> initializeAll() async {
    if (_isInitialized) {
      LoggingUtils.logDebug('Services already initialized');
      return;
    }

    try {
      InitializationProfiler.startTiming('Total Critical Services');

      // Phase 1: Initialize only critical services for fast startup
      LoggingUtils.logDebug('Initializing critical services...');

      await InitializationProfiler.timeAsync(
          'PreferencesService', () => preferencesService.initialize());

      await InitializationProfiler.timeAsync(
          'NotificationService', () => notificationService.initialize());

      InitializationProfiler.endTiming('Total Critical Services');

      // Phase 2: Schedule non-critical services for background initialization
      _scheduleBackgroundInitialization();

      _isInitialized = true;
      LoggingUtils.logCompletion('Critical services initialized successfully');

      // Log performance summary for critical services
      InitializationProfiler.logSummary();
    } catch (e, stackTrace) {
      LoggingUtils.logCriticalError(
          'CRITICAL SERVICE INITIALIZATION', e, stackTrace);
      rethrow;
    }
  }

  // Schedule non-critical services to initialize in background
  void _scheduleBackgroundInitialization() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        InitializationProfiler.startTiming('Total Background Services');
        LoggingUtils.logDebug(
            'Initializing non-critical services in background...');

        await Future.wait([
          _initializeWeatherMonitoringManager(),
          _initializeScheduledNotificationService(),
          _initializeBackgroundService(),
        ]);

        InitializationProfiler.endTiming('Total Background Services');

        // Start memory profiling in debug mode (non-critical)
        if (kDebugMode) {
          await InitializationProfiler.timeAsync('MemoryProfiler', () async {
            LoggingUtils.logDebug('Starting memory profiler...');
            MemoryProfiler.startMonitoring();
          });
        }

        LoggingUtils.logCompletion(
            'Background services initialized successfully');

        // Log final performance summary
        InitializationProfiler.logSummary();
      } catch (e) {
        LoggingUtils.logError('Background service initialization failed', e);
        // Don't rethrow - app should continue working with critical services
      }
    });
  }

  // Helper methods for parallel initialization
  Future<void> _initializeWeatherMonitoringManager() async {
    await InitializationProfiler.timeAsync('WeatherMonitoringManager',
        () => weatherMonitoringManager.initialize());
  }

  Future<void> _initializeScheduledNotificationService() async {
    await InitializationProfiler.timeAsync('ScheduledNotificationService',
        () => scheduledNotificationService.initialize());
  }

  Future<void> _initializeBackgroundService() async {
    await InitializationProfiler.timeAsync(
        'BackgroundService', () => BackgroundService.initialize());
  }
}
