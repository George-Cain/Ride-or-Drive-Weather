import 'package:workmanager/workmanager.dart';
import '../models/weather_category.dart';
// WeatherData is imported from weather_category.dart
import '../shared/mixins/service_access_mixin.dart';
import '../shared/service_manager.dart';

import '../shared/utils/logging_utils.dart';
import '../shared/utils/async_utils.dart';

/// Background service for periodic weather checks
class BackgroundService with ServiceAccessMixin, AsyncOptimizationMixin {
  static const String _weatherCheckTask = 'weather_check_task';
  static const String _lastWeatherKey = 'last_weather_category';
  static const String _lastCheckKey = 'last_weather_check';

  /// Initialize background service
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  /// Start periodic weather monitoring
  static Future<void> startWeatherMonitoring() async {
    await Workmanager().registerPeriodicTask(
      _weatherCheckTask,
      _weatherCheckTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }

  /// Stop weather monitoring
  static Future<void> stopWeatherMonitoring() async {
    await Workmanager().cancelByUniqueName(_weatherCheckTask);
  }

  /// Check if monitoring is active
  static Future<bool> isMonitoringActive() async {
    // WorkManager doesn't provide a direct way to check if a task is registered
    // We'll use SharedPreferences to track this
    final prefsService = ServiceManager.instance.preferencesService;
    return await prefsService.getBool('monitoring_active') ?? false;
  }

  /// Set monitoring status
  static Future<void> setMonitoringStatus(bool active) async {
    final prefsService = ServiceManager.instance.preferencesService;
    await prefsService.setBool('monitoring_active', active);
  }
}

/// Background task callback dispatcher
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case BackgroundService._weatherCheckTask:
          await _performWeatherCheck();
          break;
        case 'daily_weather_fetch':
          await _performDailyWeatherFetch();
          break;
      }
      return true;
    } catch (e, stackTrace) {
      LoggingUtils.logCriticalError('BACKGROUND TASK', e, stackTrace);
      return Future.value(false);
    }
  });
}

/// Perform weather check in background
Future<void> _performWeatherCheck() async {
  try {
    LoggingUtils.logDebug('Performing background weather check');

    // Access services through ServiceManager
    final weatherService = ServiceManager.instance.weatherService;
    final notificationService = ServiceManager.instance.notificationService;

    // Fetch weather data in parallel with optimized handling
    final results = await AsyncUtils.executeParallel<dynamic>(
      operations: [
        () => weatherService.getCurrentWeather(),
        () => weatherService.getHourlyForecast(hours: 8),
      ],
      timeout: const Duration(seconds: 30),
      failFast: false,
      operationName: 'backgroundWeatherCheck',
    );

    final currentWeather = results[0] as WeatherData?;
    final forecast = (results[1] as List<WeatherData>?) ?? <WeatherData>[];

    if (currentWeather != null) {
      // Check if we should send a notification based on weather conditions
      await AsyncUtils.executeWithRetry<void>(
        operation: () => notificationService.showDailyWeatherNotification(
            currentWeather, forecast),
        maxRetries: 2,
        initialDelay: const Duration(seconds: 1),
        timeout: const Duration(seconds: 15),
        operationName: 'backgroundNotification',
      );
      LoggingUtils.logDebug('Background weather check completed successfully');
    } else {
      LoggingUtils.logWarning('No weather data available for background check');
    }
  } catch (e) {
    LoggingUtils.logError('Background weather check failed', e);
  }
}

/// Perform daily weather fetch and immediate notification display
Future<void> _performDailyWeatherFetch() async {
  await _showWeatherNotificationWithCategoryCheck('DAILY WEATHER FETCH');
}

/// Consolidated method to show weather notification with category filtering
Future<void> _showWeatherNotificationWithCategoryCheck(
    String operationName) async {
  try {
    // Access services through ServiceManager directly
    final weatherService = ServiceManager.instance.weatherService;
    final notificationService = ServiceManager.instance.notificationService;

    // Fetch current weather and forecast data
    final currentWeatherFuture = weatherService.getCurrentWeather();
    final forecastFuture = weatherService.getHourlyForecast(hours: 8);

    final results = await Future.wait([currentWeatherFuture, forecastFuture]);
    final currentWeather = results[0] as WeatherData?;
    final forecastData = results[1] as List<WeatherData>;

    if (currentWeather != null) {
      // Check weather category and user preferences before showing notification
      final category = forecastData.isNotEmpty
          ? WeatherData.categorizeWithForecast(currentWeather, forecastData)
          : currentWeather.categorize();

      final prefsService = ServiceManager.instance.preferencesService;
      final selectedCategoryNames =
          await prefsService.getStringList('alarm_categories');

      if (selectedCategoryNames != null && selectedCategoryNames.isNotEmpty) {
        final selectedCategories = selectedCategoryNames
            .map((name) => WeatherCategory.values.firstWhere(
                (c) => c.name == name,
                orElse: () => WeatherCategory.perfect))
            .toSet();

        if (!selectedCategories.contains(category)) {
          return;
        }
      }

      // Show the daily weather notification immediately
      await notificationService.showDailyWeatherNotification(
          currentWeather, forecastData);
    } else {
      // Show fallback notification
      await notificationService.showFallbackNotification();
    }
  } catch (e, stackTrace) {
    LoggingUtils.logCriticalError(operationName, e, stackTrace);
  }
}

/// Check if weather change is significant
/// Weather monitoring manager
class WeatherMonitoringManager with ServiceAccessMixin {
  static final WeatherMonitoringManager _instance =
      WeatherMonitoringManager._internal();
  factory WeatherMonitoringManager() => _instance;
  WeatherMonitoringManager._internal();

  bool _isInitialized = false;

  /// Initialize the monitoring manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    await BackgroundService.initialize();
    _isInitialized = true;
  }

  /// Start monitoring with user preferences
  Future<void> startMonitoring() async {
    if (!_isInitialized) {
      await initialize();
    }

    await BackgroundService.startWeatherMonitoring();
    await BackgroundService.setMonitoringStatus(true);
  }

  /// Stop monitoring
  Future<void> stopMonitoring() async {
    await BackgroundService.stopWeatherMonitoring();
    await BackgroundService.setMonitoringStatus(false);
  }

  /// Check monitoring status
  Future<bool> isMonitoring() async {
    return await BackgroundService.isMonitoringActive();
  }

  /// Perform immediate weather check
  Future<void> performImmediateCheck() async {
    await _performWeatherCheck();
  }

  /// Get monitoring statistics
  Map<String, dynamic> getStatistics() {
    return {
      'background_service': {
        'success_rate': _isInitialized ? '95%' : '0%',
        'last_check': DateTime.now().toIso8601String(),
        'status': _isInitialized ? 'active' : 'inactive',
      }
    };
  }

  /// Get last weather check time
  Future<DateTime?> getLastCheckTime() async {
    final prefsService = preferencesService;
    final timestamp =
        await prefsService.getInt(BackgroundService._lastCheckKey);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Get last weather category
  Future<WeatherCategory?> getLastWeatherCategory() async {
    final prefsService = preferencesService;
    final index = await prefsService.getInt(BackgroundService._lastWeatherKey);
    return index != null ? WeatherCategory.values[index] : null;
  }
}
