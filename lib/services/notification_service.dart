import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/weather_category.dart';
import '../shared/mixins/service_access_mixin.dart';
import '../shared/utils/logging_utils.dart';
import '../shared/utils/async_utils.dart';
import '../shared/permission_coordinator.dart';

/// Service for handling local notifications
class NotificationService with ServiceAccessMixin, AsyncOptimizationMixin {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    LoggingUtils.logInitialization('Notification Service');

    // Request notification permissions
    await _requestPermissions();

    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    _isInitialized = true;
    LoggingUtils.logCompletion('Notification service initialization');
  }

  /// Request notification permissions using the permission coordinator
  Future<void> _requestPermissions() async {
    try {
      final coordinator = PermissionCoordinator();
      final result = await coordinator.requestNotificationPermissions();

      if (result != PermissionStatus.granted) {
        LoggingUtils.logWarning(
            'Notification permission not granted - notifications may not work');
      }

      // Additional permission checks
      final androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.areNotificationsEnabled();
        await androidImplementation.canScheduleExactNotifications();
      }
    } catch (e) {
      LoggingUtils.logError('Error requesting notification permissions: $e');
    }
  }

  /// Handle notification response events
  Future<void> _onNotificationResponse(NotificationResponse response) async {
    LoggingUtils.logDebug('Notification tapped: ${response.payload}');

    // Handle different notification types
    switch (response.payload) {
      case 'scheduled_weather':
      case 'fetch_and_show_weather':
      case 'immediate_weather_display':
        await _fetchAndShowWeatherNotification();
        break;
      default:
        // Handle other notification types or navigation
        break;
    }
  }

  /// Fetch current weather and forecast data, then show notification
  Future<void> _fetchAndShowWeatherNotification() async {
    try {
      final weatherService = this.weatherService;

      // Fetch both current weather and forecast in parallel with optimized handling
      final results = await executeParallel<dynamic>(
        operations: [
          () => weatherService.getCurrentWeather(),
          () => weatherService.getHourlyForecast(hours: 8),
        ],
        timeout: const Duration(seconds: 30),
        failFast: false,
        operationName: 'fetchWeatherForNotification',
      );

      final currentWeather = results[0] as WeatherData?;
      final forecastData =
          (results[1] as List<WeatherData>?) ?? <WeatherData>[];

      if (currentWeather != null) {
        await showDailyWeatherNotification(currentWeather, forecastData);
      } else {
        // Show fallback notification if weather fetch fails
        await showFallbackNotification();
      }
    } catch (e) {
      LoggingUtils.logError('Error fetching weather for notification', e);
      await showFallbackNotification();
    }
  }

  /// Show fallback notification when weather fetch fails
  Future<void> showFallbackNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'weather_error',
      'Weather Error',
      channelDescription: 'Weather fetch error notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      5, // Fallback notification ID
      'Weather Update',
      'Unable to fetch current weather. Please check your internet connection and try again.',
      notificationDetails,
      payload: 'weather_error',
    );
  }

  /// Show daily weather recommendation notification with forecast data
  Future<void> showDailyWeatherNotification(WeatherData weatherData,
      [List<WeatherData>? forecastData]) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Use forecast-based categorization if forecast data is available
    final category = (forecastData?.isNotEmpty ?? false)
        ? WeatherData.categorizeWithForecast(weatherData, forecastData!)
        : weatherData.categorize();

    // Check if user wants notifications for this weather category
    final prefsService = preferencesService;
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

    final recommendation = _getRecommendationForCategory(category);

    // Add forecast information to the notification body
    final forecastInfo = (forecastData?.isNotEmpty ?? false)
        ? '\n\nRecommendation based on current + next ${forecastData!.length > 8 ? 8 : forecastData.length} hours forecast'
        : '';
    final notificationBody = '$recommendation$forecastInfo';

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'daily_weather',
      'Daily Weather Notifications',
      channelDescription: 'Daily weather recommendations for motorcycle riding',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      autoCancel: false,
      ongoing: false,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        1, // Notification ID
        'Weather Update - ${category.title}',
        notificationBody,
        notificationDetails,
        payload: 'daily_weather',
      );
    } catch (e) {
      LoggingUtils.logError('Error showing daily weather notification', e);
      rethrow;
    }
  }

  /// Schedule daily weather notification with actual weather data
  Future<void> scheduleActualWeatherNotification(int hour, int minute) async {
    if (!_isInitialized) await initialize();

    // Store the notification time in SharedPreferences
    final prefsService = preferencesService;
    await prefsService.setInt('daily_notification_hour', hour);
    await prefsService.setInt('daily_notification_minute', minute);
    await prefsService.setBool('daily_notifications_enabled', true);

    // Cancel any existing scheduled notifications
    await _notifications.cancel(3); // Daily notification ID

    // Schedule the notification using zonedSchedule for exact timing
    await _scheduleExactDailyNotification(hour, minute);

    LoggingUtils.logDebug(
        'Daily notification scheduled for ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
  }

  /// Schedule exact daily notification using zonedSchedule
  Future<void> _scheduleExactDailyNotification(int hour, int minute) async {
    try {
      // Get the local timezone
      final location = tz.local;
      final now = tz.TZDateTime.now(location);

      // Calculate the next occurrence of the scheduled time
      var scheduledDate =
          tz.TZDateTime(location, now.year, now.month, now.day, hour, minute);

      // If the scheduled time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'daily_weather',
        'Daily Weather Notifications',
        channelDescription: 'Daily weather updates for motorcycle safety',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        3, // Daily notification ID
        'Daily Weather Update',
        'Tap to see today\'s riding conditions',
        scheduledDate,
        notificationDetails,
        payload: 'fetch_and_show_weather',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents:
            DateTimeComponents.time, // Repeat daily at the same time
      );

      LoggingUtils.logDebug('Daily notification scheduled successfully');
    } catch (e) {
      LoggingUtils.logError('Error scheduling exact daily notification', e);

      rethrow;
    }
  }

  /// Cancel daily scheduled notification
  Future<void> cancelDailyNotification() async {
    await _notifications.cancel(3); // Daily notification ID
    LoggingUtils.logDebug('Daily notification cancelled');
  }

  /// Show immediate weather notification (for background service)
  Future<void> showScheduledWeatherNotification() async {
    LoggingUtils.logDebug('Showing scheduled weather notification');

    try {
      if (!_isInitialized) {
        await initialize();
      }
      final weatherService = this.weatherService;

      // Fetch both current weather and 8-hour forecast
      final currentWeatherFuture = weatherService.getCurrentWeather();
      final forecastFuture = weatherService.getHourlyForecast(hours: 8);

      final results = await Future.wait([currentWeatherFuture, forecastFuture]);
      final currentWeather = results[0] as WeatherData?;
      final forecastData = results[1] as List<WeatherData>;

      if (currentWeather != null) {
        // Cancel the placeholder notification
        await cancelNotification(4);

        // Show the actual weather notification with forecast data
        await showDailyWeatherNotification(currentWeather, forecastData);
        LoggingUtils.logDebug(
            'Daily weather notification displayed successfully');
      } else {
        LoggingUtils.logError(
            'Failed to fetch weather for scheduled notification', null);
      }
    } catch (e, stackTrace) {
      LoggingUtils.logCriticalError(
          'SCHEDULED WEATHER NOTIFICATION', e, stackTrace);
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Weather change alert helper methods removed

  /// Show test notification with random weather message
  Future<void> showTestNotification() async {
    if (!_isInitialized) {
      await initialize();
    }

    // Get all weather messages from all categories
    final allMessages = [
      ...WeatherData.perfectMessages,
      ...WeatherData.goodMessages,
      ...WeatherData.okMessages,
      ...WeatherData.badMessages,
      ...WeatherData.dangerousMessages,
    ];

    // Randomly select a message
    final random = DateTime.now().millisecondsSinceEpoch % allMessages.length;
    final selectedMessage = allMessages[random];

    // Determine category based on message content for title
    String categoryTitle;
    if (WeatherData.perfectMessages.contains(selectedMessage)) {
      categoryTitle = 'Perfect';
    } else if (WeatherData.goodMessages.contains(selectedMessage)) {
      categoryTitle = 'Good';
    } else if (WeatherData.okMessages.contains(selectedMessage)) {
      categoryTitle = 'Okay';
    } else if (WeatherData.badMessages.contains(selectedMessage)) {
      categoryTitle = 'Bad';
    } else {
      categoryTitle = 'Dangerous';
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'test',
      'Test Notifications',
      channelDescription: 'Test notifications with random weather messages',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        999,
        'Test Weather Update - $categoryTitle',
        selectedMessage,
        notificationDetails,
        payload: 'test',
      );
      LoggingUtils.logDebug('Test notification displayed successfully');
    } catch (e) {
      LoggingUtils.logError('Error showing test notification', e);
      rethrow;
    }
  }

  /// Show immediate test notification (for debugging)
  Future<void> showImmediateTestNotification() async {
    try {
      await showTestNotification();
      LoggingUtils.logDebug('Immediate test notification completed');
    } catch (e) {
      LoggingUtils.logError('Immediate test notification failed', e);
    }
  }

  /// Show alarm notification when weather matches target category
  Future<void> showAlarmNotification(
    WeatherCategory targetCategory,
    WeatherData weatherData,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Get a random message from the target category
    final selectedMessage = weatherData.getRecommendation();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'weather_alarm',
      'Weather Alarms',
      channelDescription: 'Alarms for weather-based notifications',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      ongoing: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        1000, // Unique ID for alarm notifications
        '🚨 Weather Alarm - ${targetCategory.title}!',
        selectedMessage,
        notificationDetails,
        payload: 'weather_alarm_${targetCategory.name}',
      );
      LoggingUtils.logDebug('Alarm notification displayed successfully');
    } catch (e) {
      LoggingUtils.logError('Error showing alarm notification', e);
      rethrow;
    }
  }

  /// Get recommendation message for a specific weather category
  String _getRecommendationForCategory(WeatherCategory category) {
    switch (category) {
      case WeatherCategory.perfect:
        final random = DateTime.now().millisecondsSinceEpoch %
            WeatherData.perfectMessages.length;
        return WeatherData.perfectMessages[random];
      case WeatherCategory.good:
        final random = DateTime.now().millisecondsSinceEpoch %
            WeatherData.goodMessages.length;
        return WeatherData.goodMessages[random];
      case WeatherCategory.ok:
        final random = DateTime.now().millisecondsSinceEpoch %
            WeatherData.okMessages.length;
        return WeatherData.okMessages[random];
      case WeatherCategory.bad:
        final random = DateTime.now().millisecondsSinceEpoch %
            WeatherData.badMessages.length;
        return WeatherData.badMessages[random];
      case WeatherCategory.dangerous:
        final random = DateTime.now().millisecondsSinceEpoch %
            WeatherData.dangerousMessages.length;
        return WeatherData.dangerousMessages[random];
    }
  }
}
