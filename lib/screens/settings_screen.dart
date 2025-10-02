import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';
import '../services/background_service.dart';
import '../services/scheduled_notification_service.dart';
import '../models/weather_category.dart';
import '../shared/widgets/common_widgets.dart';
import '../shared/widgets/optimized_widgets.dart';
import '../shared/utils/error_handler.dart';
import '../shared/utils/memory_utils.dart';
import '../shared/utils/async_utils.dart';
import '../shared/utils/image_optimization.dart';
import '../shared/utils/performance_utils.dart';
import '../shared/mixins/service_access_mixin.dart';
import '../shared/service_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with
        ErrorHandlingMixin,
        ServiceAccessMixin,
        ResourceCleanupMixin,
        AsyncOptimizationMixin,
        PerformanceOptimizedMixin {
  late final NotificationService _notificationService;
  late final WeatherMonitoringManager _monitoringManager;
  late final PreferencesService _preferencesService;
  late final ScheduledNotificationService _scheduledNotificationService;

  bool _isLoading = true;

  // Weather alarm settings (merged from daily notifications)
  bool _alarmEnabled = true; // Default enabled
  TimeOfDay _alarmTime = const TimeOfDay(hour: 9, minute: 0); // Default 9:00 AM
  Set<WeatherCategory> _selectedCategories =
      WeatherCategory.values.toSet(); // All categories enabled by default

  @override
  void initState() {
    super.initState();
    // ServiceManager access now provided by ServiceAccessMixin
    _notificationService = serviceManager.getService<NotificationService>();
    _monitoringManager = serviceManager.getService<WeatherMonitoringManager>();
    _preferencesService = serviceManager.getService<PreferencesService>();
    _scheduledNotificationService =
        serviceManager.getService<ScheduledNotificationService>();

    // Register resources for memory tracking
    registerResource('NotificationService', 'settings_screen');
    registerResource('WeatherMonitoringManager', 'settings_screen');
    registerResource('PreferencesService', 'settings_screen');
    registerResource('ScheduledNotificationService', 'settings_screen');

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await handleAsync(
      operation: () async {
        // Parallelize basic preference reads with optimized handling
        final basicPrefs = await executeParallel<dynamic>(
          operations: [
            () => _preferencesService.getBool('alarm_enabled'),
            () => _preferencesService.getInt('alarm_hour'),
            () => _preferencesService.getInt('alarm_minute'),
          ],
          timeout: const Duration(seconds: 10),
          failFast: false,
          operationName: 'loadBasicPrefs',
        );

        final alarmEnabled = basicPrefs[0] as bool? ?? true;

        // Safe integer loading with fallback for potential string values
        int alarmHour = 9;
        int alarmMinute = 0;

        try {
          alarmHour = basicPrefs[1] as int? ?? 8;
        } catch (e) {
          // Handle case where value might be stored as string
          final hourStr = await _preferencesService.getString('alarm_hour');
          if (hourStr != null) {
            alarmHour = int.tryParse(hourStr) ?? 8;
          }
        }

        try {
          alarmMinute = basicPrefs[2] as int? ?? 0;
        } catch (e) {
          final minuteStr = await _preferencesService.getString('alarm_minute');
          if (minuteStr != null) {
            alarmMinute = int.tryParse(minuteStr) ?? 0;
          }
        }

        // Load selected categories - default to ALL categories enabled
        Set<WeatherCategory> selectedCategories =
            WeatherCategory.values.toSet();
        try {
          final categoryNames =
              await _preferencesService.getStringList('alarm_categories');
          if (categoryNames != null && categoryNames.isNotEmpty) {
            selectedCategories = {};
            for (final categoryName in categoryNames) {
              try {
                final category = WeatherCategory.values
                    .firstWhere((c) => c.name == categoryName);
                selectedCategories.add(category);
              } catch (e) {
                // Skip invalid category names
              }
            }
            // Ensure we have at least one category - default to all if empty
            if (selectedCategories.isEmpty) {
              selectedCategories = WeatherCategory.values.toSet();
            }
          }
        } catch (e) {
          // Fallback to old single category format for backward compatibility
          try {
            final categoryIndex =
                await _preferencesService.getInt('alarm_category') ?? 0;
            selectedCategories = {
              WeatherCategory.values[
                  categoryIndex.clamp(0, WeatherCategory.values.length - 1)]
            };
          } catch (e2) {
            final categoryStr =
                await _preferencesService.getString('alarm_category');
            if (categoryStr != null) {
              final categoryIndex = int.tryParse(categoryStr) ?? 0;
              selectedCategories = {
                WeatherCategory.values[
                    categoryIndex.clamp(0, WeatherCategory.values.length - 1)]
              };
            }
          }
        }

        if (mounted) {
          setState(() {
            _alarmEnabled = alarmEnabled;
            _alarmTime = TimeOfDay(hour: alarmHour, minute: alarmMinute);
            _selectedCategories = selectedCategories;
            _isLoading = false;
          });
        }
        return 'Settings loaded successfully';
      },
      operationName: 'Load settings',
      onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          SnackBarUtils.showError(context, error);
        }
      },
    );
  }

  Future<void> _saveSettings() async {
    await handleAsync(
      operation: () async {
        // Prepare category names
        final categoryNames = _selectedCategories.isNotEmpty
            ? _selectedCategories.map((c) => c.name).toList()
            : [WeatherCategory.perfect.name];

        // Parallelize preference writes with optimized handling
        await executeParallel<void>(
          operations: [
            () => _preferencesService.setBool('alarm_enabled', _alarmEnabled),
            () => _preferencesService.setInt('alarm_hour', _alarmTime.hour),
            () => _preferencesService.setInt('alarm_minute', _alarmTime.minute),
            () => _preferencesService.setStringList(
                'alarm_categories', categoryNames),
          ],
          timeout: const Duration(seconds: 10),
          failFast: true,
          operationName: 'saveSettings',
        );

        // Update scheduled notifications only (no background monitoring)
        if (_alarmEnabled) {
          // Preferences already saved above, now schedule notifications
          await _scheduledNotificationService.scheduleDailyAlarm();
        } else {
          // Cancel the alarm when disabled
          await _scheduledNotificationService.cancelDailyAlarm();
        }

        return 'Settings saved successfully';
      },
      operationName: 'Save settings',
      onSuccess: (message) {
        if (mounted) {
          SnackBarUtils.showSuccess(context, message);
        }
      },
      onError: (error) {
        if (mounted) {
          SnackBarUtils.showError(context, error);
        }
      },
    );
  }

  Future<void> _updateAlarmEnabled(bool enabled) async {
    await handleAsync(
      operation: () async {
        await _preferencesService.setBool('alarm_enabled', enabled);

        debouncedSetState(() {
          _alarmEnabled = enabled;
        });

        if (enabled) {
          // Prepare category names
          final categoryNames = _selectedCategories.isNotEmpty
              ? _selectedCategories.map((c) => c.name).toList()
              : [WeatherCategory.perfect.name];

          // Parallelize preference writes with optimized handling
          await executeParallel<void>(
            operations: [
              () => _preferencesService.setInt('alarm_hour', _alarmTime.hour),
              () =>
                  _preferencesService.setInt('alarm_minute', _alarmTime.minute),
              () => _preferencesService.setStringList(
                  'alarm_categories', categoryNames),
            ],
            timeout: const Duration(seconds: 10),
            failFast: true,
            operationName: 'updateAlarmSettings',
          );

          await _scheduledNotificationService.scheduleDailyAlarm();
        } else {
          await _scheduledNotificationService.cancelDailyAlarm();
        }

        return enabled
            ? 'Daily notifications enabled'
            : 'Daily notifications disabled';
      },
      operationName: 'Update weather alarm',
      onSuccess: (message) {
        if (mounted) {
          SnackBarUtils.showSuccess(context, message);
        }
      },
      onError: (error) {
        if (mounted) {
          SnackBarUtils.showError(context, error);
        }
      },
    );
  }

  Future<void> _selectAlarmTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _alarmTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _alarmTime) {
      // Update state immediately for saving
      setState(() {
        _alarmTime = picked;
      });
      // Save the new time
      await _saveSettings();
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await _showConfirmationDialog(
      'Clear All Data',
      'This will reset all settings and clear stored weather data. Are you sure?',
    );

    if (confirmed) {
      await handleAsync(
        operation: () async {
          // Parallelize clearing operations with optimized handling
          await executeParallel<void>(
            operations: [
              () => _preferencesService.clear(),
              () => _notificationService.cancelAllNotifications(),
              () => _monitoringManager.stopMonitoring(),
            ],
            timeout: const Duration(seconds: 15),
            failFast: false,
            operationName: 'clearAllData',
          );

          // Reset to default values
          debouncedSetState(() {
            _alarmTime = const TimeOfDay(hour: 9, minute: 0);
            _alarmEnabled = true;
            _selectedCategories = {WeatherCategory.perfect};
          });

          return 'All data cleared successfully';
        },
        operationName: 'Clear all data',
        onSuccess: (message) {
          if (mounted) {
            SnackBarUtils.showSuccess(context, message);
          }
        },
        onError: (error) {
          if (mounted) {
            SnackBarUtils.showError(context, error);
          }
        },
      );
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await CommonWidgets.showConfirmationDialog(
      context: context,
      title: title,
      content: content,
    );
  }

  Future<void> _testNotification() async {
    try {
      final notificationService = ServiceManager.instance.notificationService;
      await notificationService.showImmediateTestNotification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Test notification sent!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 3,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to send test notification: $e',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 3,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildNotificationSettings(),
                const SizedBox(height: 16),
                _buildControlsCard(),
                const SizedBox(height: 16),
                _buildAboutSection(),
                const SizedBox(height: 16),
                _buildDataSection(),
              ],
            ),
    );
  }

  Widget _buildNotificationSettings() {
    return OptimizedSettingsCard(
      title: 'Daily Weather Notifications',
      children: [
        // Weather Alarm Toggle
        OptimizedSwitchTile(
          title: 'Enable Daily Notifications',
          subtitle: 'Get daily weather recommendations for riding',
          value: _alarmEnabled,
          onChanged: _updateAlarmEnabled,
        ),

        // Alarm Time
        if (_alarmEnabled) ...[
          const Divider(),
          ListTile(
            title: const Text('Notification Time'),
            subtitle: Text(
              'Currently set to ${_alarmTime.format(context)}',
            ),
            trailing: const OptimizedIcon('schedule'),
            onTap: _selectAlarmTime,
          ),

          const Divider(),

          // Weather Category Selection
          ListTile(
            title: const Text('Weather Notification Categories'),
            subtitle: Text(
              _selectedCategories.isNotEmpty
                  ? _selectedCategories.map((cat) => cat.title).join(', ')
                  : 'Perfect Weather',
            ),
            trailing: Icon(Icons.arrow_forward_ios,
                size: ImageOptimization.getOptimizedIconSize(
                    context, IconSizeType.small)),
            onTap: _selectWeatherCategory,
          ),
        ],
      ],
    );
  }

  Widget _buildControlsCard() {
    return OptimizedSettingsCard(
      title: 'Controls',
      children: [
        ListTile(
          leading: const OptimizedIcon('notifications'),
          title: const Text('Test Alert'),
          subtitle: const Text('Send a test notification'),
          onTap: _testNotification,
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return OptimizedSettingsCard(
      title: 'About',
      children: [
        ListTile(
          leading: const OptimizedIcon('info'),
          title: const Text('Ride or Drive Weather'),
          subtitle: const Text('Version 1.0.0'),
          onTap: () => _showAboutDialog(),
        ),
        ListTile(
          leading: const OptimizedWeatherIcon('cloudy'),
          title: const Text('Weather Data'),
          subtitle: const Text('Powered by Open-Meteo'),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => const _WeatherDataSourceDialog(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDataSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return OptimizedSettingsCard(
      title: 'Data Management',
      children: [
        ListTile(
          leading: Icon(
            ImageOptimization.getIcon('delete'),
            color: colorScheme.error,
          ),
          title: Text(
            'Clear All Data',
            style: TextStyle(
              color: colorScheme.error,
            ),
          ),
          subtitle: const Text('Reset all settings and clear stored data'),
          onTap: _clearAllData,
        ),
      ],
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Ride or Drive Weather',
      applicationVersion: '1.0.0',
      applicationIcon: OptimizedIcon('motorcycle', size: 48),
      children: const [
        Text(
          'A simple weather app that helps you decide whether to ride your motorcycle or drive your car based on current weather conditions.\n\n'
          'Weather data provided by Open-Meteo.com',
        ),
      ],
    );
  }

  Future<void> _selectWeatherCategory() async {
    final Set<WeatherCategory>? selected =
        await showDialog<Set<WeatherCategory>>(
      context: context,
      builder: (context) => _WeatherCategoryDialog(
        initialSelection: _selectedCategories,
      ),
    );

    if (selected != null && selected != _selectedCategories) {
      // Use regular setState to ensure immediate state update before saving
      setState(() {
        _selectedCategories =
            selected.isNotEmpty ? selected : {WeatherCategory.perfect};
      });
      await _saveSettings();
    }
  }

  @override
  void dispose() {
    // Unregister resources
    unregisterResource('NotificationService', 'settings_screen');
    unregisterResource('WeatherMonitoringManager', 'settings_screen');
    unregisterResource('PreferencesService', 'settings_screen');
    unregisterResource('ScheduledNotificationService', 'settings_screen');

    // ResourceCleanupMixin will handle the rest
    super.dispose();
  }
}

class _WeatherDataSourceDialog extends StatelessWidget {
  const _WeatherDataSourceDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Weather Data Source'),
      content: const Text(
        'This app uses Open-Meteo.com for weather data.\n\n'
        'Open-Meteo is an open-source weather API that provides '
        'free access to high-resolution weather forecasts without '
        'requiring an API key.\n\n'
        'Data is sourced from national weather services and '
        'updated hourly.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Okay'),
        ),
      ],
    );
  }
}

class _WeatherCategoryDialog extends StatefulWidget {
  const _WeatherCategoryDialog({
    required this.initialSelection,
  });

  final Set<WeatherCategory> initialSelection;

  @override
  State<_WeatherCategoryDialog> createState() => _WeatherCategoryDialogState();
}

class _WeatherCategoryDialogState extends State<_WeatherCategoryDialog> {
  late Set<WeatherCategory> _tempSelected;

  @override
  void initState() {
    super.initState();
    _tempSelected = Set.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Weather Categories'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: WeatherCategory.values.map((category) {
          return CheckboxListTile(
            title: Text(category.title),
            subtitle: Text(category.description),
            value: _tempSelected.contains(category),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _tempSelected.add(category);
                } else {
                  _tempSelected.remove(category);
                }
              });
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_tempSelected),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
