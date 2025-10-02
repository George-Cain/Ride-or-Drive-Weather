/// Service access mixin to eliminate duplicate ServiceManager access patterns
/// Provides consistent service access across all components
library;

import '../service_manager.dart';
import '../../services/notification_service.dart';
import '../../services/optimized_weather_service.dart';
import '../../services/preferences_service.dart';
import '../../services/background_service.dart';
import '../../services/scheduled_notification_service.dart';

/// Mixin that provides centralized service access to eliminate duplicate patterns
mixin ServiceAccessMixin {
  /// Get the ServiceManager instance
  ServiceManager get serviceManager => ServiceManager.instance;

  /// Quick access to NotificationService
  NotificationService get notificationService => serviceManager.notificationService;

  /// Quick access to OptimizedWeatherService
  OptimizedWeatherService get weatherService => serviceManager.weatherService;

  /// Quick access to PreferencesService
  PreferencesService get preferencesService => serviceManager.preferencesService;

  /// Quick access to WeatherMonitoringManager
  WeatherMonitoringManager get weatherMonitoringManager => serviceManager.weatherMonitoringManager;

  /// Quick access to ScheduledNotificationService
  ScheduledNotificationService get scheduledNotificationService => serviceManager.scheduledNotificationService;

  /// Generic service access with type safety
  T getService<T>() => serviceManager.getService<T>();
}