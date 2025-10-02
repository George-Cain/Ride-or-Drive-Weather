import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';
import '../services/preferences_service.dart';
import '../services/notification_service.dart';

import '../shared/utils/logging_utils.dart';

/// Service for scheduling weather notifications using flutter_local_notifications
/// This replaces the alarm package to avoid volume meter display issues
class ScheduledNotificationService {
  static final ScheduledNotificationService _instance =
      ScheduledNotificationService._internal();
  factory ScheduledNotificationService() => _instance;
  ScheduledNotificationService._internal();

  static const int _dailyNotificationId = 100;
  static const int _testNotificationId = 101;

  final PreferencesService _preferencesService = PreferencesService();
  final NotificationService _notificationService = NotificationService();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the scheduled notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      LoggingUtils.logInitialization('Scheduled Notification Service');

      // Log timezone information

      // Ensure notification service is initialized
      await _notificationService.initialize();

      // Check notification permissions
      final plugin = FlutterLocalNotificationsPlugin();
      final androidImplementation =
          plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.areNotificationsEnabled();
        await androidImplementation.canScheduleExactNotifications();
      }

      _isInitialized = true;
      LoggingUtils.logCompletion(
          'Scheduled notification service initialization');
    } catch (e) {
      LoggingUtils.logError(
          'Error initializing scheduled notification service', e);
    }
  }

  /// Schedule daily weather notification
  Future<void> scheduleDailyAlarm() async {
    try {
      LoggingUtils.logDebug('Scheduling daily weather notification...');

      final isEnabled =
          await _preferencesService.getBool('alarm_enabled') ?? false;

      if (!isEnabled) {
        LoggingUtils.logDebug(
            'Daily notifications are disabled, not scheduling');
        return;
      }

      await _scheduleDailyNotification();
    } catch (e) {
      LoggingUtils.logError('Error scheduling daily notification', e);
    }
  }

  /// Internal method to schedule daily notification with immediate weather fetch
  Future<void> _scheduleDailyNotification() async {
    try {
      // Cancel existing daily notification
      await _notifications.cancel(_dailyNotificationId);

      // Schedule background task to fetch and display weather immediately
      await _scheduleBackgroundWeatherFetch();

      final alarmHour = await _preferencesService.getInt('alarm_hour') ?? 9;
      final alarmMinute = await _preferencesService.getInt('alarm_minute') ?? 0;

      LoggingUtils.logDebug('Notification time: $alarmHour:$alarmMinute');
      // Get the local timezone
      final location = tz.local;
      final now = tz.TZDateTime.now(location);

      // Calculate next notification date
      var notificationDateTime = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day,
        alarmHour,
        alarmMinute,
      );

      // If the time has already passed today, schedule for tomorrow
      if (notificationDateTime.isBefore(now)) {
        notificationDateTime =
            notificationDateTime.add(const Duration(days: 1));
      }

      LoggingUtils.logDebug(
          'Scheduling daily notification for: $notificationDateTime');

      // Schedule background task to fetch and display weather at notification time

      // Verify the notification was actually scheduled
      await _verifyNotificationScheduled();

      // Save notification state to preferences
      await _preferencesService.setBool('daily_alarm_scheduled', true);
      await _preferencesService.setString(
          'daily_alarm_time', notificationDateTime.toIso8601String());
    } catch (e) {
      LoggingUtils.logError('Error in _scheduleImmediateWeatherFetch', e);
      rethrow;
    }
  }

  /// Schedule background task to fetch and display weather immediately
  Future<void> _scheduleBackgroundWeatherFetch() async {
    try {
      final alarmHour = await _preferencesService.getInt('alarm_hour') ?? 9;
      final alarmMinute = await _preferencesService.getInt('alarm_minute') ?? 0;

      // Get the local timezone
      final location = tz.local;
      final now = tz.TZDateTime.now(location);

      // Calculate next notification date
      var notificationDateTime = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day,
        alarmHour,
        alarmMinute,
      );

      // If the time has already passed today, schedule for tomorrow
      if (notificationDateTime.isBefore(now)) {
        notificationDateTime =
            notificationDateTime.add(const Duration(days: 1));
      }

      // Calculate delay until notification time
      final delay = notificationDateTime.difference(now);

      // Import Workmanager for background task scheduling
      final Workmanager workmanager = Workmanager();

      // Cancel any existing daily weather task
      await workmanager.cancelByUniqueName('daily_weather_fetch');

      // Schedule one-time background task to fetch and show weather
      await workmanager.registerOneOffTask(
        'daily_weather_fetch',
        'daily_weather_fetch',
        initialDelay: delay,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );

      // Save notification state to preferences
      await _preferencesService.setBool('daily_alarm_scheduled', true);
      await _preferencesService.setString(
          'daily_alarm_time', notificationDateTime.toIso8601String());

      LoggingUtils.logDebug(
          'Background weather fetch scheduled successfully for $notificationDateTime');
    } catch (e) {
      LoggingUtils.logError('Error scheduling background weather fetch', e);
      rethrow;
    }
  }

  /// Schedule immediate weather fetch and notification display (legacy method)
  /// Schedule test notification (for immediate testing)
  Future<void> scheduleTestAlarm({int minutes = 2}) async {
    try {
      LoggingUtils.logDebug(
          'Scheduling test notification for $minutes minutes from now...');

      // Cancel existing test notification
      await _notifications.cancel(_testNotificationId);

      final location = tz.local;
      final now = tz.TZDateTime.now(location);
      final testNotificationTime = now.add(Duration(minutes: minutes));

      LoggingUtils.logDebug(
          'Test notification scheduled for: $testNotificationTime');

      // Create notification details
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'test_weather_scheduled',
        'Test Weather Notifications',
        channelDescription: 'Test weather notifications for debugging',
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

      // Schedule the test notification
      await _notifications.zonedSchedule(
        _testNotificationId,
        'Weather Test',
        'Testing weather notification system',
        testNotificationTime,
        notificationDetails,
        payload: 'fetch_and_show_weather',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      // Save test notification state to preferences
      await _preferencesService.setBool('test_alarm_scheduled', true);
      await _preferencesService.setString(
          'test_alarm_time', testNotificationTime.toIso8601String());

      LoggingUtils.logDebug(
          'Test notification scheduled successfully for $testNotificationTime');
    } catch (e) {
      LoggingUtils.logError('Error scheduling test notification', e);
    }
  }

  /// Cancel daily notification
  Future<void> cancelDailyAlarm() async {
    try {
      LoggingUtils.logDebug('Canceling daily notification...');
      await _notifications.cancel(_dailyNotificationId);

      // Cancel Workmanager background task
      final Workmanager workmanager = Workmanager();
      await workmanager.cancelByUniqueName('daily_weather_fetch');

      // Clear notification state from preferences
      await _preferencesService.setBool('daily_alarm_scheduled', false);
      await _preferencesService.remove('daily_alarm_time');

      LoggingUtils.logDebug(
          'Daily notification and background task canceled successfully');
    } catch (e) {
      LoggingUtils.logError('Error canceling daily notification', e);
    }
  }

  /// Cancel test notification
  Future<void> cancelTestAlarm() async {
    try {
      LoggingUtils.logDebug('Canceling test notification...');
      await _notifications.cancel(_testNotificationId);

      // Clear test notification state from preferences
      await _preferencesService.setBool('test_alarm_scheduled', false);
      await _preferencesService.remove('test_alarm_time');

      LoggingUtils.logDebug('Test notification canceled successfully');
    } catch (e) {
      LoggingUtils.logError('Error canceling test notification', e);
    }
  }

  /// Check if daily notification is scheduled
  Future<bool> isDailyAlarmScheduled() async {
    try {
      return await _preferencesService.getBool('daily_alarm_scheduled') ??
          false;
    } catch (e) {
      LoggingUtils.logError('Error checking daily notification status', e);
      return false;
    }
  }

  /// Check if test notification is scheduled
  Future<bool> isTestAlarmScheduled() async {
    try {
      return await _preferencesService.getBool('test_alarm_scheduled') ?? false;
    } catch (e) {
      LoggingUtils.logError('Error checking test notification status', e);
      return false;
    }
  }

  /// Check if any notification is currently scheduled (for compatibility with debug screen)
  Future<bool> isAlarmScheduled() async {
    final daily = await isDailyAlarmScheduled();
    final test = await isTestAlarmScheduled();
    return daily || test;
  }

  /// Get the next scheduled notification time (for compatibility with debug screen)
  Future<DateTime?> getNextAlarmTime() async {
    try {
      // Check daily notification first
      final dailyScheduled = await isDailyAlarmScheduled();
      if (dailyScheduled) {
        final dailyTimeStr =
            await _preferencesService.getString('daily_alarm_time');
        if (dailyTimeStr != null) {
          return DateTime.parse(dailyTimeStr);
        }
      }

      // Check test notification
      final testScheduled = await isTestAlarmScheduled();
      if (testScheduled) {
        final testTimeStr =
            await _preferencesService.getString('test_alarm_time');
        if (testTimeStr != null) {
          return DateTime.parse(testTimeStr);
        }
      }

      return null;
    } catch (e) {
      LoggingUtils.logError('Error getting next notification time', e);
      return null;
    }
  }

  /// Verify that the notification was actually scheduled by checking pending notifications
  Future<void> _verifyNotificationScheduled() async {
    try {
      final pendingNotifications =
          await _notifications.pendingNotificationRequests();

      final dailyNotification = pendingNotifications
          .where((n) => n.id == _dailyNotificationId)
          .toList();

      if (dailyNotification.isEmpty) {
        LoggingUtils.logWarning('Daily notification not found in pending list');
      }
    } catch (e) {
      LoggingUtils.logError('Error verifying notification scheduling', e);
    }
  }

  /// Test immediate notification to verify the notification system works
  Future<void> testImmediateNotification() async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'test_immediate',
        'Immediate Test Notifications',
        channelDescription:
            'Immediate test notifications for system verification',
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

      await _notifications.show(
        8888, // Unique ID for immediate test
        'Immediate Test Notification',
        'If you see this, the notification system is working! Time: ${DateTime.now().toIso8601String()}',
        notificationDetails,
        payload: 'immediate_test',
      );

      LoggingUtils.logDebug('Immediate test notification sent successfully');
    } catch (e) {
      LoggingUtils.logError('Error sending immediate test notification', e);
    }
  }

  /// Check Android battery optimization and notification settings
  Future<void> checkAndroidNotificationSettings() async {
    try {
      final androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        // Check basic notification permission
        final notificationsEnabled =
            await androidImplementation.areNotificationsEnabled();
        LoggingUtils.logDebug('Notifications enabled: $notificationsEnabled');

        // Check exact alarm permission (critical for scheduled notifications)
        final exactAlarmPermission =
            await androidImplementation.canScheduleExactNotifications();
        LoggingUtils.logDebug('Exact alarm permission: $exactAlarmPermission');

        if (exactAlarmPermission == false) {
          LoggingUtils.logWarning(
              'Exact alarm permission is DENIED - scheduled notifications may not work');
        }

        if (notificationsEnabled == false) {
          LoggingUtils.logWarning(
              'Notifications are DISABLED - user needs to enable notifications');
        }

        // Get pending and active notifications
        final pendingNotifications =
            await _notifications.pendingNotificationRequests();
        final activeNotifications =
            await _notifications.getActiveNotifications();

        LoggingUtils.logDebug(
            'Pending notifications: ${pendingNotifications.length}');
        LoggingUtils.logDebug(
            'Active notifications: ${activeNotifications.length}');
      } else {
        LoggingUtils.logDebug(
            'Android implementation not available (likely running on iOS)');
      }
    } catch (e) {
      LoggingUtils.logError('Error checking Android notification settings', e);
    }
  }

  /// Request battery optimization exemption (critical for scheduled notifications)
  Future<void> requestBatteryOptimizationExemption() async {
    LoggingUtils.logWarning(
        'Battery optimization may prevent scheduled notifications');
  }

  /// Get next daily notification time
  Future<DateTime?> getNextDailyAlarmTime() async {
    try {
      if (!await isDailyAlarmScheduled()) return null;

      final timeStr = await _preferencesService.getString('daily_alarm_time');
      if (timeStr != null) {
        return DateTime.parse(timeStr);
      }
      return null;
    } catch (e) {
      LoggingUtils.logError('Error getting next daily notification time', e);
      return null;
    }
  }

  /// Get next test notification time
  Future<DateTime?> getNextTestAlarmTime() async {
    try {
      if (!await isTestAlarmScheduled()) return null;

      final timeStr = await _preferencesService.getString('test_alarm_time');
      if (timeStr != null) {
        return DateTime.parse(timeStr);
      }
      return null;
    } catch (e) {
      LoggingUtils.logError('Error getting next test notification time', e);
      return null;
    }
  }

  /// Check if battery optimization is disabled for this app
  Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        // Note: There's no direct way to check battery optimization status
        // This is a placeholder that always returns false to encourage checking
        return false;
      }
      return true; // iOS doesn't have battery optimization issues
    } catch (e) {
      LoggingUtils.logError('Error checking battery optimization status', e);
      return false;
    }
  }
}
